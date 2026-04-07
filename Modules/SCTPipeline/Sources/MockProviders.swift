import Foundation
import AVFoundation
import SCTCore

/// Mock ASR provider that returns a simple transformation of input.
/// For MVP, this demonstrates the flow without real ASR.
public struct MockASRProvider: ASRProvider {
    public init() {}

    public func recognize(audio: Data, language: String) async throws -> String {
        // For MVP: return a mock transcript
        // In real implementation, this would call an ASR API
        return "Mock transcript for \(language): [audio input]"
    }
}

/// Mock translation provider that prefixes translated text.
/// For MVP, this demonstrates the flow without real translation API.
public struct MockTranslationProvider: TranslationProvider {
    public init() {}

    public func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        // Simple mock: prefix with target language indicator
        // Real implementation would call Google/DeepL/OpenAI translation API
        return "[\(targetLanguage)] \(text)"
    }
}

/// Mock TTS provider that generates a short sine wave tone.
/// For MVP, this provides audio data without real TTS API calls.
public struct MockTTSProvider: TTSProvider {
    public static let sampleRate: Double = 44100
    public static let toneFrequency: Double = 440 // A4 note

    public init() {}

    public func synthesize(text: String, language: String) async throws -> Data {
        // Generate a short sine wave burst as mock TTS output
        let duration: Double = 0.3 // 300ms
        let frameCount = AVAudioFrameCount(Self.sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MockTTSError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else {
            throw MockTTSError.bufferCreationFailed
        }

        for frame in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * .pi * Self.toneFrequency * Double(frame) / Self.sampleRate))
            channelData[frame] = sample
        }

        // Convert buffer to Data
        let dataSize = Int(frameCount) * MemoryLayout<Float>.size
        var data = Data(capacity: dataSize)
        data.append(UnsafeBufferPointer(start: channelData, count: Int(frameCount)))

        return data
    }
}

public enum MockTTSError: Error, Sendable {
    case bufferCreationFailed
}
