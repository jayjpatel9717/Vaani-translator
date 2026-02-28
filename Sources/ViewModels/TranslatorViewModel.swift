import Foundation
import Combine
import SwiftUI

@MainActor
class TranslatorViewModel: ObservableObject {
    @Published var targetLanguage: Language = .hindi
    @Published var selectedMode: TranslationMode = .translate
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastResult: String = ""
    @Published var lastError: String?
    @Published var processingTime: TimeInterval = 0
    @Published var showSettings = false
    @Published var apiKey: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var useFnKey: Bool = false
    @Published var history: [HistoryItem] = []
    @Published var accessibilityGranted: Bool = false

    private let audioRecorder = AudioRecorder()
    private let apiClient = SaarasAPIClient()
    private let keychainManager = KeychainManager()
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var accessibilityTimer: Timer?

    // Rate limiting: track last 10 request timestamps
    private var recentRequests: [Date] = []
    private let maxRequestsPerMinute = 10

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

        // Load fn key preference
        useFnKey = UserDefaults.standard.bool(forKey: "useFnKey")

        // Persist fn key preference on change
        $useFnKey
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "useFnKey") }
            .store(in: &cancellables)

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

        recentRequests.append(now)

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

        Task {
            do {
                let result = try await apiClient.transcribe(
                    audioURL: url,
                    mode: selectedMode,
                    targetLanguage: targetLanguage,
                    apiKey: apiKey
                )

                await MainActor.run {
                    lastResult = result.text
                    processingTime = result.processingTime
                    isProcessing = false

                    // Save to history
                    let item = HistoryItem(
                        text: result.text,
                        toLang: targetLanguage,
                        mode: selectedMode,
                        date: Date()
                    )
                    history.insert(item, at: 0)
                    if history.count > 3 {
                        history = Array(history.prefix(3))
                    }

                    // Auto-paste the result
                    PasteboardManager.pasteText(result.text)
                }

                // Cleanup
                audioRecorder.cleanup()

            } catch {
                await MainActor.run {
                    lastError = "Translation failed: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }

    func saveAPIKey() {
        do {
            try keychainManager.saveAPIKey(apiKey)
            lastError = nil
        } catch {
            lastError = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    func hasAPIKey() -> Bool {
        return keychainManager.hasAPIKey()
    }
}
