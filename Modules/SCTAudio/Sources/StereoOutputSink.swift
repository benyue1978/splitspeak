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
    private var scheduledBuffer: AVAudioPCMBuffer?  // Keep buffer alive during playback

    public init() {
        self.engine = AVAudioEngine()
    }

    /// Starts the audio engine. Must be called before playing audio.
    public func start() throws {
        // Check if engine is actually running - if so, nothing to do
        if engine.isRunning {
            print("[StereoOutputSink] engine already running, skipping start")
            return
        }

        print("[StereoOutputSink] start() called, engine is not running, need to start it")
        isConfigured = false

        // Stop any existing player node first
        if let existingNode = playerNode {
            existingNode.stop()
            engine.detach(existingNode)
            playerNode = nil
        }

        playerNode = AVAudioPlayerNode()
        guard let playerNode else {
            print("[StereoOutputSink] ERROR: playerNode is nil")
            throw StereoOutputError.playerNodeNotAdded
        }
        print("[StereoOutputSink] playerNode created")

        engine.attach(playerNode)
        print("[StereoOutputSink] playerNode attached to engine")

        // Connect player to main mixer using default format (nil = engine picks best format)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        print("[StereoOutputSink] playerNode connected to mainMixerNode")

        // Attach and start the engine
        engine.prepare()
        do {
            try engine.start()
            isConfigured = true
            print("[StereoOutputSink] engine started successfully")
        } catch {
            print("[StereoOutputSink] ERROR starting engine: \(error)")
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
        scheduledBuffer = nil
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
        print("[StereoOutputSink] playTone called, isConfigured: \(isConfigured), playerNode: \(playerNode != nil)")

        guard isConfigured, let playerNode else {
            print("[StereoOutputSink] ERROR: engine not running")
            throw StereoOutputError.engineNotRunning
        }

        // Create a stereo buffer with the tone
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        print("[StereoOutputSink] Creating buffer: sampleRate=\(sampleRate), frameCount=\(frameCount)")

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            print("[StereoOutputSink] ERROR: could not create format")
            throw StereoOutputError.bufferCreationFailed
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("[StereoOutputSink] ERROR: could not create buffer")
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        // Fill the buffer with a sine wave
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            print("[StereoOutputSink] ERROR: could not get channel data")
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

        print("[StereoOutputSink] Buffer filled, scheduling and playing on channel: \(channel)")
        // Keep buffer alive during playback - store in instance variable
        scheduledBuffer = buffer

        // Use completion handler version - more reliable in test contexts
        let didSchedule = await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }
            playerNode.play()
        }
        print("[StereoOutputSink] playback started, scheduled: \(didSchedule)")
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

        scheduledBuffer = buffer
        let _ = await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }
            playerNode.play()
        }
    }
}
