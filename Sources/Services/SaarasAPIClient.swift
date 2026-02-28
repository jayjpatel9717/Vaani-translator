import Foundation
import CommonCrypto

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

        // Mode parameter
        body.appendFormField(named: "mode", value: mode.rawValue, boundary: boundary)

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
            // Don't leak server error details to prevent information disclosure
            throw APIError.httpError(httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(SarvamAPIResponse.self, from: data)

        var finalText = apiResponse.transcript

        // For translate mode: STT always returns English.
        // If the target language is not English, chain a text translation call.
        if mode == .translate, targetLanguage != .english {
            finalText = try await translateText(
                input: apiResponse.transcript,
                sourceLanguage: .english,
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
            "model": "mayura:v1",
            "mode": "formal"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Don't leak server error details
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
