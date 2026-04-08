import SwiftUI
import AVFoundation
import SCTCore
import SCTAudio
import SCTPipeline

enum SpeakerMode: String {
    case none
    case me
    case foreigner
}

struct ContentView: View {
    @State private var stereoSink: StereoOutputSink?
    @State private var eventBus: EventBus?
    @State private var isEngineRunning = false
    @State private var speakerMode: SpeakerMode = .none
    @State private var statusMessage = "Tap a button to test audio"

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "ear")
                    .imageScale(.large)
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text("Audio Test")
                    .font(.title)

                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                // Ear test buttons
                VStack(spacing: 16) {
                    Button(action: playLeftChannel) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                            Text("Play Left Ear")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isEngineRunning)

                    Button(action: playRightChannel) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                            Text("Play Right Ear")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isEngineRunning)

                    Button(action: playBothChannels) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                            Image(systemName: "speaker.wave.3.fill")
                            Text("Play Both (Different)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isEngineRunning)
                }
                .padding(.horizontal)

                Divider()

                // Speaker routing section
                VStack(spacing: 12) {
                    Text("Speaker Routing")
                        .font(.headline)

                    Text("Left (Me) → Right ear | Right (Foreigner) → Left ear")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if speakerMode != .none {
                        HStack {
                            Image(systemName: speakerMode == .me ? "person.fill" : "person.2.fill")
                            Text(speakerMode == .me ? "Me Speaking → Right" : "Foreigner Speaking → Left")
                        }
                        .padding()
                        .background(speakerMode == .me ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                        .cornerRadius(10)
                    }

                    HStack(spacing: 16) {
                        Button(action: selectMe) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Me")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(speakerMode == .me ? Color.blue : Color.blue.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: selectForeigner) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Foreigner")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(speakerMode == .foreigner ? Color.green : Color.green.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    if speakerMode != .none {
                        Button(action: stopSpeaking) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop & Playback")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            initializeEngines()
        }
        .onDisappear {
            stereoSink?.stop()
        }
    }

    private func initializeEngines() {
        Task {
            // Create EventBus first
            let bus = EventBus()

            // Create PassthroughProcessor and start listening
            let passthrough = PassthroughProcessor(eventBus: bus)
            Task {
                await passthrough.start()
            }

            // Create StereoOutputSink
            let sink = StereoOutputSink(eventBus: bus)
            print("Starting audio engine...")

            let session = AVAudioSession.sharedInstance()
            do {
                // Use playback mode for stereo output
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)

                // Log route
                let route = session.currentRoute
                print("Audio route: \(route.outputs.first?.portName ?? "none") - \(route.outputs.first?.portType.rawValue ?? "unknown")")

                try sink.start()
                print("Audio engine started successfully")

                self.stereoSink = sink
                self.eventBus = bus
                self.isEngineRunning = true
                statusMessage = "Ready!"
            } catch {
                print("ERROR: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func selectMe() {
        speakerMode = .me
        if let bus = eventBus {
            print("Publishing speakerSelected(A)")
            Task {
                await bus.publish(.speakerSelected(participantId: "A"))
            }
        }
        // Switch to .playAndRecord mode for capture (mono on Bluetooth is ok)
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Recording from Me..."
            do {
                try sink.switchToPlayAndRecordMode()
            } catch {
                print("ERROR switching mode: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func selectForeigner() {
        speakerMode = .foreigner
        if let bus = eventBus {
            print("Publishing speakerSelected(B)")
            Task {
                await bus.publish(.speakerSelected(participantId: "B"))
            }
        }
        // Switch to .playAndRecord mode for capture (mono on Bluetooth is ok)
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Recording from Foreigner..."
            do {
                try sink.switchToPlayAndRecordMode()
            } catch {
                print("ERROR switching mode: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func stopSpeaking() {
        let wasMode = speakerMode
        speakerMode = .none

        // Switch back to .playback mode first, then play to correct ear
        Task {
            guard let sink = stereoSink else { return }

            // A (me) → right ear, B (foreigner) → left ear
            let channel: AudioChannel = (wasMode == .me) ? .right : .left
            let freq: Double = (wasMode == .me) ? 440 : 660

            statusMessage = "Switching to playback mode..."
            do {
                try sink.switchToPlaybackMode()
                // Give session a moment to stabilize
                try await Task.sleep(nanoseconds: 100_000_000)

                statusMessage = "Playing to \(channel == .left ? "left" : "right") ear..."
                try await sink.playTone(on: channel, frequencyHz: freq, durationSeconds: 0.5)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Playback complete!"
            } catch {
                print("ERROR: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playLeftChannel() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing left ear (440Hz)..."
            do {
                try await sink.playTone(on: .left, frequencyHz: 440, durationSeconds: 0.5)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Left ear played!"
            } catch {
                print("ERROR: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playRightChannel() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing right ear (880Hz)..."
            do {
                try await sink.playTone(on: .right, frequencyHz: 880, durationSeconds: 0.5)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Right ear played!"
            } catch {
                print("ERROR: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playBothChannels() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing both ears..."
            do {
                let sampleRate: Double = 44100
                let duration: Double = 0.5
                let frameCount = Int(sampleRate * duration)

                var leftData = Data()
                var rightData = Data()

                for frame in 0..<frameCount {
                    let leftSample = Float(sin(2.0 * .pi * 440 * Double(frame) / sampleRate))
                    let rightSample = Float(sin(2.0 * .pi * 880 * Double(frame) / sampleRate))
                    leftData.append(contentsOf: withUnsafeBytes(of: leftSample) { Array($0) })
                    rightData.append(contentsOf: withUnsafeBytes(of: rightSample) { Array($0) })
                }

                try await sink.playStereo(leftData: leftData, rightData: rightData, sampleRate: sampleRate)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Stereo test complete!"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
