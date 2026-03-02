import Foundation
import Combine
import SwiftUI

@MainActor
class TranslatorViewModel: ObservableObject {
    @Published var targetLanguage: Language = .hindi
    @Published var selectedMode: TranslationMode = .translit
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastResult: String = ""
    @Published var lastError: String?
    @Published var processingTime: TimeInterval = 0
    @Published var showSettings = false
    @Published var apiKey: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var useFnKey: Bool = false
    @Published var appearanceMode: AppearanceMode = .system
    @Published var history: [HistoryItem] = []
    @Published var accessibilityGranted: Bool = false
    @Published var apiKeyValid: Bool = true

    private let audioRecorder = AudioRecorder()
    private let apiClient = SaarasAPIClient()
    private let keychainManager = KeychainManager()
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var accessibilityTimer: Timer?

    // Rate limiting
    private var recentRequests: [Date] = []
    private let maxRequestsPerMinute = 30

    init() {
        // Load API key from keychain
        if let savedKey = keychainManager.getAPIKey() {
            apiKey = savedKey
        }

        // Check accessibility permission and poll until granted
        accessibilityGranted = PasteboardManager.hasAccessibilityPermission()
        if !accessibilityGranted {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self = self else { timer.invalidate(); return }
                    if PasteboardManager.hasAccessibilityPermission() {
                        self.accessibilityGranted = true
                        timer.invalidate()
                        self.accessibilityTimer = nil
                    }
                }
            }
        }

        // Load fn key preference (default: enabled for new installs)
        if UserDefaults.standard.object(forKey: "useFnKey") == nil {
            useFnKey = true
        } else {
            useFnKey = UserDefaults.standard.bool(forKey: "useFnKey")
        }

        // Load appearance preference
        if let saved = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: saved) {
            appearanceMode = mode
        }

        // Persist fn key preference on change
        $useFnKey
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "useFnKey") }
            .store(in: &cancellables)

        // Persist appearance preference on change
        $appearanceMode
            .dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "appearanceMode") }
            .store(in: &cancellables)

        // Validate API key on launch
        if hasAPIKey() {
            validateAPIKey()
        } else {
            apiKeyValid = false
        }

        // Observe audio level
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    func startRecording() {
        guard !isRecording && !isProcessing else { return }

        audioRecorder.requestMicPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                do {
                    self.recordingURL = try self.audioRecorder.startRecording()
                    self.recordingStartTime = Date()
                    self.lastError = nil
                } catch {
                    self.lastError = "Failed to start recording: \(error.localizedDescription)"
                }
            } else {
                self.lastError = "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone."
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        // Check minimum recording duration (0.5s) to avoid "Audio duration is 0" errors
        if let start = recordingStartTime, Date().timeIntervalSince(start) < 0.5 {
            _ = audioRecorder.stopRecording()
            audioRecorder.cleanup()
            lastError = "Recording too short. Hold longer to record."
            return
        }

        guard let url = audioRecorder.stopRecording() else {
            lastError = "Failed to stop recording"
            return
        }

        recordingURL = url
        processRecording()
    }

    private func processRecording() {
        guard let url = recordingURL else {
            lastError = "No recording found"
            return
        }

        // Rate limiting check
        let now = Date()
        recentRequests = recentRequests.filter { now.timeIntervalSince($0) < 60 }

        if recentRequests.count >= maxRequestsPerMinute {
            lastError = "Too many requests. Please wait a moment."
            return
        }

        guard hasAPIKey() else {
            lastError = "API key not configured. Add your API key in Settings."
            showSettings = true
            return
        }

        // Reload key from keychain in case the text field was cleared without saving
        if apiKey.isEmpty, let savedKey = keychainManager.getAPIKey() {
            apiKey = savedKey
        }

        isProcessing = true
        lastError = nil

        // Capture values for detached task (can't access @MainActor properties there)
        let mode = selectedMode
        let lang = targetLanguage
        let key = apiKey
        let client = apiClient
        let recorder = audioRecorder

        // Run ENTIRE pipeline off main thread to prevent UI freeze
        Task.detached {
            do {
                // 1. Convert to 16kHz Int16 mono + split into ≤28s chunks
                let chunks = try AudioChunker.convertAndSplit(audioURL: url)

                // 2. Transcribe all chunks in parallel, combine results
                let result = try await client.transcribeChunks(
                    audioURLs: chunks,
                    mode: mode,
                    targetLanguage: lang,
                    apiKey: key
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.lastResult = result.text
                    self.processingTime = result.processingTime
                    self.isProcessing = false

                    // Rate limiting
                    for _ in chunks {
                        self.recentRequests.append(Date())
                    }

                    // Save to history + auto-paste only if non-empty
                    if !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let item = HistoryItem(
                            text: result.text,
                            toLang: lang,
                            mode: mode,
                            date: Date()
                        )
                        self.history.insert(item, at: 0)
                        if self.history.count > 5 {
                            self.history = Array(self.history.prefix(5))
                        }

                        PasteboardManager.pasteText(result.text)
                    }
                }

                // 3. Cleanup original + chunk files
                recorder.cleanupAll(chunkURLs: chunks)

            } catch let error as AudioChunkerError {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.isProcessing = false
                }
            } catch let error as APIError {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.isProcessing = false
                    if case .httpError(let code) = error, code == 401 || code == 403 {
                        self?.apiKeyValid = false
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = "Translation failed: \(error.localizedDescription)"
                    self?.isProcessing = false
                }
            }
        }
    }

    func saveAPIKey() {
        do {
            try keychainManager.saveAPIKey(apiKey)
            lastError = nil
            validateAPIKey()
        } catch {
            lastError = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    func hasAPIKey() -> Bool {
        return keychainManager.hasAPIKey()
    }

    func validateAPIKey() {
        guard hasAPIKey() else {
            apiKeyValid = false
            return
        }
        let key = apiKey.isEmpty ? (keychainManager.getAPIKey() ?? "") : apiKey
        guard !key.isEmpty else {
            apiKeyValid = false
            return
        }
        Task {
            let valid = await apiClient.validateKey(apiKey: key)
            await MainActor.run {
                self.apiKeyValid = valid
                if !valid {
                    self.lastError = "API key invalid or expired. Update in Settings."
                }
            }
        }
    }
}
