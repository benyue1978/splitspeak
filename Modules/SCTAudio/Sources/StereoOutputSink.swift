import AVFoundation
import Foundation
import SCTCore

/// Errors that can occur during stereo output operations
public enum StereoOutputError: Error, Sendable {
    case engineNotRunning
    case playerNodeNotAdded
    case bufferCreationFailed
    case engineStartFailed(String)
    case invalidSampleRate
}

/// Manages stereo audio output to left and right channels using AVAudioEngine.
///
/// This sink verifies the ability to independently route audio to each ear on a real iOS device.
/// Use cases:
/// - Left channel only: plays audio only in the left ear
/// - Right channel only: plays audio only in the right ear
/// - Stereo: plays audio in both ears (same content)
public actor StereoOutputSink {
    // Note: AVAudioEngine and AVAudioPlayerNode are Sendable on Apple platforms
    private let engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode?
    private var isConfigured = false
    // Keep buffer alive during playback - only one buffer at a time supported
    private var scheduledBuffer: AVAudioPCMBuffer?

    /// Default sample rate for audio playback
    public static let defaultSampleRate: Double = 44100

    public init() {
        self.engine = AVAudioEngine()
    }

    /// Starts the audio engine. Must be called before playing audio.
    /// Safe to call multiple times - will no-op if already running.
    public func start() throws {
        guard !engine.isRunning else { return }

        // Clean up any existing player node
        if let existingNode = playerNode {
            existingNode.stop()
            engine.detach(existingNode)
            playerNode = nil
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)

        // Connect to main mixer with default format
        engine.connect(node, to: engine.mainMixerNode, format: nil)

        engine.prepare()
        try engine.start()
        playerNode = node
        isConfigured = true
    }

    /// Stops the audio engine and releases resources.
    public func stop() {
        playerNode?.stop()
        engine.stop()
        if let node = playerNode {
            engine.detach(node)
        }
        playerNode = nil
        scheduledBuffer = nil
        isConfigured = false
    }

    /// Plays a tone burst on the specified channel.
    ///
    /// - Parameters:
    ///   - channel: The target channel for audio output (.left or .right)
    ///   - frequencyHz: Frequency of the tone in Hz (default 440 = A4)
    ///   - durationSeconds: Duration of the tone (default 0.5s)
    ///   - sampleRate: Sample rate for tone generation (default 44100)
    public func playTone(
        on channel: AudioChannel,
        frequencyHz: Double = 440,
        durationSeconds: Double = 0.5,
        sampleRate: Double = StereoOutputSink.defaultSampleRate
    ) async throws {
        guard isConfigured, let playerNode else {
            throw StereoOutputError.engineNotRunning
        }

        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            throw StereoOutputError.bufferCreationFailed
        }

        for frame in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * .pi * frequencyHz * Double(frame) / sampleRate))

            switch channel {
            case .left:
                leftChannel[frame] = sample
                rightChannel[frame] = 0
            case .right:
                leftChannel[frame] = 0
                rightChannel[frame] = sample
            }
        }

        // Keep buffer alive during playback
        scheduledBuffer = buffer

        // Use completion handler for reliable playback
        _ = await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }
            playerNode.play()
        }
    }

    /// Plays stereo audio where left and right channels contain independent audio data.
    ///
    /// - Parameters:
    ///   - leftData: Audio data (linear PCM Float32) for the left channel
    ///   - rightData: Audio data (linear PCM Float32) for the right channel
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

        guard frameCount > 0 else {
            throw StereoOutputError.bufferCreationFailed
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
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

        scheduledBuffer = buffer
        _ = await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }
            playerNode.play()
        }
    }

    /// Stops current playback without stopping the engine.
    public func stopPlayback() {
        playerNode?.stop()
        scheduledBuffer = nil
    }

    /// Returns whether the audio engine is currently running.
    public var isRunning: Bool {
        engine.isRunning
    }
}
