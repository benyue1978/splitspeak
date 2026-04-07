import Foundation
import SCTCore

/// TextTransform converts between text and audio representations.
///
/// For MVP:
/// - Text input: no-op (pass through)
/// - Audio input: requires ASR provider (not implemented in MVP)
///
/// This provides a unified interface for text transformation:
/// - `TextInput`: raw text from manual input
/// - `AudioInput`: audio data requiring ASR
public enum TextTransform {
    /// Text passes through unchanged
    case text(String)

    /// Audio requires ASR to convert to text
    case audio(Data, language: String)
}

/// Transforms input based on type.
///
/// - For text input: returns text as-is (pass-through)
/// - For audio input: calls ASR provider to convert
public struct TextTransformProcessor: Sendable {
    private let asrProvider: ASRProvider

    public init(asrProvider: ASRProvider) {
        self.asrProvider = asrProvider
    }

    /// Transforms the given input to text.
    /// - Parameter input: Either text directly or audio requiring ASR
    /// - Returns: The recognized text
    public func transform(_ input: TextTransform) async throws -> String {
        switch input {
        case .text(let text):
            return text
        case .audio(let audioData, let language):
            return try await asrProvider.recognize(audio: audioData, language: language)
        }
    }
}
