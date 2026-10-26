import Foundation
import AppKit
import Combine
import SwiftUI
import AVFoundation
import os

private let vmLog = Logger(subsystem: "com.vaani.app", category: "pipeline")

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
    @Published var useFnKey: Bool = false {
        didSet { if useFnKey { useControlKey = false } }
    }
    @Published var useControlKey: Bool = false {
        didSet { if useControlKey { useFnKey = false } }
    }
    var holdKeyLabel: String? { useControlKey ? "ctrl" : (useFnKey ? "fn" : nil) }
    @Published var appearanceMode: AppearanceMode = .system
    @Published var history: [HistoryItem] = []
    @Published var accessibilityGranted: Bool = false
    @Published var apiKeyStatus: APIKeyStatus = .unknown
    @Published var micGranted: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published var hudState: HUDState = .hidden
    @Published var setupCompleted: Bool = UserDefaults.standard.bool(forKey: "setupCompleted") {
        didSet { UserDefaults.standard.set(setupCompleted, forKey: "setupCompleted") }
    }
    var apiKeyValid: Bool { apiKeyStatus == .ok || apiKeyStatus == .unknown }

    private let audioRecorder = AudioRecorder()
    private let apiClient = SaarasAPIClient()
    private let keychainManager = KeychainManager()
    private var recordingGeneration = 0
    private var recordingPasteTarget: NSRunningApplication?
    private var recordingURL: URL?
    @Published private(set) var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var accessibilityTimer: Timer?

    // Rate limiting
    private var recentRequests: [Date] = []
    private let maxRequestsPerMinute = 30

    private var keychainLoaded = false

    init() {
        // Defer Keychain read to avoid macOS permission dialog on first launch.
        // API key is loaded lazily when Settings is opened or recording starts.

        // Poll permissions until both are granted (System Settings changes don't notify us)
        accessibilityGranted = PasteboardManager.hasAccessibilityPermission()
        if !accessibilityGranted || !micGranted {
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self = self else { timer.invalidate(); return }
                    self.accessibilityGranted = PasteboardManager.hasAccessibilityPermission()
                    self.micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
                    if self.accessibilityGranted && self.micGranted {
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

        useControlKey = UserDefaults.standard.bool(forKey: "useControlKey")

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

        $useControlKey
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "useControlKey") }
            .store(in: &cancellables)

        // Persist appearance preference on change
        $appearanceMode
            .dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "appearanceMode") }
            .store(in: &cancellables)

        // Validate API key lazily after a short delay (avoids Keychain dialog on cold launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.loadKeychainIfNeeded()
        }

        // Observe audio level
        audioRecorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    func requestMicPermission() {
        audioRecorder.requestMicPermission { [weak self] granted in
            Task { @MainActor in self?.micGranted = granted }
        }
    }

    func startRecording() {
        guard !isRecording && !isProcessing else { return }
        recordingPasteTarget = PasteboardManager.captureTarget()
        recordingGeneration += 1
        let generation = recordingGeneration
        apiClient.warmUp()

        audioRecorder.requestMicPermission { [weak self] granted in
            guard let self = self, self.recordingGeneration == generation else { return }
            self.micGranted = granted
            if granted {
                do {
                    self.recordingURL = try self.audioRecorder.startRecording()
                    self.recordingStartTime = Date()
                    self.lastError = nil
                    self.hudState = .listening
                } catch {
                    self.lastError = "Failed to start recording: \(error.localizedDescription)"
                    self.hudState = .error(self.lastError ?? "")
                }
            } else {
                self.lastError = "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone."
                self.hudState = .error("Microphone access denied \u{2014} allow it in System Settings")
            }
        }
    }

    func stopRecording() {
        recordingGeneration += 1
        guard isRecording else { return }

        // Check minimum recording duration (0.5s) to avoid "Audio duration is 0" errors
        if let start = recordingStartTime, Date().timeIntervalSince(start) < 0.5 {
            _ = audioRecorder.stopRecording()
            audioRecorder.cleanup()
            lastError = "Recording too short. Hold longer to record."
            hudState = .error("Too short \u{2014} hold the key while you speak")
            return
        }

        guard let url = audioRecorder.stopRecording() else {
            lastError = "Failed to stop recording"
            hudState = .error("Failed to stop recording")
            return
        }

        recordingURL = url
        processRecording()
    }

    // A Control chord cancels the hold gesture without uploading or pasting audio.
    func cancelRecording() {
        recordingGeneration += 1
        _ = audioRecorder.stopRecording()
        audioRecorder.cleanup()
        recordingURL = nil
        recordingStartTime = nil
        hudState = .hidden
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
            hudState = .error("Too many requests \u{2014} wait a moment")
            return
        }

        guard hasAPIKey() else {
            vmLog.error("pipeline: no API key readable from keychain")
            apiKeyStatus = .missing
            lastError = "API key not configured. Add your API key in Settings."
            hudState = .error("Add your Sarvam API key in Settings")
            showSettings = true
            return
        }

        // Reload key from keychain in case the text field was cleared without saving
        if apiKey.isEmpty, let savedKey = keychainManager.getAPIKey() {
            apiKey = savedKey
        }

        isProcessing = true
        lastError = nil
        hudState = .translating(since: Date())

        // Capture values for detached task (can't access @MainActor properties there)
        let mode = selectedMode
        let lang = targetLanguage
        let key = apiKey
        let client = apiClient
        let recorder = audioRecorder
        let pasteTarget = recordingPasteTarget

        // Run ENTIRE pipeline off main thread to prevent UI freeze
        Task.detached {
            do {
                // 1. Convert to 16kHz Int16 mono + split into ≤28s chunks
                let chunks = try AudioChunker.convertAndSplit(audioURL: url)
                vmLog.info("pipeline: \(chunks.count) chunk(s), mode \(mode.rawValue, privacy: .public), key length \(key.count)")

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

                    if result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.hudState = .error("Nothing heard \u{2014} speak louder or raise input volume")
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

                        PasteboardManager.pasteText(result.text, recordedTarget: pasteTarget) { [weak self] outcome in
                            guard let self, !self.isRecording, !self.isProcessing else { return }
                            self.accessibilityGranted = PasteboardManager.hasAccessibilityPermission()
                            self.hudState = .done(outcome.message)
                        }
                    }
                }

                // 3. Cleanup original + chunk files
                recorder.cleanupAll(chunkURLs: chunks)

            } catch let error as AudioChunkerError {
                vmLog.error("pipeline: chunker error \(String(describing: error), privacy: .public)")
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.isProcessing = false
                    self?.hudState = .error(error.localizedDescription)
                }
            } catch let error as APIError {
                vmLog.error("pipeline: API error \(String(describing: error), privacy: .public)")
                await MainActor.run { [weak self] in
                    if case .httpError(let code) = error {
                        if code == 401 || code == 403 { self?.apiKeyStatus = .invalid }
                        if code == 402 { self?.apiKeyStatus = .noCredits }
                    }
                    self?.lastError = error.localizedDescription
                    self?.isProcessing = false
                    self?.hudState = .error(error.localizedDescription)
                }
            } catch {
                vmLog.error("pipeline: failed \(String(describing: error), privacy: .public)")
                await MainActor.run { [weak self] in
                    self?.lastError = "Translation failed: \(error.localizedDescription)"
                    self?.isProcessing = false
                    self?.hudState = .error("Translation failed: \(error.localizedDescription)")
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

    /// Loads API key from Keychain on first access (deferred from init to avoid first-launch dialog)
    func loadKeychainIfNeeded() {
        guard !keychainLoaded else { return }
        keychainLoaded = true
        if let savedKey = keychainManager.getAPIKey() {
            apiKey = savedKey
            // Existing installs that already have a key skip the first-run checklist
            if UserDefaults.standard.object(forKey: "setupCompleted") == nil {
                setupCompleted = true
            }
            validateAPIKey()
        } else {
            apiKeyStatus = .missing
        }
    }

    func hasAPIKey() -> Bool {
        loadKeychainIfNeeded()
        return keychainManager.hasAPIKey()
    }

    func validateAPIKey() {
        let key = hasAPIKey() ? (apiKey.isEmpty ? (keychainManager.getAPIKey() ?? "") : apiKey) : ""
        guard !key.isEmpty else {
            apiKeyStatus = .missing
            return
        }
        Task {
            let status = await apiClient.validateKey(apiKey: key)
            await MainActor.run {
                self.apiKeyStatus = status
                if let message = status.message {
                    self.lastError = message
                }
            }
        }
    }
}
