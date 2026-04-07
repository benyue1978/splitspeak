import Foundation

/// Represents the state of a turn in the conversation.
///
/// A "turn" is a period where one participant is speaking/inputting text,
/// which then gets processed and output to the other participant.
public enum TurnState: Equatable, Sendable {
    /// Waiting for a speaker to be selected
    case waiting

    /// User is currently speaking (text being entered)
    case speaking

    /// Text submitted, pipeline is running
    case processing

    /// Audio/text being output to sinks
    case output
}
