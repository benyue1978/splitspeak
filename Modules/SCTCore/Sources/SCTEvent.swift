import Foundation

public enum SCTEvent: Equatable, Sendable {
    // Session
    case sessionStarted(sessionId: String)
    case sessionStopped(sessionId: String)
    case speakerSelected(participantId: String)
    
    // Input
    case audioCaptured(Data)
    case manualTextInjected(String, participantId: String)
    
    // Pipeline Events
    case transcriptProduced(text: String, participantId: String)
    case translationProduced(text: String, targetLanguage: String, participantId: String)
    case ttsProduced(audioData: Data, targetChannel: AudioChannel)
    
    // Routing/Output
    case routeDecided(targetChannel: AudioChannel, reason: String)
    case errorOccurred(String)
}
