# SCTCore Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the foundational models (Session, Participant) and the EventBus for the stereo conversational translator.

**Architecture:** A standalone Swift Package (`SCTCore`). Models are simple structs. `EventBus` is an actor utilizing Swift Concurrency (`AsyncStream`) to provide a thread-safe, reactive event stream to subscribers.

**Tech Stack:** Swift 5.9, Swift Concurrency, XCTest.

---

### Task 1: Define Core Models (Participant & Session)

**Files:**
- Create: `Modules/SCTCore/Sources/Models.swift`
- Create: `Modules/SCTCore/Tests/ModelsTests.swift`

- [ ] **Step 1: Write the failing test for Models**

```swift
// Modules/SCTCore/Tests/ModelsTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL with "cannot find 'Participant' in scope" and "cannot find 'Session' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// Modules/SCTCore/Sources/Models.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Modules/SCTCore/Sources/Models.swift Modules/SCTCore/Tests/ModelsTests.swift
git commit -m "feat(SCTCore): add Participant and Session models"
```

---

### Task 2: Define SCTEvent Enum

**Files:**
- Create: `Modules/SCTCore/Sources/SCTEvent.swift`
- Create: `Modules/SCTCore/Tests/SCTEventTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Modules/SCTCore/Tests/SCTEventTests.swift
import XCTest
@testable import SCTCore

final class SCTEventTests: XCTestCase {
    func testEventEquality() {
        let event1 = SCTEvent.sessionStarted(sessionId: "123")
        let event2 = SCTEvent.sessionStarted(sessionId: "123")
        XCTAssertEqual(event1, event2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL with "cannot find 'SCTEvent' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// Modules/SCTCore/Sources/SCTEvent.swift
import Foundation

public enum SCTEvent: Equatable {
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Modules/SCTCore/Sources/SCTEvent.swift Modules/SCTCore/Tests/SCTEventTests.swift
git commit -m "feat(SCTCore): define SCTEvent enum"
```

---

### Task 3: Implement EventBus

**Files:**
- Create: `Modules/SCTCore/Sources/EventBus.swift`
- Create: `Modules/SCTCore/Tests/EventBusTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Modules/SCTCore/Tests/EventBusTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `just test`
Expected: FAIL with "cannot find 'EventBus' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// Modules/SCTCore/Sources/EventBus.swift
import Foundation

public actor EventBus {
    private var continuations: [UUID: AsyncStream<SCTEvent>.Continuation] = [:]
    
    public init() {}
    
    public func subscribe() -> AsyncStream<SCTEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            self.continuations[id] = continuation
            
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    public func publish(_ event: SCTEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `just test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Modules/SCTCore/Sources/EventBus.swift Modules/SCTCore/Tests/EventBusTests.swift
git commit -m "feat(SCTCore): implement async EventBus"
```

---

### Task 4: Clean up Initial Files

**Files:**
- Modify: `Modules/SCTCore/Sources/SCTCore.swift` (Delete)
- Modify: `Modules/SCTCore/Tests/SCTCoreTests.swift` (Delete)

- [ ] **Step 1: Delete placeholder files**
Run: `rm Modules/SCTCore/Sources/SCTCore.swift Modules/SCTCore/Tests/SCTCoreTests.swift`

- [ ] **Step 2: Run tests to verify the project still builds**
Run: `just test`
Expected: PASS

- [ ] **Step 3: Commit**
```bash
git rm Modules/SCTCore/Sources/SCTCore.swift Modules/SCTCore/Tests/SCTCoreTests.swift
git commit -m "chore(SCTCore): remove placeholder files"
```
