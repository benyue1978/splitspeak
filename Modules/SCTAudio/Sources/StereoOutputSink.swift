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
/// This sink supports:
/// - Left channel only: plays audio only in the left ear
/// - Right channel only: plays audio only in the right ear
/// - Stereo: plays audio in both ears (same content)
/// - Full-duplex capture + playback when eventBus is provided
public final class StereoOutputSink: @unchecked Sendable {
    private let engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode?
    private var isConfigured = false
    private var scheduledBuffer: AVAudioPCMBuffer?
    private let audioQueue = DispatchQueue(label: "com.splitspeak.stereooutput", qos: .userInteractive)

    /// Default sample rate for audio playback
    public static let defaultSampleRate: Double = 44100

    private var eventBus: EventBus?
    private var isCapturing = false

    public init() {
        self.engine = AVAudioEngine()
    }

    /// Starts the audio engine in playback-only mode (stereo).
    public func start() throws {
        try start(category: .playback)
    }

    /// Starts the audio engine with a specific category.
    /// - Parameter category: The audio session category to use.
    private func start(category: AVAudioSession.Category) throws {
        // Clean up any existing player node
        if let existingNode = playerNode {
            existingNode.stop()
            engine.detach(existingNode)
            playerNode = nil
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)

        // Explicitly specify stereo format
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        engine.connect(node, to: engine.mainMixerNode, format: stereoFormat)

        engine.prepare()
        try engine.start()
        playerNode = node
        isConfigured = true
    }

    /// Switches the audio session to .playAndRecord mode and starts capture.
    /// Full teardown and rebuild to ensure clean state.
    public func switchToPlayAndRecordMode() throws {
        let session = AVAudioSession.sharedInstance()

        // Full engine teardown
        audioQueue.sync {
            playerNode?.stop()
            engine.stop()
            if let node = playerNode {
                engine.detach(node)
            }
            playerNode = nil
            scheduledBuffer = nil
            isConfigured = false
        }
        isCapturing = false

        Thread.sleep(forTimeInterval: 0.1)

        // Deactivate session completely
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            Thread.sleep(forTimeInterval: 0.05)
        } catch {
            // Ignore - session might already be inactive
        }

        // Set new category and activate
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        // Give hardware a moment to settle with new session
        Thread.sleep(forTimeInterval: 0.1)

        // Rebuild engine from scratch
        try rebuildEngine(category: .playAndRecord)

