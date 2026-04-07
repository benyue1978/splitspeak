# Pipeline & Mock Processors Design

## 1. Overview

The Pipeline module sits between Input (manual text/audio) and Output (Sinks). It transforms input text/audio through ASR → Translation → TTS stages using pluggable providers.

**Key principle:** Text is the universal intermediate format. All pipeline output is text-based; sinks transform to their required format.

## 2. Architecture

```
EventBus (SCTEvent)
      │
      ├── speakerSelected ───────────────────────────→ TurnManager
      ├── manualTextInjected ────────────────────────→ TranslationProcessor
      │                                                      │
      │                                                      ▼
      │                                            translationProduced ──→ SubtitleSink
      │                                                      │               (displays text)
      │                                                      ▼
      │                                              TTSProcessor
      │                                                      │
      │                                                      ▼
      │                                            ttsProduced ────────→ StereoOutputSink
      │                                                                           (audio on L/R)
```

## 3. Provider Interfaces

### ASRProvider
```swift
public protocol ASRProvider: Sendable {
    func recognize(audio: Data, language: String) async throws -> String
}
```

### TranslationProvider
```swift
public protocol TranslationProvider: Sendable {
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String
}
```

### TTSProvider
```swift
public protocol TTSProvider: Sendable {
    func synthesize(text: String, language: String) async throws -> Data
}
```

## 4. Mock Providers

### MockASRProvider
- Returns a predefined transcript based on audio hash, or "Mock transcript for [language]"
- For MVP: simply wraps the input or returns fixed text

### MockTranslationProvider
- For MVP: returns "[translated] \(text)" with target language prefix
- Demonstrates the flow without real API calls

### MockTTSProvider
- Returns short audio buffer (sine wave tone) for testing
- Proves the audio pipeline without real TTS

## 5. Processors

### TranslationProcessor
```swift
public actor TranslationProcessor {
    public init(eventBus: EventBus, translationProvider: TranslationProvider)

    // Subscribes to: manualTextInjected
    // Publishes: translationProduced
}
```

Flow:
1. Receives `manualTextInjected(text, participantId)`
2. Determines target language from participant
3. Calls `translationProvider.translate()`
4. Publishes `translationProduced(text, targetLanguage, participantId)`

### TTSProcessor
```swift
public actor TTSProcessor {
    public init(eventBus: EventBus, ttsProvider: TTSProvider)

    // Subscribes to: translationProduced
    // Publishes: ttsProduced(audioData, targetChannel)
}
```

Flow:
1. Receives `translationProduced(text, targetLanguage, participantId)`
2. Calls `ttsProvider.synthesize()`
3. Determines target channel from participant's assignedChannel
4. Publishes `ttsProduced(audioData, targetChannel)`

## 6. Module Structure

```
Modules/SCTPipeline/
├── Sources/
│   ├── ProviderInterfaces.swift    # ASRProvider, TranslationProvider, TTSProvider
│   ├── MockProviders.swift         # Mock implementations
│   ├── TranslationProcessor.swift # Subscribes to manualTextInjected
│   ├── TTSProcessor.swift         # Subscribes to translationProduced
│   └── TextTransform.swift         # Noop for text, ASR for audio
└── Tests/
    └── PipelineTests.swift
```

## 7. Event Flow

### Text Input MVP Flow
```
1. SpeakerSelected(A) → TurnManager → RouteDecided(right)
2. ManualTextInjected("Hello", "A") → TranslationProcessor
3. TranslationProcessor → translationProduced("[translated] Hello", "zh", "A")
4. TTSProcessor → ttsProduced(audioData, .right)
5. StereoOutputSink plays audio on right channel
6. SubtitleSink displays both original and translated text
```

## 8. Dependencies

- SCTPipeline depends on SCTCore (EventBus, SCTEvent, Models)
- Processors do NOT call each other - they communicate only via events

## 9. Testing Strategy

### Unit Tests
- Mock providers return predictable values
- TranslationProcessor correctly transforms input → output
- TTSProcessor correctly routes to correct channel

### Integration Test (future)
- Full flow: manualTextInjected → translationProduced → ttsProduced

## 10. Definition of Done

- [ ] Provider interfaces defined and compilable
- [ ] MockTranslationProvider returns predictable translated text
- [ ] MockTTSProvider returns audio buffer
- [ ] TranslationProcessor publishes translationProduced on manualTextInjected
- [ ] TTSProcessor publishes ttsProduced on translationProduced
- [ ] Unit tests for processors pass
