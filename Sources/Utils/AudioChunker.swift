import Foundation
import AVFoundation

enum AudioChunkerError: Error, LocalizedError {
    case fileReadFailed
    case conversionFailed
    case chunkWriteFailed

    var errorDescription: String? {
        switch self {
        case .fileReadFailed: return "Failed to read audio file"
        case .conversionFailed: return "Failed to convert audio format"
        case .chunkWriteFailed: return "Failed to write audio chunk"
        }
    }
}

struct AudioChunker {
    /// 28s chunks — safely under the 30s API limit
    static let maxChunkDuration: TimeInterval = 28.0

    /// Target format for Sarvam API
    static let targetSampleRate: Double = 16000

    /// Converts recording to 16kHz Int16 mono, then splits into ≤28s chunks.
    /// Recording can be in any format (48kHz Float32, etc.) — this handles conversion.
    /// Returns ordered array of chunk file URLs ready for the API.
    static func convertAndSplit(audioURL: URL, maxDuration: TimeInterval = maxChunkDuration) throws -> [URL] {
        // Already 16kHz Int16 mono (AudioRecorder converts while recording)? Skip afconvert.
        if let file = try? AVAudioFile(forReading: audioURL),
           file.fileFormat.sampleRate == targetSampleRate,
           file.fileFormat.channelCount == 1,
           file.fileFormat.commonFormat == .pcmFormatInt16 {
            return try split(audioURL: audioURL, maxDuration: maxDuration)
        }

        // Step 1: Convert to 16kHz Int16 mono using afconvert (reliable, works on all Macs)
        let convertedURL = audioURL.deletingLastPathComponent()
            .appendingPathComponent(audioURL.deletingPathExtension().lastPathComponent + "_converted.wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-d", "LEI16@16000",   // 16-bit little-endian integer at 16kHz
            "-c", "1",              // mono
            "-f", "WAVE",           // WAV format
            audioURL.path,
            convertedURL.path
        ]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AudioChunkerError.conversionFailed
        }

        guard process.terminationStatus == 0 else {
            throw AudioChunkerError.conversionFailed
        }

        // Step 2: Split the converted file into chunks
        let chunks = try split(audioURL: convertedURL, maxDuration: maxDuration)

        // Delete the intermediate converted file if chunks were created from it
        if chunks.first != convertedURL {
            try? FileManager.default.removeItem(at: convertedURL)
        }

        return chunks
    }

    /// Splits a WAV file into chunks of at most `maxDuration` seconds.
    /// File must already be in 16kHz Int16 mono format.
    private static func split(audioURL: URL, maxDuration: TimeInterval) throws -> [URL] {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw AudioChunkerError.fileReadFailed
        }

        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let maxFramesPerChunk = AVAudioFrameCount(sampleRate * maxDuration)

        // Short recording — no splitting needed, return the converted file as-is
        if totalFrames <= maxFramesPerChunk {
            return [audioURL]
        }

        let chunkDir = audioURL.deletingLastPathComponent()
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        var chunkURLs: [URL] = []
        var framesRead: AVAudioFrameCount = 0
        var chunkIndex = 0

        while framesRead < totalFrames {
            let remainingFrames = totalFrames - framesRead
            let framesToRead = min(maxFramesPerChunk, remainingFrames)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: framesToRead
            ) else {
                throw AudioChunkerError.chunkWriteFailed
            }

            do {
                try audioFile.read(into: buffer, frameCount: framesToRead)
            } catch {
                throw AudioChunkerError.fileReadFailed
            }

            let chunkURL = chunkDir.appendingPathComponent(
                "\(baseName)_chunk\(chunkIndex).wav"
            )

            do {
                let chunkFile = try AVAudioFile(
                    forWriting: chunkURL,
                    settings: audioFile.fileFormat.settings
                )
                try chunkFile.write(from: buffer)
            } catch {
                throw AudioChunkerError.chunkWriteFailed
            }

            chunkURLs.append(chunkURL)
            framesRead += framesToRead
            chunkIndex += 1
        }

        // Clean up the converted source file since we have chunks now
        try? FileManager.default.removeItem(at: audioURL)

        return chunkURLs
    }

    /// Cleans up chunk files (not the original recording).
    static func cleanupChunks(_ urls: [URL], originalURL: URL) {
        for url in urls where url != originalURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
