# splitspeak

Stereo Conversational Translator (SCT) - An iOS app enabling real-time, two-way translation using stereo audio separation (Left/Right channels) for two users sharing a single pair of headphones.

## Architecture

```
splitspeak/
├── App/                    # Main iOS Application
├── Modules/
│   ├── SCTCore/            # Core models, EventBus, Orchestrator
│   ├── SCTAudio/           # AVAudioSession, Capture, Playback
│   ├── SCTPipeline/        # ASR, Translation, TTS Abstractions
│   ├── SCTRouting/         # Channel routing logic
│   └── SCTUI/              # Shared SwiftUI components
├── Scripts/                # CLI Build/Test/Deploy scripts
├── project.yml             # XcodeGen project definition
└── Package.swift           # Swift Package manifest
```

## Prerequisites

- **macOS** with Xcode
- **XcodeGen** (`brew install xcodegen`)
- **Swift 5.9+**
- iOS 17.0+ device or simulator (for device testing)

## Setup

```bash
# Install xcodegen if not already installed
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Run tests
swift test
```

## Build & Run

### iOS Simulator

```bash
# Generate project (if not already)
xcodegen generate

# Build for simulator
just build-sim

# Or manually:
xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Physical iPhone

1. **Connect your iPhone via USB**
2. **Add Apple ID in Xcode**: Xcode → Settings → Accounts → + (personal team works for free)
3. **Build and run**:

```bash
# With just
just run-iphone

# Or manually:
xcodebuild -project splitspeak.xcodeproj -scheme splitspeak -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build
```

4. **Open Xcode**, select your iPhone as the destination, and press **Cmd+R** to run

## Testing

```bash
# Run unit tests (macOS)
swift test

# Or with just
just test

# Run on iOS Simulator
just test-ios
```

## Project Structure

- **SCTCore**: Core data models (`Participant`, `Session`), `EventBus` actor, and `SCTEvent` enum
- **SCTAudio**: Audio capture and playback, including `StereoOutputSink` for left/right channel control
- **SCTPipeline**: Abstractions for ASR, Translation, and TTS processors
- **SCTRouting**: Channel routing logic (which speaker goes to which ear)
- **SCTUI**: Shared SwiftUI components

## Available Just Recipes

```bash
just                    # Show this help
just generate           # Generate Xcode project
just build-sim          # Build for iOS Simulator
just build-ios          # Build for generic iOS
just test               # Run unit tests (swift test)
just test-ios           # Run tests on iOS Simulator
just run-iphone         # Build for connected iPhone
just clean              # Remove build artifacts
just setup              # Generate + test (full setup)
```
