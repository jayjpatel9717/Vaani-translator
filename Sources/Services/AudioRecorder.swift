import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private static let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
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

        // Create secure app-specific directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let recordingsDir = appSupport.appendingPathComponent("com.vaani.app/recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        recordingURL = recordingsDir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")

        guard let url = recordingURL else {
            throw RecordingError.fileCreationFailed
        }

        // Convert to 16kHz Int16 mono while recording so the upload needs no post-processing.
        // ponytail: if the converter can't be built for this device, fall back to the native
        // format and let AudioChunker run afconvert afterwards.
        let nativeFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: nativeFormat, to: Self.targetFormat)

        do {
            if converter != nil {
                audioFile = try AVAudioFile(forWriting: url, settings: Self.targetFormat.settings,
                                            commonFormat: .pcmFormatInt16, interleaved: true)
            } else {
                audioFile = try AVAudioFile(forWriting: url, settings: nativeFormat.settings)
            }
        } catch {
            throw RecordingError.fileCreationFailed
        }

        // Install tap in native format — works on ALL Macs
        input.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, time in
            guard let self = self, let file = self.audioFile else { return }

            // Calculate audio level for UI feedback
            let channelData = buffer.floatChannelData?[0]
            let frameCount = Int(buffer.frameLength)
            if let data = channelData, frameCount > 0 {
                var sum: Float = 0
                for i in 0..<frameCount {
                    sum += abs(data[i])
                }
                let average = min(sum / Float(frameCount), 1.0)
                DispatchQueue.main.async {
                    self.audioLevel = average
                }
            }

            // Write (converted) audio buffer to file
            let toWrite: AVAudioPCMBuffer
            if let converter = self.converter {
                guard let converted = Self.convert(buffer, with: converter) else { return }
                toWrite = converted
            } else {
                toWrite = buffer
            }
            try? file.write(from: toWrite)
        }

        try engine.start()

        DispatchQueue.main.async {
            self.isRecording = true
        }

        return url
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : out
    }

    func stopRecording() -> URL? {
        guard let engine = audioEngine, let input = inputNode else {
            return nil
        }

        input.removeTap(onBus: 0)
        engine.stop()

        // Close the audio file to finalize the WAV header (writes correct data size)
        audioFile = nil

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

    /// Cleans up the original recording and any chunk files
    func cleanupAll(chunkURLs: [URL]) {
        if let url = recordingURL {
            AudioChunker.cleanupChunks(chunkURLs, originalURL: url)
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
