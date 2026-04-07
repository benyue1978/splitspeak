import Foundation
import SCTCore

/// Provider for Automatic Speech Recognition (ASR).
///
/// Converts audio data to text transcript.
public protocol ASRProvider: Sendable {
    /// Recognizes speech in the given audio data.
    /// - Parameters:
    ///   - audio: The audio data to recognize
    ///   - language: The language code of the audio (e.g., "en", "zh")
    /// - Returns: The recognized transcript as a String
    func recognize(audio: Data, language: String) async throws -> String
}

/// Provider for text-to-text translation.
public protocol TranslationProvider: Sendable {
    /// Translates text from source language to target language.
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceLanguage: Source language code (e.g., "en")
    ///   - targetLanguage: Target language code (e.g., "zh")
    /// - Returns: The translated text
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String
}

/// Provider for text-to-speech synthesis.
public protocol TTSProvider: Sendable {
    /// Synthesizes speech from text.
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - language: The language code for TTS (e.g., "zh")
    /// - Returns: Raw audio data (PCM format)
    func synthesize(text: String, language: String) async throws -> Data
}
