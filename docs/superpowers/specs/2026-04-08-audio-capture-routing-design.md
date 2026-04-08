# Audio Capture & Routing — Design

## Context

MVP goal: Single device + split-wire earbuds + two people speaking different languages.

**Key constraint from spike**: Baseus Bowie M2s Pro earbuds present as single mono input (Option B). Manual speaker selection is required.

**Routing rule**: Whoever is speaking, their audio plays to the *other* person's ear.
- Me (left/Chinese) speaking → audio routes to **right** channel (foreigner hears)
- Foreigner (right/English) speaking → audio routes to **left** channel (me hears)

## Architecture

```
AVAudioEngine (inputNode tap)
    ↓ (raw PCM Float32 mono Data)
AudioPassthroughProcessor.audioStream()
    ↓ (AsyncStream<Data>)
Pipeline.input
    ↓
PassthroughProcessor (no-op transform)
    ↓
TurnManager.output
    ↓
StereoOutputSink.playStereo(leftData, rightData, sampleRate)
```

The pipeline and TurnManager are reused from existing infrastructure. Only AudioPassthroughProcessor and PassthroughProcessor are new.

## Components

### AudioPassthroughProcessor (SCTAudio)
- Uses single AVAudioEngine in full-duplex mode
- Installs tap on inputNode → publishes captured PCM Float32 mono samples via `AsyncStream<Data>`
- InputNode connected to MixerNode → MainMixerNode → OutputNode (graph handles routing)
- No threading complexity — AVAudioEngine manages audio threads internally
- Exposes: `start()`, `stop()`, `audioStream() -> AsyncStream<Data>`, `sampleRate: Double`, `running: Bool`

### PassthroughProcessor (SCTPipeline)
- Pipeline processor (conforms to Processor protocol)
- Reads from upstream stream, writes identical data downstream
- No-op transformation — simply passes audio through
- Used to exercise the existing pipeline infrastructure

### Pipeline (existing SCTPipeline)
- Already has Processor protocol and routing infrastructure
- AudioPassthroughProcessor feeds into Pipeline
- PassthroughProcessor is the first processor in the chain

### TurnManager (existing SCTConversation)
- Receives `SpeakerSelected` events from UI
- Routes to correct channel: .left or .right
- Provides output stream that StereoOutputSink consumes

### StereoOutputSink (existing SCTAudio)
- Already implemented and tested
- playStereo(leftData: Data, rightData: Data, sampleRate: Double)

## Speaker Toggle Flow

1. User taps "Me Speaking" button in UI
2. UI publishes `SpeakerSelected(participant: .me)` event
3. TurnManager receives event, sets routing → audio plays to **right** channel
4. User taps "Foreigner Speaking" → routing → **left** channel
5. User taps "Stop" → routing → neither (audio muted)

## Key Constraints

- AudioPassthroughProcessor uses AVAudioEngine in full-duplex: inputNode → mixer → outputNode
- Mono capture (1 channel) — confirmed from spike
- PCM Float32 format throughout
- No ASR/Translation/TTS in this card — verification is raw audio passthrough
- Existing StereoOutputSink API unchanged

## Verification

1. Connect earbuds to iPhone
2. Open app → select "Me Speaking"
3. Speak into mic (left earbud side) → hear voice in **right** ear
4. Select "Foreigner Speaking"
5. Speak into mic (right earbud side) → hear voice in **left** ear
6. "Stop" → no audio plays

## What Changed vs. Previous Architecture

The spike revealed that automatic speaker detection via channel correlation is impossible (mono pre-mixed earbuds). Manual toggle replaces the audio capture + VAD step. The processor pipeline remains the same — just with a pass-through processor instead of ASR/Translation.
