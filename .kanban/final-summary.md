### What was done
- Created `Spike/AudioDeviceEnumeration.swift` — macOS SwiftUI app using CoreAudio APIs to enumerate all audio input devices
- Added `Spike` target to `project.yml`, regenerated Xcode project
- Build: **SUCCEEDED**
- User ran the spike on hardware with Baseus Bowie M2s Pro earbuds connected
- Review found channel-counting bug (mNumberBuffers vs mNumberChannels), fixed, re-ran spike

### Key Decisions
- Used CoreAudio `kAudioHardwarePropertyDevices` enumeration (most reliable for macOS)
- Used `kAudioDevicePropertyStreamConfiguration` with per-buffer `mNumberChannels` summation
- Spike output goes to both UI and Xcode console for analysis

### Result / Links
- **CONCLUSION: Option B — split-wire earbuds present as single mono device**
- Baseus Bowie M2s Pro: 1 channel @ 16000 Hz (mono, pre-mixed)
- Cross-correlation channel detection approach: **INVALID**
- Findings documented in `Spike/README.md`
- Commit: 3cf966c

### DoD Check
- [x] Spike code runs without errors on macOS
- [x] Device enumeration output captured
- [x] Conclusion stated: **Option B** (mono pre-mixed)
- [x] Channel-detection approach invalidated — documented alternative strategies
