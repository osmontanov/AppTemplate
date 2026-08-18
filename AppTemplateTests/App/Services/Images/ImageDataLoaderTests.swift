import Foundation
import Nuke
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct ImageDataLoaderTests {
    private func url(_ name: String) -> URL {
        URL(string: "https://cdn.dummyjson.com/\(name).png")!
    }

    private func loader(
        policy: ImagePolicy = .product,
        clock: AppClock = .live
    ) -> ImageDataLoader {
        ImageDataLoader(
            policy: policy,
            clock: clock,
            protocolClasses: [ImageURLProtocolStub.self]
        )
    }

    private func load(
        _ url: URL,
        loader: ImageDataLoader
    ) async -> (received: [Data], error: (any Error)?, completions: Int, mimeType: String?) {
        let box = Box()
        await withCheckedContinuation { continuation in
            _ = loader.loadData(
                with: URLRequest(url: url),
                didReceiveData: { data, response in box.append(data, response) },
                completion: { error in
                    if box.finish(error) { continuation.resume() }
                }
            )
        }
        return (box.received, box.error, box.completions, box.mimeType)
    }

    @Test
    func deliversAValidatedBodyInOnePieceAfterTheWholeResponseIsProven() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(chunks: [ImageFixtures.png.prefix(20), ImageFixtures.png.dropFirst(20)]),
            for: url("delivers")
        )

        let result = await load(url("delivers"), loader: loader())

        #expect(result.error == nil)
        #expect(result.received == [ImageFixtures.png])
        #expect(result.completions == 1)
    }

    @Test
    func refusesAForeignHostWithoutOpeningAConnection() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(.init(chunks: [ImageFixtures.png]), for: ImageFixtures.foreignURL)

        let result = await load(ImageFixtures.foreignURL, loader: loader())

        #expect(result.error as? ImageServiceError == .disallowedOrigin)
        #expect(result.received.isEmpty)
        #expect(ImageURLProtocolStub.chunksDelivered(for: ImageFixtures.foreignURL) == 0)
    }

    @Test
    func abortsMidBodyWhenTheEncodedCapIsExceededWithoutForwardingBytes() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        let chunk = Data(repeating: 0x41, count: 64)
        ImageURLProtocolStub.set(
            .init(
                headers: ["Content-Type": "image/png", "Content-Length": "16"],
                chunks: Array(repeating: chunk, count: 40)
            ),
            for: url("midbody")
        )
        let tiny = ImagePolicy(
            allowedHosts: ImagePolicy.product.allowedHosts,
            timeout: .seconds(5),
            maximumEncodedBytes: 100,
            maximumPixelSide: 4_096
        )

        let result = await load(url("midbody"), loader: loader(policy: tiny))

        #expect(result.error as? ImageServiceError == .responseTooLarge)
        #expect(result.received.isEmpty)
        #expect(result.completions == 1)
        // The abort happened while the body was still arriving, not after it.
        #expect(ImageURLProtocolStub.chunksDelivered(for: url("midbody")) < 40)
    }

    @Test
    func rejectsADeclaredContentLengthOverTheCapBeforeAcceptingABody() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(
                headers: ["Content-Type": "image/png", "Content-Length": "999999"],
                chunks: [ImageFixtures.png]
            ),
            for: url("declaredlength")
        )
        let tiny = ImagePolicy(
            allowedHosts: ImagePolicy.product.allowedHosts,
            timeout: .seconds(5),
            maximumEncodedBytes: 100,
            maximumPixelSide: 4_096
        )

        let result = await load(url("declaredlength"), loader: loader(policy: tiny))

        #expect(result.error as? ImageServiceError == .responseTooLarge)
        #expect(result.received.isEmpty)
    }

    @Test
    func refusesARedirectThatLeavesTheAllowlist() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(.init(redirectTo: ImageFixtures.foreignURL), for: url("redirectout"))
        ImageURLProtocolStub.set(.init(chunks: [ImageFixtures.png]), for: ImageFixtures.foreignURL)

        let result = await load(url("redirectout"), loader: loader())

        #expect(result.error as? ImageServiceError == .disallowedOrigin)
        #expect(ImageURLProtocolStub.chunksDelivered(for: ImageFixtures.foreignURL) == 0)
    }

    @Test
    func followsARedirectThatStaysInsideTheAllowlist() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(.init(redirectTo: ImageFixtures.otherAllowedURL), for: url("redirectin"))
        ImageURLProtocolStub.set(.init(chunks: [ImageFixtures.png]), for: ImageFixtures.otherAllowedURL)

        let result = await load(url("redirectin"), loader: loader())

        #expect(result.error == nil)
        #expect(result.received == [ImageFixtures.png])
    }

    @Test(arguments: [301, 400, 404, 500])
    func rejectsANonSuccessStatus(_ status: Int) async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(statusCode: status, chunks: [ImageFixtures.png]),
            for: url("status")
        )

        let result = await load(url("status"), loader: loader())

        #expect(result.error as? ImageServiceError == .invalidStatus)
    }

    @Test
    func rejectsADisallowedContentTypeAtTheResponseHead() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(headers: ["Content-Type": "image/svg+xml"], chunks: [ImageFixtures.png]),
            for: url("badtype")
        )

        let result = await load(url("badtype"), loader: loader())

        #expect(result.error as? ImageServiceError == .invalidMIMEType)
        #expect(result.received.isEmpty)
    }

    @Test
    func rejectsBytesThatContradictAnAllowedContentType() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(headers: ["Content-Type": "image/jpeg"], chunks: [ImageFixtures.png]),
            for: url("mismatch")
        )

        let result = await load(url("mismatch"), loader: loader())

        #expect(result.error as? ImageServiceError == .invalidSignature)
        #expect(result.received.isEmpty)
    }

    @Test
    func theInjectedClockDeadlineFiresAndCompletesExactlyOnce() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(.init(stallsForever: true), for: url("deadline"))
        let immediate = AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { _ in }
        )

        let result = await load(
            url("deadline"),
            loader: loader(clock: immediate)
        )

        #expect(result.error as? ImageServiceError == .timedOut)
        #expect(result.completions == 1)
    }

    @Test
    func cancellationCompletesExactlyOnceWithTheCancelledError() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(.init(stallsForever: true), for: url("cancel"))

        let box = Box()
        let cancellable = loader().loadData(
            with: URLRequest(url: url("cancel")),
            didReceiveData: { data, response in box.append(data, response) },
            completion: { _ = box.finish($0) }
        )
        cancellable.cancel()
        cancellable.cancel()
        try? await Task.sleep(for: .milliseconds(120))

        #expect(box.error as? ImageServiceError == .cancelled)
        #expect(box.completions == 1)
    }

    @Test
    func aTransportFailureIsReportedAsTransport() async {
        ImageURLProtocolStub.reset()
        defer { ImageURLProtocolStub.reset() }
        ImageURLProtocolStub.set(
            .init(failure: URLError(.networkConnectionLost)),
            for: url("transport")
        )

        let result = await load(url("transport"), loader: loader())

        #expect(result.error as? ImageServiceError == .transport)
    }
}

// Counting completions is the point: the DataLoading contract says the closure
// runs exactly once, and the redirect, head, chunk, deadline and cancel paths
// can all reach it.
nonisolated
private final class Box: @unchecked Sendable {
    private let lock = NSLock()
    private var storedReceived: [Data] = []
    private var storedError: (any Error)?
    private var storedCompletions = 0
    private var storedMIMEType: String?

    var received: [Data] { lock.withLock { storedReceived } }
    var error: (any Error)? { lock.withLock { storedError } }
    var completions: Int { lock.withLock { storedCompletions } }
    var mimeType: String? { lock.withLock { storedMIMEType } }

    func append(_ data: Data, _ response: URLResponse) {
        lock.withLock {
            storedReceived.append(data)
            storedMIMEType = response.mimeType
        }
    }

    func finish(_ error: (any Error)?) -> Bool {
        lock.withLock {
            storedCompletions += 1
            if storedCompletions == 1 { storedError = error }
            return storedCompletions == 1
        }
    }
}
