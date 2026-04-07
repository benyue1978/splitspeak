import AVFoundation
import Foundation
import SCTCore

/// Errors that can occur during stereo output operations
public enum StereoOutputError: Error, Sendable {
    case engineNotRunning
    case playerNodeNotAdded
    case bufferCreationFailed
    case engineStartFailed(String)
}

/// Manages stereo audio output to left and right channels using AVAudioEngine.
///
/// This sink verifies the ability to independently route audio to each ear on a real iOS device.
/// Use cases:
/// - Left channel only: plays audio only in the left ear
/// - Right channel only: plays audio only in the right ear
/// - Stereo: plays audio in both ears (same content)
public actor StereoOutputSink {
    private let engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode?
    private var isConfigured = false

    public init() {
        self.engine = AVAudioEngine()
    }

    /// Starts the audio engine. Must be called before playing audio.
    public func start() throws {
        guard !isConfigured else { return }

        playerNode = AVAudioPlayerNode()
        guard let playerNode else {
            throw StereoOutputError.playerNodeNotAdded
        }

        engine.attach(playerNode)

        // Get the main mixer output format (stereo on iOS)
        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        // Connect player to main mixer
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        // Attach and start the engine
        engine.prepare()
        do {
            try engine.start()
            isConfigured = true
        } catch {
            throw StereoOutputError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Stops the audio engine and releases resources.
    public func stop() {
        playerNode?.stop()
        engine.stop()
        if let playerNode {
            engine.detach(playerNode)
        }
        isConfigured = false
    }

    /// Plays a tone burst on the specified channel(s).
    ///
    /// - Parameters:
    ///   - channel: The target channel(s) for audio output
    ///   - frequencyHz: Frequency of the tone in Hz (default 440 = A4)
    ///   - durationSeconds: Duration of the tone (default 0.5s)
    public func playTone(
        on channel: AudioChannel,
        frequencyHz: Double = 440,
        durationSeconds: Double = 0.5
    ) async throws {
        guard isConfigured, let playerNode else {
            throw StereoOutputError.engineNotRunning
        }

        // Create a stereo buffer with the tone
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw StereoOutputError.bufferCreationFailed
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        // Fill the buffer with a sine wave
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            throw StereoOutputError.bufferCreationFailed
        }

        for frame in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * .pi * frequencyHz * Double(frame) / sampleRate))

            switch channel {
            case .left:
                // Audio only on left channel
                leftChannel[frame] = sample
                rightChannel[frame] = 0
            case .right:
                // Audio only on right channel
                leftChannel[frame] = 0
                rightChannel[frame] = sample
            }
        }

        // Schedule and play
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()
    }

    /// Plays a stereo audio buffer where left and right channels contain independent audio data.
    ///
    /// - Parameters:
    ///   - leftData: Audio data (linear PCM) for the left channel
    ///   - rightData: Audio data (linear PCM) for the right channel
    ///   - sampleRate: Sample rate of the audio data
    public func playStereo(
        leftData: Data,
        rightData: Data,
        sampleRate: Double
    ) async throws {
        guard isConfigured, let playerNode else {
            throw StereoOutputError.engineNotRunning
        }

        let frameCount = AVAudioFrameCount(min(leftData.count, rightData.count) / MemoryLayout<Float>.size)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw StereoOutputError.bufferCreationFailed
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            throw StereoOutputError.bufferCreationFailed
        }

        leftData.withUnsafeBytes { leftPtr in
            rightData.withUnsafeBytes { rightPtr in
                let leftFloats = leftPtr.bindMemory(to: Float.self)
                let rightFloats = rightPtr.bindMemory(to: Float.self)

                for frame in 0..<Int(frameCount) {
                    leftChannel[frame] = leftFloats[frame]
                    rightChannel[frame] = rightFloats[frame]
                }
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()
    }
}
