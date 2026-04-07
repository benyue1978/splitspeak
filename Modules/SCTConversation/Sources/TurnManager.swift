import Foundation
import SCTCore

/// Manages turn protocol and routing decisions.
///
/// Turn state machine:
/// ```
/// waiting ←→ speaking ←→ processing ←→ output
///    ↑                                        ↓
///    └────────────── TurnEnded ────────────────┘
/// ```
///
/// Responsibilities:
/// - Track current speaker
/// - Enforce turn state machine
/// - Make routing decisions (A → Right, B → Left)
/// - Publish RouteDecision events
public actor TurnManager {
    private let eventBus: EventBus

    /// Current turn state
    public private(set) var turnState: TurnState = .waiting

    /// Current speaker, if any
    public private(set) var currentSpeaker: ParticipantRole?

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    /// Called when UI selects a speaker.
    /// - Parameter participantId: The participant ID ("A" or "B")
    public func selectSpeaker(_ participantId: String) async {
        guard turnState == .waiting else { return }

        guard let role = ParticipantRole(rawValue: participantId) else { return }

        currentSpeaker = role
        turnState = .speaking

        // Publish turn started
        await eventBus.publish(.turnStarted(speaker: role))

        // Make routing decision
        let targetChannel: AudioChannel
        let reason: String

        switch role {
        case .userA:
            targetChannel = .right  // A speaks → output to B (right channel)
            reason = "A speaks, output to B"
        case .userB:
            targetChannel = .left  // B speaks → output to A (left channel)
            reason = "B speaks, output to A"
        }

        await eventBus.publish(.routeDecided(targetChannel: targetChannel, reason: reason))
    }

    /// Called when manual text is injected.
    /// - Parameters:
    ///   - text: The injected text
    ///   - speaker: The speaker role
    public func injectText(_ text: String, speaker: ParticipantRole) async {
        guard turnState == .speaking, currentSpeaker == speaker else { return }

        turnState = .processing

        // Publish manual text injected event for processors to consume
        await eventBus.publish(.manualTextInjected(text, participantId: speaker.rawValue))
    }

    /// Called when output phase begins (processors publish translation).
    public func beginOutput() {
        guard turnState == .processing else { return }
        turnState = .output
    }

    /// Called when turn ends.
    /// - Parameter speaker: The speaker whose turn is ending
    public func endTurn(speaker: ParticipantRole) async {
        guard turnState == .output else {
            // Fallback: reset to waiting from any state
            turnState = .waiting
            currentSpeaker = nil
            return
        }

        turnState = .waiting
        currentSpeaker = nil

        await eventBus.publish(.turnEnded(speaker: speaker))
    }

    /// Resets turn state to waiting (for error recovery).
    public func reset() {
        turnState = .waiting
        currentSpeaker = nil
    }
}
