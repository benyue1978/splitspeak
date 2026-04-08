import Foundation
import SCTCore

/// Routes audio to the correct channel based on the current speaker.
/// Listens for speakerSelected events and audioCaptured events,
/// then plays captured audio to the correct ear.
public final class PassthroughProcessor: @unchecked Sendable {
    private let eventBus: EventBus
    private var currentSpeaker: String?

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    public func start() async {
        let stream = await eventBus.subscribe()
        for await event in stream {
            switch event {
            case .speakerSelected(let participantId):
                print("PassthroughProcessor: speaker selected = \(participantId)")
                self.currentSpeaker = participantId
            case .audioCaptured(let data):
                // Route audio based on current speaker
                // A (me) → right ear
                // B (foreigner) → left ear
                if currentSpeaker != nil {
                    let targetChannel: AudioChannel = (currentSpeaker == "A") ? .right : .left
                    await eventBus.publish(.ttsProduced(audioData: data, targetChannel: targetChannel))
                }
            default:
                break
            }
        }
    }
}
