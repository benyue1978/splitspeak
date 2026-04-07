import XCTest
@testable import SCTCore

final class EventBusTests: XCTestCase {
    
    /// Basic publish and subscribe test
    func testEventPublishAndSubscribe() async throws {
        let eventBus = EventBus()
        let eventStream = await eventBus.subscribe()
        
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
    
    /// Test that multiple subscribers receive the same event
    func testMultipleSubscribers() async throws {
        let eventBus = EventBus()
        let count = 5
        var expectations: [XCTestExpectation] = []
        var tasks: [Task<Void, Never>] = []
        
        for i in 0..<count {
            let exp = XCTestExpectation(description: "Subscriber \(i) receives event")
            expectations.append(exp)
            
            let stream = await eventBus.subscribe()
            let task = Task {
                for await event in stream {
                    if case .sessionStarted(let id) = event, id == "multi-test" {
                        exp.fulfill()
                        break
                    }
                }
            }
            tasks.append(task)
        }
        
        // Wait a bit to ensure all tasks are listening
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        await eventBus.publish(.sessionStarted(sessionId: "multi-test"))
        
        await fulfillment(of: expectations, timeout: 1.0)
        
        for task in tasks {
            task.cancel()
        }
    }
    
    /// Test that subscribers are cleaned up when they are deallocated
    func testSubscriberCleanup() async throws {
        let eventBus = EventBus()
        
        // Use a nested function to ensure the stream is dropped
        @Sendable func subscribeAndDrop(bus: EventBus) async {
            let _ = await bus.subscribe()
            // Stream is dropped here as it goes out of scope
        }
        
        await subscribeAndDrop(bus: eventBus)
        
        // Cleanup happens in a background task within onTermination
        // We need to wait a bit for the Task to execute
        var currentCount = 1
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            currentCount = await eventBus.subscriptionCount()
            if currentCount == 0 { break }
        }
        
        XCTAssertEqual(currentCount, 0, "Subscriber should have been removed from the bus after being dropped")
    }
    
    /// Test concurrent publishing to ensure no race conditions
    func testConcurrentPublishing() async throws {
        let eventBus = EventBus()
        let subscriberCount = 3
        let eventCount = 100
        
        actor TestCounter {
            var counts = [Int: Int]()
            func increment(for index: Int) {
                counts[index, default: 0] += 1
            }
            func getCount(for index: Int) -> Int {
                counts[index, default: 0]
            }
        }
        
        let counter = TestCounter()
        var expectations: [XCTestExpectation] = []
        var tasks: [Task<Void, Never>] = []
        
        for i in 0..<subscriberCount {
            let exp = XCTestExpectation(description: "Subscriber \(i) finished")
            exp.expectedFulfillmentCount = eventCount
            expectations.append(exp)
            
            let stream = await eventBus.subscribe()
            let task = Task {
                for await _ in stream {
                    await counter.increment(for: i)
                    exp.fulfill()
                }
            }
            tasks.append(task)
        }
        
        // Publish from multiple tasks concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<eventCount {
                group.addTask {
                    await eventBus.publish(.sessionStarted(sessionId: "event-\(i)"))
                }
            }
        }
        
        await fulfillment(of: expectations, timeout: 5.0)
        
        for i in 0..<subscriberCount {
            let count = await counter.getCount(for: i)
            XCTAssertEqual(count, eventCount, "Subscriber \(i) missed some events")
        }
        
        for task in tasks {
            task.cancel()
        }
    }
    
    /// Test buffering policy
    func testBufferingPolicy() async throws {
        let eventBus = EventBus()
        // Subscriber with small buffer (keeps only the 2 newest events)
        let stream = await eventBus.subscribe(bufferingPolicy: .bufferingNewest(2))
        
        // Publish 5 events without consuming
        for i in 0..<5 {
            await eventBus.publish(.errorOccurred("error-\(i)"))
        }
        
        var received: [SCTEvent] = []
        var iterator = stream.makeAsyncIterator()
        
        // Should only have the last 2 events (3 and 4)
        if let event = await iterator.next() { received.append(event) }
        if let event = await iterator.next() { received.append(event) }
        
        XCTAssertEqual(received.count, 2)
        if case .errorOccurred(let msg1) = received[0] {
            XCTAssertEqual(msg1, "error-3")
        }
        if case .errorOccurred(let msg2) = received[1] {
            XCTAssertEqual(msg2, "error-4")
        }
    }
}
