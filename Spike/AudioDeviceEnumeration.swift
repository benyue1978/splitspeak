import AVFoundation
import CoreAudio
import SwiftUI

// MARK: - Audio Device Info

struct AudioDeviceInfo: Identifiable {
    let id: String
    let name: String
    let uid: String
    let channelCount: Int
    let sampleRate: Double
    let isInput: Bool
}

// MARK: - Audio Device Enumerator

enum AudioDeviceEnumerator {

    /// Enumerate all audio input devices using CoreAudio
    static func enumerateInputDevices() -> [AudioDeviceInfo] {
        var devices: [AudioDeviceInfo] = []

        // Get all audio device IDs
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            print("[ERROR] Failed to get devices data size: \(status)")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            print("[ERROR] Failed to get device IDs: \(status)")
            return devices
        }

        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID), device.isInput {
                devices.append(device)
            }
        }

        return devices
    }

    private static func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDeviceInfo? {
        // Check if device has input streams
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else {
            // Not an input device
            return nil
        }

        // Get device name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)
        status = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0,
            nil,
            &dataSize,
            &name
        )

        let deviceName = status == noErr ? (name as String) : "Unknown"

        // Get device UID
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)
        status = AudioObjectGetPropertyData(
            deviceID,
            &uidAddress,
            0,
            nil,
            &dataSize,
            &uid
        )

        let deviceUID = status == noErr ? (uid as String) : "Unknown"

        // Get channel count
        var channelCount: UInt32 = 0
        var channelAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        dataSize = 0
        status = AudioObjectGetPropertyDataSize(
            deviceID,
            &channelAddress,
            0,
            nil,
            &dataSize
        )

        if status == noErr, dataSize > 0 {
            let byteSize = Int(dataSize)
            let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { bufferListPointer.deallocate() }

            status = AudioObjectGetPropertyData(
                deviceID,
                &channelAddress,
                0,
                nil,
                &dataSize,
                bufferListPointer
            )

            if status == noErr {
                let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self).pointee
                // Sum channels across all buffers (each buffer may have different channel count)
                var totalChannels: UInt32 = 0
                let bufferCount = Int(bufferList.mNumberBuffers)
                withUnsafePointer(to: bufferList.mBuffers) { ptr in
                    for i in 0..<bufferCount {
                        let bufferPtr = UnsafeRawPointer(ptr).advanced(by: i * MemoryLayout<AudioBuffer>.stride).assumingMemoryBound(to: AudioBuffer.self)
                        totalChannels += bufferPtr.pointee.mNumberChannels
                    }
                }
                channelCount = totalChannels
            }
        }

        // Get sample rate
        var sampleRate: Double = 0
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        dataSize = UInt32(MemoryLayout<Float64>.size)
        status = AudioObjectGetPropertyData(
            deviceID,
            &sampleRateAddress,
            0,
            nil,
            &dataSize,
            &sampleRate
        )

        if status != noErr {
            sampleRate = 0
        }

        return AudioDeviceInfo(
            id: String(deviceID),
            name: deviceName,
            uid: deviceUID,
            channelCount: Int(channelCount),
            sampleRate: sampleRate,
            isInput: true
        )
    }
}

// MARK: - SwiftUI App

@main
struct AudioDeviceEnumerationApp: App {
    @State private var devices: [AudioDeviceInfo] = []
    @State private var isLoading = false

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("Audio Input Device Enumeration")
                    .font(.title)
                    .padding(.top, 20)

                Button(action: refreshDevices) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Refresh Devices")
                    }
                }
                .disabled(isLoading)
                .padding(.bottom, 10)

                if devices.isEmpty && !isLoading {
                    Text("No input devices found.\nConnect split-wire earbuds and refresh.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(devices) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.headline)
                            Text("UID: \(device.uid)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Channels: \(device.channelCount) | Sample Rate: \(Int(device.sampleRate)) Hz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.inset)
                }

                Spacer()

                // Summary
                if !devices.isEmpty {
                    let hasStereo = devices.contains { $0.channelCount >= 2 }
                    let hasMultipleMono = devices.filter { $0.channelCount == 1 }.count >= 2

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary:")
                            .font(.headline)
                        if hasStereo {
                            Text("✓ Option A: Found stereo input device(s) — channels can be distinguished")
                                .foregroundColor(.green)
                        }
                        if hasMultipleMono {
                            Text("✓ Option C: Found multiple mono devices — can select separate devices")
                                .foregroundColor(.green)
                        }
                        if !hasStereo && !hasMultipleMono {
                            Text("? Only mono devices found — may be Option B (pre-mixed)")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
            .onAppear {
                refreshDevices()
            }
        }
    }

    private func refreshDevices() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let enumerated = AudioDeviceEnumerator.enumerateInputDevices()

            // Print to console for agent analysis
            print("=== Audio Input Device Enumeration ===")
            print("Total input devices found: \(enumerated.count)")
            for (index, device) in enumerated.enumerated() {
                print("--- Device \(index + 1) ---")
                print("  Name: \(device.name)")
                print("  UID: \(device.uid)")
                print("  Channels: \(device.channelCount)")
                print("  Sample Rate: \(Int(device.sampleRate)) Hz")
                print("  Option: \(device.channelCount >= 2 ? "A (stereo)" : "C (mono)")")
            }

            if enumerated.isEmpty {
                print("No input devices found.")
            }

            DispatchQueue.main.async {
                self.devices = enumerated
                self.isLoading = false
            }
        }
    }
}
