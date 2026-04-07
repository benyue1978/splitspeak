import AVFoundation
import XCTest
@testable import SCTAudio
import SCTCore

final class StereoOutputSinkTests: XCTestCase {
    func testStereoOutputSinkCreation() async {
        // Just verify we can create the sink - actual audio playback requires device
        let sink = StereoOutputSink()
        await sink.stop() // Should be a no-op since not started
    }

    func testChannelRoutingLogic() async throws {
        // Verify channel enum values exist and are correct
        XCTAssertEqual(AudioChannel.left.rawValue, "left")
        XCTAssertEqual(AudioChannel.right.rawValue, "right")
    }

    func testToneGenerationParameters() async throws {
        // Verify tone parameters are valid for left channel
        let sink = StereoOutputSink()
        try await sink.start()
        try await sink.playTone(on: .left, frequencyHz: 440, durationSeconds: 0.1)
        try await Task.sleep(nanoseconds: 200_000_000) // Wait for playback
        await sink.stop()
    }

    func testRightChannelTone() async throws {
        let sink = StereoOutputSink()
        try await sink.start()
        try await sink.playTone(on: .right, frequencyHz: 880, durationSeconds: 0.1) // Higher pitch for right
        try await Task.sleep(nanoseconds: 200_000_000)
        await sink.stop()
    }

    func testPlayStereoWithData() async throws {
        let sampleRate: Double = 44100
        let duration: Double = 0.1
        let frameCount = Int(sampleRate * duration)

        // Generate left and right channel data (different frequencies for distinction)
        var leftData = Data()
        var rightData = Data()

        for frame in 0..<frameCount {
            let leftSample = Float(sin(2.0 * .pi * 440 * Double(frame) / sampleRate))
            let rightSample = Float(sin(2.0 * .pi * 880 * Double(frame) / sampleRate))

            leftData.append(contentsOf: withUnsafeBytes(of: leftSample) { Array($0) })
            rightData.append(contentsOf: withUnsafeBytes(of: rightSample) { Array($0) })
        }

        let sink = StereoOutputSink()
        try await sink.start()
        try await sink.playStereo(leftData: leftData, rightData: rightData, sampleRate: sampleRate)
        try await Task.sleep(nanoseconds: 200_000_000)
        await sink.stop()
    }
}
