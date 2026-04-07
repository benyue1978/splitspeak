import Foundation
import SCTCore

/// Processes text through translation pipeline.
///
/// Subscribes to:
/// - `manualTextInjected` → triggers translation
///
/// Publishes:
/// - `translationProduced` → consumed by TTSProcessor and SubtitleSink
public actor TranslationProcessor {
    private let eventBus: EventBus
    private let translationProvider: TranslationProvider
    private var listenerTask: Task<Void, Never>?

    public init(eventBus: EventBus, translationProvider: TranslationProvider) {
        self.eventBus = eventBus
        self.translationProvider = translationProvider
    }

    /// Starts listening for manualTextInjected events.
    public func start() async {
        listenerTask?.cancel()  // Cancel any existing listener
        let stream = await eventBus.subscribe()

        listenerTask = Task {
            for await event in stream {
                if case .manualTextInjected(let text, let participantId) = event {
                    await self.processText(text, participantId: participantId)
                }
            }
        }
    }

    /// Stops listening for events.
    public func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    /// Processes text injection: translates and publishes result.
    private func processText(_ text: String, participantId: String) async {
        // Get participant's target language
        // For MVP, we determine this from the speaker ID
        // A speaks English → target is Chinese (zh)
        // B speaks Chinese → target is English (en)
        let targetLanguage: String
        let sourceLanguage: String

        switch participantId {
        case "A", "userA":
            sourceLanguage = "en"
            targetLanguage = "zh"
        case "B", "userB":
            sourceLanguage = "zh"
            targetLanguage = "en"
        default:
            await eventBus.publish(.errorOccurred("Unknown participant: \(participantId)"))
            return
        }

        do {
            let translatedText = try await translationProvider.translate(
                text: text,
                from: sourceLanguage,
                to: targetLanguage
            )

            await eventBus.publish(.translationProduced(
                text: translatedText,
                targetLanguage: targetLanguage,
                participantId: participantId
            ))
        } catch {
            await eventBus.publish(.errorOccurred("Translation failed: \(error)"))
        }
    }
}
