import Foundation
import CommonCrypto
import os

// Diagnostics: `log show --predicate 'subsystem == "com.vaani.app"' --last 10m`
private let apiLog = Logger(subsystem: "com.vaani.app", category: "api")

class SaarasAPIClient: NSObject, URLSessionDelegate {
    private let baseURL = "https://api.sarvam.ai"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Public key hash for api.sarvam.ai (SPKI SHA256)
    // This should be updated periodically - check cert expiry
    private let pinnedPublicKeyHashes: Set<String> = [
        // Primary cert hash - needs to be obtained from actual cert
        // Backup cert hash - for cert rotation
    ]

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Only pin api.sarvam.ai, allow others (for flexibility in testing)
        guard challenge.protectionSpace.host == "api.sarvam.ai" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate server trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If pinning is disabled (no hashes configured), proceed with system trust
        if pinnedPublicKeyHashes.isEmpty {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Extract and validate public key
        if let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
           let serverCert = certChain.first,
           let publicKey = SecCertificateCopyKey(serverCert),
           let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {

            let hash = sha256(data: publicKeyData).base64EncodedString()

            if pinnedPublicKeyHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // Pin validation failed
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    func transcribe(
        audioURL: URL,
        mode: TranslationMode,
        targetLanguage: Language,
        apiKey: String
    ) async throws -> TranslationResult {
        let startTime = Date()

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "\(baseURL)/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)

        var body = Data()

        // Model parameter
        body.appendFormField(named: "model", value: "saaras:v3", boundary: boundary)

        // Language code — "unknown" lets the API auto-detect source language
        body.appendFormField(named: "language_code", value: "unknown", boundary: boundary)

        // For translate to non-English: use transcribe mode for STT, then translate
        // directly from source language → target (skips the English middleman)
        let directTranslate = (mode == .translate && targetLanguage != .english)
        let sttMode = directTranslate ? TranslationMode.transcribe.rawValue : mode.rawValue

        // Mode parameter
        body.appendFormField(named: "mode", value: sttMode, boundary: boundary)

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            apiLog.error("speech-to-text HTTP \(httpResponse.statusCode): \(String(decoding: data.prefix(500), as: UTF8.self), privacy: .public)")
            throw APIError.httpError(httpResponse.statusCode)
        }

        let apiResponse: SarvamAPIResponse
        do {
            apiResponse = try JSONDecoder().decode(SarvamAPIResponse.self, from: data)
        } catch {
            apiLog.error("speech-to-text decode failed: \(String(describing: error), privacy: .public) body: \(String(decoding: data.prefix(500), as: UTF8.self), privacy: .public)")
            throw error
        }
        apiLog.info("speech-to-text ok: \(apiResponse.transcript.count) chars, lang \(apiResponse.languageCode ?? "nil", privacy: .public)")

        var finalText = apiResponse.transcript

        // For translate to non-English: STT returned native text via transcribe mode.
        // Translate directly from detected source language → target (no English hop).
        // For translate to English: STT already returned English via translate mode.
        if directTranslate {
            let sourceLang = apiResponse.languageCode
                .flatMap { Language(rawValue: $0) } ?? .hindi
            finalText = try await translateText(
                input: apiResponse.transcript,
                sourceLanguage: sourceLang,
                targetLanguage: targetLanguage,
                apiKey: apiKey
            )
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return TranslationResult(
            text: finalText,
            sourceLanguage: apiResponse.languageCode,
            confidence: apiResponse.languageProbability,
            processingTime: processingTime
        )
    }

    /// Transcribes multiple audio chunks in parallel, returning a combined result.
    /// For translate mode with non-English target: transcribes in native language,
    /// concatenates, then performs ONE direct translation (no English middleman).
    func transcribeChunks(
        audioURLs: [URL],
        mode: TranslationMode,
        targetLanguage: Language,
        apiKey: String
    ) async throws -> TranslationResult {
        let startTime = Date()

        // Single chunk — use the normal path directly
        if audioURLs.count == 1 {
            return try await transcribe(
                audioURL: audioURLs[0],
                mode: mode,
                targetLanguage: targetLanguage,
                apiKey: apiKey
            )
        }

        // For translate to non-English: transcribe each chunk in native language,
        // concatenate, then ONE translateText() call (direct, no English hop).
        // For translate to English: STT translate mode returns English directly.
        // For all other modes: transcribe each chunk, concatenate results.
        let needsPostTranslation = (mode == .translate && targetLanguage != .english)

        // Parallel transcription of all chunks
        let indexedResults: [(Int, String, String?)] = try await withThrowingTaskGroup(
            of: (Int, String, String?).self
        ) { group in
            for (index, url) in audioURLs.enumerated() {
                group.addTask {
                    // For post-translation: use transcribe mode to get native text
                    // (transcribe() handles this via directTranslate logic)
                    let result = try await self.transcribe(
                        audioURL: url,
                        mode: needsPostTranslation ? .transcribe : mode,
                        targetLanguage: targetLanguage,
                        apiKey: apiKey
                    )
                    return (index, result.text, result.sourceLanguage)
                }
            }

            var results: [(Int, String, String?)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Sort by chunk order and concatenate
        let sorted = indexedResults.sorted { $0.0 < $1.0 }
        let orderedTranscripts = sorted.map { $0.1 }.filter { !$0.isEmpty }
        var combinedText = orderedTranscripts.joined(separator: " ")

        // For translate to non-English: one direct translation from source → target
        if needsPostTranslation && !combinedText.isEmpty {
            let sourceLang = sorted.first?.2
                .flatMap { Language(rawValue: $0) } ?? .hindi
            combinedText = try await translateText(
                input: combinedText,
                sourceLanguage: sourceLang,
                targetLanguage: targetLanguage,
                apiKey: apiKey
            )
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return TranslationResult(
            text: combinedText,
            sourceLanguage: sorted.first?.2,
            confidence: nil,
            processingTime: processingTime
        )
    }

    /// Opens the HTTPS connection early (fn-down) so the upload on release skips the TLS handshake.
    func warmUp() {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        session.dataTask(with: request).resume()
    }

    /// Validate API key by making a lightweight request
    func validateKey(apiKey: String) async -> APIKeyStatus {
        var request = URLRequest(url: URL(string: "\(baseURL)/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Send empty body — API will return 400 (bad request) if key is valid,
        // or 401/403 if key is invalid
        request.httpBody = "{}".data(using: .utf8)
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .unknown }
            switch httpResponse.statusCode {
            case 401, 403: return .invalid
            case 402: return .noCredits
            default: return .ok   // 400/422 = key accepted, body rejected
            }
        } catch {
            return .unknown   // network error — don't blame the key
        }
    }

    /// Text-to-text translation using Sarvam /translate endpoint
    func translateText(
        input: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiKey: String
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/translate")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": input,
            "source_language_code": sourceLanguage.bcp47Code,
            "target_language_code": targetLanguage.bcp47Code,
            "model": "sarvam-translate:v1",
            "mode": "formal"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            apiLog.error("translate HTTP \(httpResponse.statusCode): \(String(decoding: data.prefix(500), as: UTF8.self), privacy: .public)")
            throw APIError.httpError(httpResponse.statusCode)
        }

        let translateResponse = try JSONDecoder().decode(TranslateResponse.self, from: data)
        return translateResponse.translatedText
    }
}

private extension Data {
    mutating func appendFormField(named name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}

enum APIKeyStatus: Equatable {
    case unknown, missing, ok, invalid, noCredits

    var label: String {
        switch self {
        case .unknown: return "Not checked"
        case .missing: return "No key saved"
        case .ok: return "Key OK"
        case .invalid: return "Invalid key"
        case .noCredits: return "No credits"
        }
    }

    var message: String? {
        switch self {
        case .missing: return "Add your Sarvam API key in Settings."
        case .invalid: return "API key invalid or expired. Update in Settings."
        case .noCredits: return "Sarvam account has no credits. Add credits at dashboard.sarvam.ai"
        case .ok, .unknown: return nil
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unable to connect to translation service"
        case .httpError(let code):
            switch code {
            case 401, 403:
                return "API key invalid or expired"
            case 402:
                return "Sarvam account has no credits. Add credits at dashboard.sarvam.ai"
            case 429:
                return "Too many requests. Please wait and try again"
            case 500...599:
                return "Translation service temporarily unavailable"
            default:
                return "Translation failed. Please try again"
            }
        }
    }
}
