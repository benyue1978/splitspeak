import XCTest
@testable import SCTCore

final class SCTEventTests: XCTestCase {
    func testEventEquality() {
        let event1 = SCTEvent.sessionStarted(sessionId: "123")
        let event2 = SCTEvent.sessionStarted(sessionId: "123")
        XCTAssertEqual(event1, event2)
    }
}
