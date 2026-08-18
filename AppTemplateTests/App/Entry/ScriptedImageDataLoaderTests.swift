import Foundation
import Nuke
import Testing
@testable import AppTemplate

struct ScriptedImageDataLoaderTests {
    private func load(
        _ url: URL,
        loader: ScriptedImageDataLoader
    ) async -> (received: [Data], error: (any Error)?) {
        let received = ReceivedData()
        return await withCheckedContinuation { continuation in
            _ = loader.loadData(
                with: URLRequest(url: url),
                didReceiveData: { data, _ in received.append(data) },
                completion: { continuation.resume(returning: (received.values, $0)) }
            )
        }
    }

    @Test
    func servesEachURLOnceAndReplaysItWithoutConsumingASecondStep() async throws {
        // Two steps, not one: the tracker clamps at zero, so a single-step budget
        // cannot tell one consume from two and the replay would go unnoticed.
        let tracker = UITestScriptConsumptionTracker(networkSteps: 0, imageSteps: 2)
        let loader = ScriptedImageDataLoader(
            steps: [
                .png(ImageFixtures.allowedURL, body: ImageFixtures.png),
                .png(ImageFixtures.otherAllowedURL, body: ImageFixtures.png)
            ],
            tracker: tracker
        )

        let first = await load(ImageFixtures.allowedURL, loader: loader)
        #expect(first.error == nil)
        #expect(first.received == [ImageFixtures.png])

        // The reminder path re-requests a URL the detail view already showed;
        // a replay must not spend the step the other URL still needs.
        let second = await load(ImageFixtures.allowedURL, loader: loader)
        #expect(second.error == nil)
        #expect(second.received == [ImageFixtures.png])

        await loader.drainNotifications()
        var afterReplay = await tracker.updates().makeAsyncIterator()
        #expect(await afterReplay.next() == .pending)

        #expect(await load(ImageFixtures.otherAllowedURL, loader: loader).error == nil)

        try loader.assertExhausted()
        #expect(loader.requestedURLs.count == 3)
        await loader.drainNotifications()
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .exhausted)
    }

    @Test
    func servesStepsInAnyOrder() async throws {
        let loader = ScriptedImageDataLoader(steps: [
            .png(ImageFixtures.allowedURL, body: ImageFixtures.png),
            .png(ImageFixtures.otherAllowedURL, body: ImageFixtures.png)
        ])

        #expect(await load(ImageFixtures.otherAllowedURL, loader: loader).error == nil)
        #expect(await load(ImageFixtures.allowedURL, loader: loader).error == nil)

        try loader.assertExhausted()
    }

    @Test
    func anUnplannedURLFailsTheScriptRatherThanReachingTheNetwork() async {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 0, imageSteps: 1)
        let loader = ScriptedImageDataLoader(
            steps: [.png(ImageFixtures.allowedURL, body: ImageFixtures.png)],
            tracker: tracker
        )

        let result = await load(ImageFixtures.otherAllowedURL, loader: loader)

        #expect(result.error as? ScriptedImageDataLoaderError == .unexpectedURL)
        #expect(result.received.isEmpty)
        await loader.drainNotifications()
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .failed)
    }

    @Test
    func aDisallowedOriginFailsTheScript() async {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 0, imageSteps: 0)
        let loader = ScriptedImageDataLoader(steps: [], tracker: tracker)

        let result = await load(ImageFixtures.foreignURL, loader: loader)

        #expect(result.error as? ImageServiceError == .disallowedOrigin)
        await loader.drainNotifications()
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .failed)
    }

    @Test
    func unservedStepsAreReportedByExhaustion() {
        let loader = ScriptedImageDataLoader(steps: [
            .png(ImageFixtures.allowedURL, body: ImageFixtures.png),
            .png(ImageFixtures.otherAllowedURL, body: ImageFixtures.png)
        ])

        #expect(throws: ScriptedImageDataLoaderError.unconsumedSteps(2)) {
            try loader.assertExhausted()
        }
    }

    @Test
    func seededBytesStillGoThroughTheRealValidator() async {
        let loader = ScriptedImageDataLoader(steps: [ScriptedImageStep(
            url: ImageFixtures.allowedURL,
            outcome: .response(
                statusCode: 200,
                contentType: "image/png",
                body: Data("not a png".utf8)
            )
        )])

        let result = await load(ImageFixtures.allowedURL, loader: loader)

        #expect(result.error as? ImageServiceError == .invalidSignature)
        #expect(result.received.isEmpty)
    }

    @Test
    func aScriptedFailureIsDeliveredVerbatim() async {
        let loader = ScriptedImageDataLoader(steps: [ScriptedImageStep(
            url: ImageFixtures.allowedURL,
            outcome: .failure(.timedOut)
        )])

        let result = await load(ImageFixtures.allowedURL, loader: loader)

        #expect(result.error as? ImageServiceError == .timedOut)
    }
}

nonisolated
private final class ReceivedData: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Data] = []

    var values: [Data] { lock.withLock { stored } }

    func append(_ data: Data) {
        lock.withLock { stored.append(data) }
    }
}
