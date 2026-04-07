# SessionOrchestrator & TurnManager Design

## 1. Overview

### Purpose
SessionOrchestrator and TurnManager form the coordination layer of the SCT system.

### Architecture
- **EventBus** is the central hub for all communication
- **Orchestrator** is minimal — session lifecycle only
- **TurnManager** owns turn protocol and routing decisions
- **Processors** subscribe to events, publish results
- **Sinks** subscribe to events, handle output

## 2. Orchestrator Responsibilities

### Session State Machine
```
idle ←→ active
         ↓
       error
```

**States:**
- `idle` — No session active
- `active` — Session running
- `error` — Error occurred

**Transitions:**
- `idle` → `active`: SessionStarted
- `active` → `idle`: SessionStopped
- `active` → `error`: ErrorOccurred
- `error` → `idle`: SessionStopped

**Responsibilities:**
- Create/destroy session
- Track session state
- Handle errors (log, emit ErrorOccurred)
- Does NOT call processors directly — events flow through EventBus

## 3. TurnManager Responsibilities

### Turn State Machine
```
waiting ←→ speaking ←→ processing ←→ output
   ↑                                        ↓
   └────────────── TurnEnded ────────────────┘
```

**States:**
- `waiting` — Waiting for speaker
- `speaking` — User is speaking (text being entered)
- `processing` — Text submitted, pipeline running
- `output` — Audio/text being output to sinks

**Transitions:**
- `waiting` → `speaking`: SpeakerSelected
- `speaking` → `processing`: ManualTextInjected
- `processing` → `output`: TranslationProduced (routed to sinks)
- `output` → `waiting`: TurnEnded
- Any → `waiting`: TurnEnded (fallback)

### Speaker Tracking
- Current speaker: `ParticipantRole?` (A or B or nil)
- TurnManager decides route when speaker selected:
  - A speaking → RouteDecision(targetChannel: .right, reason: "A speaks, output to B")
  - B speaking → RouteDecision(targetChannel: .left, reason: "B speaks, output to A")

### Events Published
- `turnStarted(speaker: ParticipantRole)`
- `turnEnded(speaker: ParticipantRole)`
- `routeDecided(targetChannel: AudioChannel, reason: String)`

## 4. Event Flow

### Manual Text Input MVP Flow
```
1. User taps "A Speaking"
      ↓
2. UI publishes: SpeakerSelected(participantId: "A")
      ↓
3. TurnManager receives:
   - If waiting: transition to speaking
   - Publish: TurnStarted(speaker: A)
   - Publish: RouteDecided(targetChannel: right, reason: "A→B")
      ↓
4. User types text and taps "Send"
      ↓
5. UI publishes: ManualTextInjected(text: "...", participantId: "A")
      ↓
6. TranslationProcessor subscribes, processes:
   - Publishes: TranslationProduced(text: "...", targetLanguage: "zh", speaker: A)
      ↓
7. Sinks subscribe:
   - SubtitleSink: displays text
   - StereoOutputSink: receives text → TTS → audio → plays on right channel
      ↓
8. User taps "Done"
      ↓
9. UI publishes: TurnEnded
      ↓
10. TurnManager: output → waiting
```

## 5. New Events

### Events (add to SCTEvent enum)

```swift
// Session
case sessionStarted(sessionId: String)
case sessionStopped(sessionId: String)

// Turn Management
case speakerSelected(participantId: String)       // From UI
case turnStarted(speaker: ParticipantRole)          // From TurnManager
case turnEnded(speaker: ParticipantRole)           // From UI
case routeDecided(targetChannel: AudioChannel, reason: String)  // From TurnManager

// Input
case manualTextInjected(String, participantId: String)  // From UI

// Pipeline (existing)
case transcriptProduced(text: String, participantId: String)
case translationProduced(text: String, targetLanguage: String, participantId: String)

// Output (existing)
case ttsProduced(audioData: Data, targetChannel: AudioChannel)
```

## 6. Key Design Decisions

### Decision: Orchestrator is Minimal
- Session lifecycle only
- Does NOT trigger processors
- Events flow directly between UI, TurnManager, Processors, Sinks
- This keeps Orchestrator simple and testable

