# Audio Capture & Manual Speaker Toggle UI

## Goal

Implement audio capture from the microphone and a manual speaker toggle UI for the dual-person translation app.

## Context

MVP: Single device + split-wire earbuds + two people speaking different languages (Chinese/English).

**Physical setup:**
- Left earbud → Person A (Chinese speaker, "Me")
- Right earbud → Person B (English speaker, "Foreigner")

**Routing rule:** Whoever is speaking, their *translated* audio plays to the *other* person's ear. Currently verification is playback-only (no TTS yet).

- Person A ("Me") speaks → audio plays to **right** earbud (Person B hears)
- Person B ("Foreigner") speaks → audio plays to **left** earbud (Person A hears)

## Scope

- **Audio capture**: AVAudioEngine captures mono audio from available input device
- **Speaker toggle UI**: Two mutually-exclusive buttons — "Me (Chinese)" and "Foreigner (English)"
- **Language config**: Left language (Chinese) / Right language (English) shown on main UI (language pair binding)
- **Channel routing**:
  - "Me" active → capture plays to **right channel only**
  - "Foreigner" active → capture plays to **left channel only**
- **Visual state**: UI clearly shows which speaker is currently active
- **Minimal pipeline**: Capture → Buffer → Opposite channel playback (no ASR/Translation/TTS yet)

## Definition of Done
- [ ] Audio captures from available input device and plays to correct channel
- [ ] "Me" button routes audio to right channel
- [ ] "Foreigner" button routes audio to left channel
- [ ] Only one speaker active at a time (mutually exclusive)
- [ ] UI displays active speaker state clearly
- [ ] Build succeeds

## Constraints

- No device selection — use default available input device
- No ASR/Translation/TTS — verification is raw audio playback only
- Use existing `StereoOutputSink` for playback
- Do NOT modify `StereoOutputSink` API

## Plan

1. Create `SCTAudio/Sources/AudioCaptureProcessor.swift` — AVAudioEngine mono capture
2. Update `ContentView.swift` with:
   - Language labels (left = Chinese, right = English)
   - "Me Speaking" / "Foreigner Speaking" toggle buttons
3. Integrate: Capture → buffer → StereoOutputSink on opposite channel
4. Build and verify with earbuds connected
