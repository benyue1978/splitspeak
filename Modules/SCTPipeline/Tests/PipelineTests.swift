import XCTest
@testable import SCTCore
@testable import SCTPipeline

final class PipelineTests: XCTestCase {

    // MARK: - Mock Providers Tests

    func testMockTranslationProvider() async throws {
        let provider = MockTranslationProvider()

        let result = try await provider.translate(text: "Hello", from: "en", to: "zh")

        XCTAssertEqual(result, "[zh] Hello")
    }

    func testMockTranslationProviderChineseToEnglish() async throws {
        let provider = MockTranslationProvider()

        let result = try await provider.translate(text: "你好", from: "zh", to: "en")

        XCTAssertEqual(result, "[en] 你好")
    }

    func testMockTTSProvider() async throws {
        let provider = MockTTSProvider()

        let audioData = try await provider.synthesize(text: "测试", language: "zh")

        // Should return some audio data
        XCTAssertFalse(audioData.isEmpty)
    }

    func testMockTTSProviderAudioFormat() async throws {
        let provider = MockTTSProvider()

        let audioData = try await provider.synthesize(text: "Hello", language: "en")

        // 300ms at 44100Hz = 13230 bytes (300 * 44100 * 4 bytes per float)
        // Allow some tolerance
        XCTAssertGreaterThan(audioData.count, 1000)
    }

    // MARK: - TranslationProcessor Tests

    func testTranslationProcessorPublishesOnManualTextInjected() async throws {
        let eventBus = EventBus()
        let provider = MockTranslationProvider()
        let processor = TranslationProcessor(eventBus: eventBus, translationProvider: provider)

        // Start listening for translationProduced
        var receivedTranslation: SCTEvent?
        let listenerTask = Task {
            for await event in await eventBus.subscribe() {
                if case .translationProduced = event {
                    receivedTranslation = event
                    return
                }
            }
        }

        // Start processor
        await processor.start()

        // Give time for processor to start listening
        try await Task.sleep(nanoseconds: 50_000_000)

        // Inject text
        await eventBus.publish(.manualTextInjected("Hello", participantId: "A"))

        // Wait for result
        try await Task.sleep(nanoseconds: 100_000_000)

        await processor.stop()
        listenerTask.cancel()

        XCTAssertNotNil(receivedTranslation)
        if case .translationProduced(let text, let targetLanguage, let participantId) = receivedTranslation {
            XCTAssertEqual(text, "[zh] Hello")
            XCTAssertEqual(targetLanguage, "zh")
            XCTAssertEqual(participantId, "A")
        }
    }

    func testTranslationProcessorHandlesParticipantB() async throws {
        let eventBus = EventBus()
        let provider = MockTranslationProvider()
        let processor = TranslationProcessor(eventBus: eventBus, translationProvider: provider)

        var receivedTranslation: SCTEvent?
        let listenerTask = Task {
            for await event in await eventBus.subscribe() {
                if case .translationProduced = event {
                    receivedTranslation = event
                    return
                }
            }
        }

        await processor.start()
        try await Task.sleep(nanoseconds: 50_000_000)

        // B speaks Chinese → translate to English
        await eventBus.publish(.manualTextInjected("你好", participantId: "B"))

        try await Task.sleep(nanoseconds: 100_000_000)

        await processor.stop()
        listenerTask.cancel()

        XCTAssertNotNil(receivedTranslation)
        if case .translationProduced(let text, let targetLanguage, _) = receivedTranslation {
            XCTAssertEqual(text, "[en] 你好")
            XCTAssertEqual(targetLanguage, "en")
        }
    }

    // MARK: - TTSProcessor Tests

    func testTTSProcessorPublishesOnTranslationProduced() async throws {
        let eventBus = EventBus()
        let provider = MockTTSProvider()
        let processor = TTSProcessor(eventBus: eventBus, ttsProvider: provider)

        var receivedTTS: SCTEvent?
        let listenerTask = Task {
            for await event in await eventBus.subscribe() {
                if case .ttsProduced = event {
                    receivedTTS = event
                    return
                }
            }
        }

        await processor.start()
        try await Task.sleep(nanoseconds: 50_000_000)

        // A speaks → output to right channel
        await eventBus.publish(.translationProduced(text: "你好", targetLanguage: "zh", participantId: "A"))

        try await Task.sleep(nanoseconds: 100_000_000)

        await processor.stop()
        listenerTask.cancel()

        XCTAssertNotNil(receivedTTS)
        if case .ttsProduced(let audioData, let channel) = receivedTTS {
            XCTAssertFalse(audioData.isEmpty)
            XCTAssertEqual(channel, .right) // A → right
        }
    }

    func testTTSProcessorRoutesToCorrectChannel() async throws {
        let eventBus = EventBus()
        let provider = MockTTSProvider()
        let processor = TTSProcessor(eventBus: eventBus, ttsProvider: provider)

        var receivedChannels: [AudioChannel] = []
        let listenerTask = Task {
            for await event in await eventBus.subscribe() {
                if case .ttsProduced(_, let channel) = event {
                    receivedChannels.append(channel)
                }
            }
        }

        await processor.start()
        try await Task.sleep(nanoseconds: 50_000_000)

        // A → right channel
        await eventBus.publish(.translationProduced(text: "Hello", targetLanguage: "en", participantId: "A"))

        // Give time for first event to be processed
        try await Task.sleep(nanoseconds: 50_000_000)

        // B → left channel
        await eventBus.publish(.translationProduced(text: "你好", targetLanguage: "zh", participantId: "B"))

        try await Task.sleep(nanoseconds: 100_000_000)

        await processor.stop()
        listenerTask.cancel()

        XCTAssertEqual(receivedChannels.count, 2)
        XCTAssertEqual(receivedChannels[0], .right)  // A → right
        XCTAssertEqual(receivedChannels[1], .left)   // B → left
    }

    // MARK: - TextTransform Tests

    func testTextTransformTextPassThrough() async throws {
        let asrProvider = MockASRProvider()
        let processor = TextTransformProcessor(asrProvider: asrProvider)

        let result = try await processor.transform(.text("Hello"))

        XCTAssertEqual(result, "Hello")
    }

    func testTextTransformAudioRequiresASR() async throws {
        let asrProvider = MockASRProvider()
        let processor = TextTransformProcessor(asrProvider: asrProvider)

        let audioData = Data([0x00, 0x01, 0x02])
        let result = try await processor.transform(.audio(audioData, language: "en"))

        XCTAssertTrue(result.contains("Mock transcript"))
        XCTAssertTrue(result.contains("en"))
    }
}
