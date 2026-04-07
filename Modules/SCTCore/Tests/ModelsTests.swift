import XCTest
@testable import SCTCore

final class ModelsTests: XCTestCase {
    func testParticipantCreation() {
        let participant = Participant(id: "userA", role: .userA, sourceLanguage: "en", targetLanguage: "zh", assignedChannel: .right)
        XCTAssertEqual(participant.id, "userA")
        XCTAssertEqual(participant.role, .userA)
        XCTAssertEqual(participant.assignedChannel, .right)
    }
    
    func testSessionInitialization() {
        let pA = Participant(id: "A", role: .userA, sourceLanguage: "en", targetLanguage: "zh", assignedChannel: .right)
        let pB = Participant(id: "B", role: .userB, sourceLanguage: "zh", targetLanguage: "en", assignedChannel: .left)
        let session = Session(id: "session1", participants: [pA, pB])
        
        XCTAssertEqual(session.id, "session1")
        XCTAssertEqual(session.participants.count, 2)
        XCTAssertEqual(session.state, .idle)
    }
}
