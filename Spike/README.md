# Audio Device Enumeration Spike — Findings

## Results

| Device | Channels | Sample Rate | Option |
|--------|----------|-------------|--------|
| Ben's iPhone Microphone | 1 (mono) | 48000 Hz | C |
| **Baseus Bowie M2s Pro** (earbuds) | **1 (mono)** | **16000 Hz** | **B** |
| MacBook Pro Microphone | 1 (mono) | 48000 Hz | C |
| Microsoft Teams Audio | 1 (mono) | 48000 Hz | C |
| WeMeet Audio Device | 1 (mono) | 48000 Hz | C |

## Conclusion: **Option B** — Single Mono Input Device

The Baseus Bowie M2s Pro split-wire earbuds present to macOS as a **single mono input device** at 16000 Hz.

- Left mic and right mic signals are **pre-mixed** into one mono stream before reaching macOS
- There is no way to distinguish left vs right channel at the software layer
- **Channel-correlation approach is INVALID** with this hardware

## Why This Matters

For the MVP's who-is-speaking detection to work via cross-correlation, we need at minimum:
- Option A: A stereo input device with 2+ channels (left mic = channel 0, right mic = channel 1)
- Option C: Two separate mono devices (one per earbud/mic)

We have neither.

## Alternative Strategies to Explore

1. **Two separate physical audio interfaces** — Use two USB-C to 3.5mm adapters, each as a separate mono input device
2. **Software-based diarization** — Use ML speaker diarization on the mixed mono signal (heavier, needs more compute)
3. **Bluetooth HFP profile investigation** — The earbuds might present differently under certain Bluetooth profiles; investigate if macOS exposes separate channels via a different API
4. **Hardware change** — Use earbuds that present as a stereo (2-channel) input device to macOS

## Hardware Used

- MacBook Pro (Apple Silicon)
- Baseus Bowie M2s Pro earbuds (connected via Bluetooth)
- Baseus Bowie M2s Pro was enumerated as: `41-AA-01-51-05-2A:input` at 16000 Hz mono

## Next Steps

1. Discuss alternative approaches with user
2. Either change hardware strategy or pivot to ML-based speaker diarization
