import Foundation
import SCTCore

/// Orchestrates session lifecycle.
///
/// Minimal by design - only manages session state transitions.
/// Does NOT call processors directly - events flow through EventBus.
///
/// Session state machine:
/// ```
/// idle ←→ active
///          ↓
///        error
/// ```
public actor SessionOrchestrator {
    private let eventBus: EventBus

    /// Current session, if any
    private var currentSession: Session?

    /// The current session state
    public private(set) var state: SessionState = .idle

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    /// Starts a new session.
    /// - Parameter sessionId: The unique identifier for the session
    public func start(sessionId: String) async throws {
        guard state == .idle else {
            throw SessionOrchestratorError.sessionAlreadyActive
        }

        // Create participants A and B with opposing channel assignments
        let participantA = Participant(
            id: "A",
            role: .userA,
            sourceLanguage: "en",
            targetLanguage: "zh",
            assignedChannel: .right  // A speaks → output to right channel (B hears)
        )
        let participantB = Participant(
            id: "B",
            role: .userB,
            sourceLanguage: "zh",
            targetLanguage: "en",
            assignedChannel: .left  // B speaks → output to left channel (A hears)
        )

        let session = Session(id: sessionId, participants: [participantA, participantB], state: .active)
        currentSession = session
        state = .active

        await eventBus.publish(.sessionStarted(sessionId: sessionId))
    }

    /// Stops the current session.
    public func stop() async {
        guard let session = currentSession else { return }

        let sessionId = session.id
        currentSession = nil
        state = .idle

        await eventBus.publish(.sessionStopped(sessionId: sessionId))
    }

    /// Reports an error and transitions to error state.
    /// - Parameter message: Error description
    public func reportError(_ message: String) async {
        guard state == .active else { return }
        state = .error

        await eventBus.publish(.errorOccurred(message))
    }

    /// Returns the current session, if any.
    public func getSession() -> Session? {
        return currentSession
    }
}

public enum SessionOrchestratorError: Error, Sendable {
    case sessionAlreadyActive
    case noSessionActive
}