        // Start capture
        do {
            try startCaptureChecked()
        } catch {
            print("StereoOutputSink: capture setup failed: \(error)")
        }
    }

    /// Switches the audio session back to .playback mode for stereo output.
    /// Full teardown and rebuild to ensure clean state.
    public func switchToPlaybackMode() throws {
        let session = AVAudioSession.sharedInstance()

        // Full engine teardown
        audioQueue.sync {
            playerNode?.stop()
            engine.stop()
            if let node = playerNode {
                engine.detach(node)
            }
            playerNode = nil
            scheduledBuffer = nil
            isConfigured = false
        }
        isCapturing = false

        Thread.sleep(forTimeInterval: 0.1)

        // Deactivate session completely
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            Thread.sleep(forTimeInterval: 0.05)
        } catch {
            // Ignore - session might already be inactive
        }

        // Set new category and activate
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        // Give hardware a moment to settle
        Thread.sleep(forTimeInterval: 0.1)

        // Rebuild engine from scratch
        try rebuildEngine(category: .playback)
    }

    /// Rebuilds the audio engine with a fresh player node.
    private func rebuildEngine(category: AVAudioSession.Category) throws {
        let node = AVAudioPlayerNode()
        engine.attach(node)

        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        engine.connect(node, to: engine.mainMixerNode, format: stereoFormat)

        engine.prepare()
        try engine.start()
        playerNode = node
        isConfigured = true
    }

    /// Starts capturing audio from the mic. Throws on format invalid.
    private func startCaptureChecked() throws {
        guard let eventBus = eventBus, !isCapturing else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.channelCount > 0 && format.sampleRate > 0 else {
            throw StereoOutputError.invalidSampleRate
        }

        isCapturing = true

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            let frameCount = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData?[0] else { return }

            let data = Data(bytes: channelData, count: frameCount * MemoryLayout<Float>.size)

            Task { @MainActor in
                await eventBus.publish(.audioCaptured(data))
            }
        }
    }

    /// Starts capturing audio from the mic (no-throw version for internal use).
    private func startCapture() {
        try? startCaptureChecked()
    }

    /// Stops capturing audio.
    public func stopCapture() {
        guard isCapturing else { return }
        isCapturing = false

        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
        }
    }

    /// Stops the audio engine and releases resources.
    public func stop() {
        stopCapture()
        audioQueue.sync {
            playerNode?.stop()
            engine.stop()
            if let node = playerNode {
                engine.detach(node)
            }
            playerNode = nil
            scheduledBuffer = nil
            isConfigured = false
        }
    }

    // MARK: - EventBus Integration

    private var listenerTask: Task<Void, Never>?

    /// Creates a StereoOutputSink that subscribes to ttsProduced events from EventBus.
    public convenience init(eventBus: EventBus) {
        self.init()
        self.eventBus = eventBus
        let sampleRate = StereoOutputSink.defaultSampleRate
        listenerTask = Task { [weak self, eventBus, sampleRate] in
            guard let sink = self else { return }
            let stream = await eventBus.subscribe()
            for await event in stream {
                if case .ttsProduced(let audioData, let targetChannel) = event {
                    let leftData = targetChannel == .left ? audioData : Data()
                    let rightData = targetChannel == .right ? audioData : Data()
                    await sink.playStereoOnQueue(leftData: leftData, rightData: rightData, sampleRate: sampleRate)
                }
            }
        }
    }

    /// Plays stereo audio on the serial audio queue.
    private func playStereoOnQueue(leftData: Data, rightData: Data, sampleRate: Double) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            audioQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                Task {
                    do {
                        try await self.playStereoSync(leftData: leftData, rightData: rightData, sampleRate: sampleRate)
                    } catch {
                        print("StereoOutputSink play error: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// Synchronous playStereo that must be called on audioQueue.
    private func playStereoSync(leftData: Data, rightData: Data, sampleRate: Double) async throws {
        guard isConfigured, let playerNode else {
            throw StereoOutputError.engineNotRunning
        }

        let leftFrameCount = leftData.count / MemoryLayout<Float>.size
        let rightFrameCount = rightData.count / MemoryLayout<Float>.size
        let frameCount: Int
        if leftFrameCount == 0 {
            frameCount = rightFrameCount
        } else if rightFrameCount == 0 {
            frameCount = leftFrameCount
        } else {
            frameCount = min(leftFrameCount, rightFrameCount)
        }

        guard frameCount > 0 else {
            throw StereoOutputError.bufferCreationFailed
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            throw StereoOutputError.bufferCreationFailed
        }

        leftData.withUnsafeBytes { leftPtr in
            rightData.withUnsafeBytes { rightPtr in
                let leftFloats = leftPtr.bindMemory(to: Float.self)
                let rightFloats = rightPtr.bindMemory(to: Float.self)

                for frame in 0..<Int(frameCount) {
                    if leftFrameCount > 0 {
                        leftChannel[frame] = leftFloats[frame]
                    }
                    if rightFrameCount > 0 {
                        rightChannel[frame] = rightFloats[frame]
                    }
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

    /// Plays a tone burst on the specified channel.
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
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

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

        scheduledBuffer = buffer

        _ = await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }
            playerNode.play()
        }
    }

    /// Plays stereo audio.
    public func playStereo(
        leftData: Data,
        rightData: Data,
        sampleRate: Double
    ) async throws {
        guard isConfigured, let playerNode else {
            throw StereoOutputError.engineNotRunning
        }

        let leftFrameCount = leftData.count / MemoryLayout<Float>.size
        let rightFrameCount = rightData.count / MemoryLayout<Float>.size
        let frameCount: Int
        if leftFrameCount == 0 {
            frameCount = rightFrameCount
        } else if rightFrameCount == 0 {
            frameCount = leftFrameCount
        } else {
            frameCount = min(leftFrameCount, rightFrameCount)
        }

        guard frameCount > 0 else {
            throw StereoOutputError.bufferCreationFailed
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw StereoOutputError.bufferCreationFailed
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            throw StereoOutputError.bufferCreationFailed
        }

        leftData.withUnsafeBytes { leftPtr in
            rightData.withUnsafeBytes { rightPtr in
                let leftFloats = leftPtr.bindMemory(to: Float.self)
                let rightFloats = rightPtr.bindMemory(to: Float.self)

                for frame in 0..<Int(frameCount) {
                    if leftFrameCount > 0 {
                        leftChannel[frame] = leftFloats[frame]
                    }
                    if rightFrameCount > 0 {
                        rightChannel[frame] = rightFloats[frame]
                    }
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
        audioQueue.sync {
            playerNode?.stop()
            scheduledBuffer = nil
        }
    }

    /// Returns whether the audio engine is currently running.
    public var isRunning: Bool {
        engine.isRunning
    }
}
