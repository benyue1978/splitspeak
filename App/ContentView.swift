import SwiftUI
import AVFoundation
import SCTCore
import SCTAudio

struct ContentView: View {
    @State private var stereoSink: StereoOutputSink?
    @State private var isEngineRunning = false
    @State private var statusMessage = "Tap a button to test audio"
    @State private var interruptionObserver: NSObjectProtocol?
    @State private var routeChangeObserver: NSObjectProtocol?

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
        .onDisappear {
            if let obs = interruptionObserver {
                NotificationCenter.default.removeObserver(obs)
            }
            if let obs = routeChangeObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }
    }

    private func initializeEngines() {
        Task {
            let sink = StereoOutputSink()
            print("Starting audio engine...")

            // Set up audio session with notification for route changes
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)

                // Register for interruption and route change notifications
                interruptionObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.interruptionNotification,
                    object: session,
                    queue: .main
                ) { [self] notification in
                    Task {
                        await handleInterruption(notification, sink: sink)
                    }
                }

                routeChangeObserver = NotificationCenter.default.addObserver(
                    forName: AVAudioSession.routeChangeNotification,
                    object: session,
                    queue: .main
                ) { [self] notification in
                    Task {
                        await handleRouteChange(notification, sink: sink)
                    }
                }

                try await sink.start()
                print("Audio engine started successfully")
                stereoSink = sink
                isEngineRunning = true
                statusMessage = "Ready! Tap a button to test."
            } catch {
                print("ERROR in initializeEngines: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func handleInterruption(_ notification: Notification, sink: StereoOutputSink) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("Audio interruption began")
            isEngineRunning = false
            statusMessage = "Audio interrupted..."
        case .ended:
            print("Audio interruption ended, restarting engine...")
            do {
                try await sink.start()
                isEngineRunning = true
                statusMessage = "Ready! Tap a button to test."
            } catch {
                print("ERROR restarting engine: \(error)")
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification, sink: StereoOutputSink) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            print("Audio route changed: \(reason), restarting engine...")
            do {
                try await sink.start()
                isEngineRunning = true
                statusMessage = "Ready! Tap a button to test."
            } catch {
                print("ERROR restarting engine after route change: \(error)")
            }
        default:
            break
        }
    }

    private func playLeftChannel() {
        Task {
            guard let sink = stereoSink else { return }

            // Try to restart engine if needed
            do {
                try await sink.start()
            } catch {}

            statusMessage = "Playing left ear (440Hz)..."
            do {
                try await sink.playTone(on: .left, frequencyHz: 440, durationSeconds: 0.5)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Left ear played!"
            } catch {
                print("ERROR playing left: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playRightChannel() {
        Task {
            guard let sink = stereoSink else { return }

            // Try to restart engine if needed
            do {
                try await sink.start()
            } catch {}

            statusMessage = "Playing right ear (880Hz)..."
            do {
                try await sink.playTone(on: .right, frequencyHz: 880, durationSeconds: 0.5)
                try await Task.sleep(nanoseconds: 600_000_000)
                statusMessage = "Right ear played!"
            } catch {
                print("ERROR playing right: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func playBothChannels() {
        Task {
            guard let sink = stereoSink else { return }

            // Try to restart engine if needed
            do {
                try await sink.start()
            } catch {}

            statusMessage = "Playing both ears (different pitches)..."
            do {
                // Generate left channel: 440Hz tone
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
