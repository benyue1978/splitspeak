import XCTest
@testable import SCTCore

final class EventBusTests: XCTestCase {
    func testEventPublishAndSubscribe() async throws {
        let eventBus = EventBus()
        let eventStream = await eventBus.subscribe()
        
        // Run listener in background task
        let expectation = XCTestExpectation(description: "Receive event")
        let task = Task {
            for await event in eventStream {
                if case .sessionStarted(let id) = event, id == "test" {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        await eventBus.publish(.sessionStarted(sessionId: "test"))
        
        await fulfillment(of: [expectation], timeout: 1.0)
        task.cancel()
    }
}
