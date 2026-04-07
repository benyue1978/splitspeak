# Stereo Conversational Translator (SCT) - MVP Architecture & Context

## 1. MVP Goal

Single device + single headset + dual-person conversation translation (via left/right channel separation).

---

## 2. MVP Scope

### Supported
- 2-person conversation
- 2 languages (e.g., EN ↔ ZH)
- Real-time translation
- Left/right channel separation output

### Not Supported
- Multiple participants
- Advanced speaker diarization
- Offline mode
- Multi-device sync

---

## 3. MVP Architecture

```
Mic Input
   ↓
VAD
   ↓
Turn Detection (simple rule-based)
   ↓
ASR
   ↓
Translation
   ↓
TTS
   ↓
Channel Routing (L / R)
   ↓
Stereo Output
```

---

## 4. Core Logic

### Rules
- User A → Output to Right Channel
- User B → Output to Left Channel

---

## 5. Speaker Determination (MVP Solution)

No complex models. Use:
- Turn-taking (turn-based)
- Volume direction (simple heuristic)
- Manual select A/B (fallback)

---

## 6. Key Requirements

- Mono Audio must be OFF
- Latency control < 2.5s
- Discard stale audio (no queuing)

---

## 7. UI Requirements

- Display bilingual subtitles
- Identify current speaker
- Prompt wearing direction (L/R)

---

## 8. Success Criteria

- Users can converse continuously
- No need to pass the phone
- Basically understandable

---

## 9. Development Roadmap

### Phase 0: Basic Capability Verification (Audio)
Goal: Prove "left/right channel separation works"

### Phase 1: Single Audio Routing
Goal: Control "who hears what"

### Phase 2: Speech Processing Foundation
Goal: Connect speech pipeline

### Phase 3: Translation Integration
Goal: Complete semantic conversion

### Phase 4: TTS Output
Goal: Close the loop

### Phase 5: Dual-Person Mode (Core)
Goal: Simulate Timekettle

### Phase 6: Optimization (Key Experience)
Goal: Latency reduction, interruption mechanism

### Phase 7 (Optional): Dual Device Mode
Goal: Each person has one device, network sync

### Phase 8 (Future)
- Real speaker diarization
- On-device model
- Agent integration

---

## 10. Architecture Style

Event-driven conversational real-time audio processing architecture.

Core principles:
- **Session-first**: All processing centers around a session
- **Event-driven**: Modules communicate via events
- **Pipeline-pluggable**: ASR / Translate / TTS are replaceable processing nodes
- **Routing-separated**: Routing is an independent layer
- **Observability-built-in**: Logs, events, latency, routing decisions visible from day one
- **Capability-aware**: Verify iPhone + Bluetooth headphone stereo feasibility first

---

## 11. Core Concepts

### 11.1 Session
A dual-person conversation session.

Responsibilities:
- Participant info
- Language config
- Left/right ear binding
- Current state
- Interruption policy
- Provider config
- Debug switches

### 11.2 Participant
- id
- role: A / B
- sourceLanguage
- targetLanguage
- assignedChannel: left / right

### 11.3 Event
The sole communication unit in the system. All modules receive events and emit events.

### 11.4 Processor
Modules that process events and produce new events.

Examples:
- AudioCaptureProcessor
- TurnManager
- ASRProcessor
- TranslationProcessor
- TTSProcessor
- RoutingProcessor

### 11.5 Sink
Final output targets.

MVP initially implements:
- StereoOutputSink
- SubtitleSink

### 11.6 Orchestrator
Session-level coordinator.

Responsibilities:
- Who is currently speaking
- Current turn lifecycle
- When to trigger processing stages
- Interruption/queuing policy
- State consistency

---

## 12. Recommended Layer Structure

### 12.1 Platform Layer
- iOS Audio Session
- Bluetooth device output
- Microphone permissions
- Stereo output capability
- Left/right channel testing
- Interruption handling

### 12.2 Core Layer
- Session model
- Event model
- EventBus
- Basic state machine
- ID / timestamp / correlation

### 12.3 Conversation Layer
- Participant management
- Current turn
- Manual speaker assignment
- Turn-based flow control
- Interruption policy

### 12.4 Pipeline Layer
- ASR provider abstraction
- Translation provider abstraction
- TTS provider abstraction
- Processing node interfaces
- Fake input/output nodes

### 12.5 Routing Layer
- Route decision
- Send results to left / right / subtitle

### 12.6 Sink Layer
- StereoOutputSink
- SubtitleSink

### 12.7 Observability Layer
- Event log
- Timeline
- Latency tracing
- Route decision log
- Transcript/translation/TTS result recording
- Debug UI data source

---

## 13. Event Model

### 13.1 Session
- SessionStarted
- SessionStopped
- SessionStateChanged

### 13.2 Input
- AudioCaptured
- ManualTextInjected
- SpeakerSelected

### 13.3 Turn
- TurnStarted
- TurnEnded

### 13.4 Semantic
- TranscriptProduced
- TranslationProduced

### 13.5 Audio Generation
- TTSRequested
- TTSProduced

### 13.6 Routing
- RouteDecided
- OutputQueued
- OutputStarted
- OutputFinished

### 13.7 Debug/Error
- MetricRecorded
- WarningRaised
- ErrorOccurred

---

## 14. Routing Rules

### Core Rules
- A speaks → Output to Right
- B speaks → Output to Left

### Subtitle Rules
- Both transcript and translation go to subtitle sink
- Dev mode shows complete intermediate results
- User mode shows only necessary content

---

## 15. Provider Abstraction

Define 3 interfaces from day one:

### ASRProvider
Input: audio / audioRef
Output: transcript

### TranslationProvider
Input: text + sourceLanguage + targetLanguage
Output: translatedText

### TTSProvider
Input: text + targetLanguage + voiceConfig
Output: audio buffer / playable asset

---

## 16. Minimum State Machine

At least these states:
- idle
- session_ready
- waiting_for_speaker
- capturing_input
- processing_turn
- playing_output
- error

---

## 17. Interruption Policy

MVP needs only 3 types:
- interrupt_immediately
- queue
- latest_wins

Default: queue for turn-based mode

---

## 18. Development Order

1. **Stereo Capability Verification**
   - Left/right channel test tones
   - Different audio to left/right
   - Confirm Bluetooth headphone behavior

2. **Core Skeleton**
   - Session
   - EventBus
   - Event types
   - Dev timeline

3. **Fake Pipeline**
   - Manual speaker
   - Manual text input
   - Fake translation / real translation
   - Real or fake TTS
   - Route to left/right + subtitle

4. **Connect TTS**

5. **Connect ASR**

6. **Connect Real Microphone Turn-based**

7. **Optimize latency, replay, error handling**

---

## 19. Provider Interface Definitions (Draft)

```swift
public protocol ASRProvider: Sendable {
    func recognize(audio: Data) async throws -> String
}

public protocol TranslationProvider: Sendable {
    func translate(text: String, from: String, to: String) async throws -> String
}

public protocol TTSProvider: Sendable {
    func synthesize(text: String, language: String) async throws -> Data
}
```
