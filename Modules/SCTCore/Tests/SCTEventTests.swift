import XCTest
@testable import SCTCore

final class SCTEventTests: XCTestCase {
    func testEventEquality() {
        let event1 = SCTEvent.sessionStarted(sessionId: "123")
        let event2 = SCTEvent.sessionStarted(sessionId: "123")
        let event3 = SCTEvent.sessionStopped(sessionId: "123")
        
        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }
    
    func testDataEvents() {
        let data = Data([0x01, 0x02])
        let event = SCTEvent.audioCaptured(data)
        
        if case .audioCaptured(let capturedData) = event {
            XCTAssertEqual(capturedData, data)
        } else {
            XCTFail("Should be audioCaptured event")
        }
    }
}