### Decision: TurnManager Makes Routing Decisions
- TurnManager knows current speaker
- TurnManager publishes RouteDecided
- Router/Sinks just follow the decision
- Keeps routing logic centralized in TurnManager

### Decision: Text is Universal Intermediate Format
- All pipeline output is text-based
- Sinks transform text to their required format:
  - SubtitleSink: text → display (noop)
  - StereoOutputSink: text → TTS → audio
- Extensible: new sinks just add their transform

## 7. Module Structure

```
Modules/
├── SCTCore/
│   ├── Sources/
│   │   ├── Models.swift        # Participant, Session, ParticipantRole, AudioChannel
│   │   ├── SCTEvent.swift       # All event definitions
│   │   └── EventBus.swift       # EventBus actor
│   └── Tests/

├── SCTConversation/
│   ├── Sources/
│   │   ├── SessionOrchestrator.swift   # Session state machine
│   │   ├── TurnManager.swift          # Turn state machine + routing
│   │   └── SessionState.swift           # Session state enum
│   │   └── TurnState.swift             # Turn state enum
│   └── Tests/

├── SCTPipeline/
│   ├── Sources/
│   │   ├── ProviderInterfaces.swift    # ASRProvider, TranslationProvider, TTSProvider
│   │   ├── Processors/
│   │   │   ├── TranslationProcessor.swift
│   │   │   └── MockProcessors.swift
│   │   └── TextTransform.swift
│   └── Tests/

├── SCTRouting/
│   ├── Sources/
│   │   └── RoutingPolicy.swift    # A→Right, B→Left logic
│   └── Tests/

├── SCTAudio/
│   ├── Sources/
│   │   ├── StereoOutputSink.swift  # Already implemented
│   │   └── SubtitleSink.swift       # New: displays text
│   └── Tests/

└── SCTUI/
    ├── Sources/
    │   ├── UserModeView.swift
    │   ├── DevModeView.swift
    │   └── EventTimelineView.swift
    └── Tests/
```

## 8. Implementation Order

### Step 1: SCTConversation Module
1. Create SessionOrchestrator (minimal — session state only)
2. Create TurnManager (turn state + routing decisions)
3. Add new events to SCTEvent
4. Unit tests for state machines

### Step 2: Wire Up Fake Pipeline
1. Create MockProcessors
2. TranslationProcessor with mock or real translation
3. Verify event flow: SpeakerSelected → TurnStarted → TranslationProduced → Sinks

### Step 3: SubtitleSink
1. Implement SubtitleSink (receives TranslationProduced, stores for display)
2. UI displays subtitles

### Step 4: Integration Test
1. Full flow: SpeakerSelected → ManualTextInjected → Translation → Subtitle + Audio
2. Verify routing: A → Right, B → Left

## 9. Test Scenarios

### SessionOrchestrator Tests
- idle → active on SessionStarted
- active → idle on SessionStopped
- active → error on ErrorOccurred

### TurnManager Tests
- waiting → speaking on SpeakerSelected
- speaking → processing on ManualTextInjected
- output → waiting on TurnEnded
- RouteDecided published correctly (A → right, B → left)

### Integration Tests
- SpeakerSelected(A) → RouteDecided(right)
- SpeakerSelected(B) → RouteDecided(left)
- ManualTextInjected → TranslationProduced
- TranslationProduced → Sinks receive

## 10. API Surface

### SessionOrchestrator (Actor)
```swift
public actor SessionOrchestrator {
    public func start(sessionId: String) throws
    public func stop()
    public var state: SessionState { get }
}
```

### TurnManager (Actor)
```swift
public actor TurnManager {
    public func selectSpeaker(_ participantId: String) async
    public func injectText(_ text: String, speaker: ParticipantRole) async
    public func endTurn(speaker: ParticipantRole) async
    public var currentSpeaker: ParticipantRole? { get }
    public var turnState: TurnState { get }
}
```

## 11. DoD Check

- [ ] SessionOrchestrator correctly transitions states
- [ ] TurnManager correctly tracks speaker
- [ ] RouteDecided published when speaker selected
- [ ] All state machine transitions tested
- [ ] Event flow connects UI → TurnManager → Processors → Sinks
