import XCTest
@testable import SCTCore
@testable import SCTConversation

final class SCTConversationTests: XCTestCase {

    // MARK: - SessionOrchestrator Tests

    func testSessionOrchestratorInitialState() async {
        let eventBus = EventBus()
        let orchestrator = SessionOrchestrator(eventBus: eventBus)

        let state = await orchestrator.state
        XCTAssertEqual(state, .idle)
    }

    func testSessionOrchestratorStartTransition() async throws {
        let eventBus = EventBus()
        let orchestrator = SessionOrchestrator(eventBus: eventBus)

        try await orchestrator.start(sessionId: "test-session-1")

        let state = await orchestrator.state
        XCTAssertEqual(state, .active)

        let session = await orchestrator.getSession()
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.id, "test-session-1")
    }

    func testSessionOrchestratorStopTransition() async throws {
        let eventBus = EventBus()
        let orchestrator = SessionOrchestrator(eventBus: eventBus)

        try await orchestrator.start(sessionId: "test-session-1")
        await orchestrator.stop()

        let state = await orchestrator.state
        XCTAssertEqual(state, .idle)

        let session = await orchestrator.getSession()
        XCTAssertNil(session)
    }

    func testSessionOrchestratorCannotStartWhenActive() async throws {
        let eventBus = EventBus()
        let orchestrator = SessionOrchestrator(eventBus: eventBus)

        try await orchestrator.start(sessionId: "session-1")

        do {
            try await orchestrator.start(sessionId: "session-2")
            XCTFail("Should have thrown")
        } catch SessionOrchestratorError.sessionAlreadyActive {
            // Expected
        }
    }

    func testSessionOrchestratorReportError() async throws {
        let eventBus = EventBus()
        let orchestrator = SessionOrchestrator(eventBus: eventBus)

        try await orchestrator.start(sessionId: "test-session")
        await orchestrator.reportError("Test error")

        let state = await orchestrator.state
        XCTAssertEqual(state, .error)
    }

    // MARK: - TurnManager Tests

    func testTurnManagerInitialState() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        let state = await turnManager.turnState
        XCTAssertEqual(state, .waiting)

        let speaker = await turnManager.currentSpeaker
        XCTAssertNil(speaker)
    }

    func testTurnManagerSelectSpeakerATransitions() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")

        let state = await turnManager.turnState
        XCTAssertEqual(state, .speaking)

        let speaker = await turnManager.currentSpeaker
        XCTAssertEqual(speaker, .userA)
    }

    func testTurnManagerSelectSpeakerBTransitions() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userB")

        let state = await turnManager.turnState
        XCTAssertEqual(state, .speaking)

        let speaker = await turnManager.currentSpeaker
        XCTAssertEqual(speaker, .userB)
    }

    func testTurnManagerRouteDecidedForUserA() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        // Listen for route decision
        let stream = await eventBus.subscribe()
        let listenerTask = Task {
            for await event in stream {
                if case .routeDecided(let channel, _) = event {
                    // A speaks → right channel
                    XCTAssertEqual(channel, .right)
                    return
                }
            }
        }

        await turnManager.selectSpeaker("userA")

        // Give time for event to propagate
        try? await Task.sleep(nanoseconds: 50_000_000)
        listenerTask.cancel()
    }

    func testTurnManagerRouteDecidedForUserB() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        // Listen for route decision
        let stream = await eventBus.subscribe()
        let listenerTask = Task {
            for await event in stream {
                if case .routeDecided(let channel, _) = event {
                    // B speaks → left channel
                    XCTAssertEqual(channel, .left)
                    return
                }
            }
        }

        await turnManager.selectSpeaker("userB")

        // Give time for event to propagate
        try? await Task.sleep(nanoseconds: 50_000_000)
        listenerTask.cancel()
    }

    func testTurnManagerInjectTextTransitionsToProcessing() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")
        await turnManager.injectText("Hello", speaker: .userA)

        let state = await turnManager.turnState
        XCTAssertEqual(state, .processing)
    }

    func testTurnManagerBeginOutput() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")
        await turnManager.injectText("Hello", speaker: .userA)
        await turnManager.beginOutput()  // Note: beginOutput is now async

        let state = await turnManager.turnState
        XCTAssertEqual(state, .output)
    }

    func testTurnManagerEndTurn() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")
        await turnManager.injectText("Hello", speaker: .userA)
        await turnManager.beginOutput()
        await turnManager.endTurn(speaker: .userA)

        let state = await turnManager.turnState
        XCTAssertEqual(state, .waiting)

        let speaker = await turnManager.currentSpeaker
        XCTAssertNil(speaker)
    }

    func testTurnManagerCannotSelectSpeakerWhenNotWaiting() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")
        // Try to select speaker again while in speaking state
        await turnManager.selectSpeaker("userB")

        // Should still be userA
        let speaker = await turnManager.currentSpeaker
        XCTAssertEqual(speaker, .userA)
    }

    func testTurnManagerReset() async {
        let eventBus = EventBus()
        let turnManager = TurnManager(eventBus: eventBus)

        await turnManager.selectSpeaker("userA")
        await turnManager.injectText("Hello", speaker: .userA)
        await turnManager.beginOutput()

        await turnManager.reset()

        let state = await turnManager.turnState
        XCTAssertEqual(state, .waiting)

        let speaker = await turnManager.currentSpeaker
        XCTAssertNil(speaker)
    }

    // MARK: - TurnState Tests

    func testTurnStateEquality() {
        XCTAssertEqual(TurnState.waiting, .waiting)
        XCTAssertEqual(TurnState.speaking, .speaking)
        XCTAssertEqual(TurnState.processing, .processing)
        XCTAssertEqual(TurnState.output, .output)
    }
}
