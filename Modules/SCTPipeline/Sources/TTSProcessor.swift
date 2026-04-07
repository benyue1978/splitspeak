import Foundation
import SCTCore

/// Processes translated text through TTS pipeline.
///
/// Subscribes to:
/// - `translationProduced` → triggers TTS synthesis
///
/// Publishes:
/// - `ttsProduced` → consumed by StereoOutputSink
public actor TTSProcessor {
    private let eventBus: EventBus
    private let ttsProvider: TTSProvider
    private var listenerTask: Task<Void, Never>?

    public init(eventBus: EventBus, ttsProvider: TTSProvider) {
        self.eventBus = eventBus
        self.ttsProvider = ttsProvider
    }

    /// Starts listening for translationProduced events.
    public func start() async {
        listenerTask?.cancel()  // Cancel any existing listener
        let stream = await eventBus.subscribe()

        listenerTask = Task {
            for await event in stream {
                if case .translationProduced(let text, let targetLanguage, let participantId) = event {
                    await self.processTranslation(text: text, language: targetLanguage, participantId: participantId)
                }
            }
        }
    }

    /// Stops listening for events.
    public func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    /// Processes translation: synthesizes speech and publishes result.
    private func processTranslation(text: String, language: String, participantId: String) async {
        // Determine target channel based on participant
        // A → output to right channel (B hears)
        // B → output to left channel (A hears)
        let targetChannel: AudioChannel

        switch participantId {
        case "A", "userA":
            targetChannel = .right
        case "B", "userB":
            targetChannel = .left
        default:
            await eventBus.publish(.errorOccurred("Unknown participant for routing: \(participantId)"))
            return
        }

        do {
            let audioData = try await ttsProvider.synthesize(text: text, language: language)

            await eventBus.publish(.ttsProduced(
                audioData: audioData,
                targetChannel: targetChannel
            ))
        } catch {
            await eventBus.publish(.errorOccurred("TTS failed: \(error)"))
        }
    }
}
