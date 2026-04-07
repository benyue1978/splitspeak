# 📄 Design Spec: Stereo Conversational Translator (SCT) v1

## 1. Goal
Build a modular, event-driven iOS application that enables real-time, two-way translation using stereo audio separation (Left/Right channels) for two users sharing a single pair of headphones.

## 2. Architecture
The project follows a **Modular SPM + XcodeGen** approach to ensure high testability, clean boundaries, and CLI-friendliness.

### 2.1 Project Structure
```
/
├── App/                # Main iOS Application source
├── Modules/            # Standalone Swift Packages
│   ├── SCTCore/        # Core models, EventBus, Orchestrator
│   ├── SCTAudio/       # AVAudioSession, Capture, Playback
│   ├── SCTPipeline/    # ASR, Translation, TTS Abstractions
│   ├── SCTRouting/     # Channel routing logic
│   └── SCTUI/          # Shared SwiftUI components
├── Scripts/            # CLI Build/Test/Deploy scripts
├── project.yml         # XcodeGen project definition
└── Package.swift       # (Optional) Root package for combined testing
```

### 2.2 Core Components
- **EventBus**: A lightweight pub-sub system for component communication.
- **SessionOrchestrator**: An Actor that manages the state machine and coordinates the pipeline.
- **RoutingEngine**: Decides which audio stream goes to which channel (A -> Right, B -> Left).
- **Processors**: Independent units for ASR, Translation, and TTS (following the `Processor` protocol).

## 3. Data Flow
1. **Input**: `AudioCaptureProcessor` (SCTAudio) captures raw audio.
2. **Event**: Publishes `AudioCapturedEvent`.
3. **Processing**: `ASRProcessor` (SCTPipeline) consumes audio -> `TranscriptProducedEvent`.
4. **Translation**: `TranslationProcessor` (SCTPipeline) consumes transcript -> `TranslationProducedEvent`.
5. **Synthesis**: `TTSProcessor` (SCTPipeline) consumes translation -> `TTSProducedEvent`.
6. **Routing**: `RoutingProcessor` (SCTRouting) decides channel (Left/Right) based on speaker.
7. **Output**: `StereoOutputSink` (SCTAudio) plays audio to the designated channel.

## 4. Testing & Quality
- **Unit Tests**: Every module must have a dedicated test target.
- **Mocks**: `SCTPipeline` will use mock providers for ASR/Translation/TTS during development and testing.
- **CLI**: All tests must be runnable via `swift test`.

## 5. Build & Deployment
- **XcodeGen**: Generates `.xcodeproj` from `project.yml`.
- **Signing**: Configured via Team ID in `project.yml` for real device deployment.
- **CLI Workflow**: Scripts for `generate-project`, `build`, `test`, and `deploy-to-iphone`.
