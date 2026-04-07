import Foundation

public enum ParticipantRole: String, Equatable {
    case userA
    case userB
}

public enum AudioChannel: String, Equatable {
    case left
    case right
}

public enum SessionState: String, Equatable {
    case idle
    case active
    case error
}

public struct Participant: Equatable, Identifiable {
    public let id: String
    public let role: ParticipantRole
    public let sourceLanguage: String
    public let targetLanguage: String
    public let assignedChannel: AudioChannel
    
    public init(id: String, role: ParticipantRole, sourceLanguage: String, targetLanguage: String, assignedChannel: AudioChannel) {
        self.id = id
        self.role = role
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.assignedChannel = assignedChannel
    }
}

public struct Session: Equatable, Identifiable {
    public let id: String
    public let participants: [Participant]
    public var state: SessionState
    
    public init(id: String, participants: [Participant], state: SessionState = .idle) {
        self.id = id
        self.participants = participants
        self.state = state
    }
}
