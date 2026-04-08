# Spike: Audio Input Device Enumeration

## Goal

Determine whether split-wire earbuds (two mics, left/right physically separated) present to macOS as:
- **Option A**: One stereo input device (2 channels in one stream) — channels can be distinguished
- **Option B**: One mono input device (pre-mixed signal) — channels are lost, cross-correlation won't work
- **Option C**: Two separate mono input devices — easy separation

This is a **validation spike** — if Option B, the whole left/right channel detection approach is invalid and we need a different strategy.

## Context

MVP goal: single device + split-wire earbuds + dual-person conversation translation routed to left/right channel.

Design hypothesis: Use cross-correlation between left and right mic signals to detect if same person (high correlation = same speaker) or different people (low correlation = different speakers).

**Critical assumption**: The two mics are captured as distinguishable channels. If macOS pre-mixes them to mono, the hypothesis fails.

## Scope

- Write minimal Swift spike using AVAudioEngine
- Enumerate all audio input devices
- For each device: name, UID, channel count, sample rate
- Report whether devices are mono or multi-channel
- Run on hardware and capture actual device enumeration output
- Build a minimal macOS UI for the user to run the spike and see results
- Log output to Xcode console for agent analysis

## Definition of Done
- [ ] Spike code runs without errors on macOS
- [ ] Device enumeration output captured
- [ ] Conclusion stated: Option A, B, or C above
- [ ] If Option B: flag that channel-detection approach is invalid, document need for alternative strategy

## Constraints

- Must run on actual hardware (can't determine from docs alone)
- Minimal code — spike quality, not production quality
- Do NOT modify existing app code

## Plan

1. Create `Spike/AudioDeviceEnumeration.swift` in repo
2. Use AVAudioEngine + CoreAudio to enumerate input devices
3. Print device details to console
4. Run and capture output
5. Document findings in `Spike/README.md`

---

## Final Summary
### What was done

### Key Decisions

### Result / Links

### DoD Check
- [ ] Spike code runs without errors on macOS
- [ ] Device enumeration output captured
- [ ] Conclusion (A/B/C) stated
- [ ] If Option B: approach invalidated
