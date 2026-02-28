import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    override init() {
        super.init()
    }

    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }

    func startRecording() throws -> URL {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw RecordingError.engineInitFailed
        }

        inputNode = engine.inputNode
        guard let input = inputNode else {
            throw RecordingError.noInputNode
        }

        // Create secure app-specific directory (not world-readable /tmp)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordingsDir = appSupport.appendingPathComponent("com.vaani.app/recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        recordingURL = recordingsDir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")

        guard let url = recordingURL else {
            throw RecordingError.fileCreationFailed
        }

        // Setup audio format
        let recordingFormat = input.outputFormat(forBus: 0)

        // Create audio file
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        } catch {
            throw RecordingError.fileCreationFailed
        }

        // Install tap on input node
        input.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self, let file = self.audioFile else { return }

            do {
                try file.write(from: buffer)

                // Calculate audio level for UI feedback
                let channelData = buffer.floatChannelData?[0]
                let channelDataCount = Int(buffer.frameLength)

                if let data = channelData {
                    var sum: Float = 0
                    for i in 0..<channelDataCount {
                        sum += abs(data[i])
                    }
                    let average = min(sum / Float(channelDataCount), 1.0)
                    DispatchQueue.main.async {
                        self.audioLevel = average
                    }
                }
            } catch {
                // Audio buffer write error (non-fatal)
            }
        }

        // Start engine
        try engine.start()

        DispatchQueue.main.async {
            self.isRecording = true
        }

        return url
    }

    func stopRecording() -> URL? {
        guard let engine = audioEngine, let input = inputNode else {
            return nil
        }

        input.removeTap(onBus: 0)
        engine.stop()

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }

        return recordingURL
    }

    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case engineInitFailed
    case noInputNode
    case fileCreationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .noInputNode:
            return "No audio input device found"
        case .fileCreationFailed:
            return "Failed to create recording file"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
