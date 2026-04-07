import SwiftUI
import AVFoundation
import SCTCore
import SCTAudio

struct ContentView: View {
    @State private var leftSink: StereoOutputSink?
    @State private var rightSink: StereoOutputSink?
    @State private var stereoSink: StereoOutputSink?
    @State private var isEngineRunning = false
    @State private var statusMessage = "Tap a button to test audio"

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "ear")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Stereo Output Test")
                .font(.title)

            Text(statusMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 20) {
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
                        Text("Play Both Ears (Different)")
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

            Spacer()
        }
        .padding()
        .onAppear {
            initializeEngines()
        }
    }

    private func initializeEngines() {
        Task {
            do {
                // Configure audio session for playback
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)

                // Initialize stereo sink and start engine
                let sink = StereoOutputSink()
                try await sink.start()
                stereoSink = sink
                isEngineRunning = true
                statusMessage = "Ready! Tap a button to test."
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playLeftChannel() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing left ear (440Hz)..."
            do {
                try await sink.playTone(on: .left, frequencyHz: 440, durationSeconds: 1.0)
                statusMessage = "Left ear played!"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playRightChannel() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing right ear (880Hz)..."
            do {
                try await sink.playTone(on: .right, frequencyHz: 880, durationSeconds: 1.0)
                statusMessage = "Right ear played!"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playBothChannels() {
        Task {
            guard let sink = stereoSink else { return }
            statusMessage = "Playing both ears (different pitches)..."
            do {
                // Generate left channel: 440Hz tone
                let sampleRate: Double = 44100
                let duration: Double = 1.0
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
                statusMessage = "Stereo test complete!"
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}
