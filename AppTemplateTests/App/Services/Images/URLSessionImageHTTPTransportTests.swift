import Foundation
import Synchronization
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct URLSessionImageHTTPTransportTests {
    private let policy = ImageLoadPolicy(
        allowedHosts: ["images.example.test"],
        timeout: .seconds(2),
        maximumEncodedBytes: 5 * 1_024 * 1_024,
        maximumPixelWidth: 10,
        maximumPixelHeight: 10
    )

    @Test(
        arguments: [
            "http://images.example.test/image",
            "https://user@images.example.test/image",
            "https://images.example.test:444/image",
            "https://images.example.test/image#fragment",
            "https://images.example.test.evil.test/image"
        ]
    )
    func rejectsUnsafeOriginBeforeFirstRequest(_ value: String) async {
        ImageURLProtocolFixture.reset(.success(data: Data()))
        let transport = makeTransport()

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            try await transport.fetch(URL(string: value)!, policy: policy)
        }
        #expect(ImageURLProtocolFixture.requestedURLs.isEmpty)
    }

    @Test
    func allowsExactHostWithExplicitDefaultHTTPSPort() async throws {
        ImageURLProtocolFixture.reset(.success(data: Data([1, 2, 3])))

        let response = try await makeTransport().fetch(
            URL(string: "https://images.example.test:443/image")!,
            policy: policy
        )

        #expect(response.statusCode == 200)
        #expect(response.data == Data([1, 2, 3]))
        #expect(ImageURLProtocolFixture.requestedURLs.count == 1)
    }

    @Test(
        arguments: [
            "http://images.example.test/collect",
            "https://user@images.example.test/collect",
            "https://images.example.test:444/collect",
            "https://images.example.test/collect#fragment",
            "https://images.example.test.evil.test/collect",
            "https://evil.example.test/collect"
        ]
    )
    func rejectsUnsafeRedirectBeforeFollowingIt(_ destinationValue: String) async {
        ImageURLProtocolFixture.reset(.redirect(URL(string: destinationValue)!))

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/start")!,
                policy: policy
            )
        }
        #expect(ImageURLProtocolFixture.requestedURLs == [
            URL(string: "https://images.example.test/start")!
        ])
    }

    @Test
    func rejectsCrossOriginFinalResponse() async {
        ImageURLProtocolFixture.reset(
            .responseURL(URL(string: "https://evil.example.test/image")!)
        )

        await #expect(throws: ImageLoaderError.disallowedOrigin) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
    }

    @Test
    func rejectsDeclaredLengthBeforeAcceptingBody() async {
        ImageURLProtocolFixture.reset(
            .declaredLength(5 * 1_024 * 1_024 + 1, data: Data([1]))
        )

        await #expect(throws: ImageLoaderError.responseTooLarge) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
        await ImageURLProtocolFixture.waitUntilStopped()
        #expect(ImageURLProtocolFixture.stopCount == 1)
    }

    @Test
    func cancelsAsSoonAsChunkedResponseWouldCrossLimit() async {
        ImageURLProtocolFixture.reset(
            .chunks([
                Data(repeating: 1, count: 5 * 1_024 * 1_024),
                Data([2])
            ])
        )

        await #expect(throws: ImageLoaderError.responseTooLarge) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
        await ImageURLProtocolFixture.waitUntilStopped()
        #expect(ImageURLProtocolFixture.stopCount == 1)
    }

    @Test
    func cancelsLyingContentLengthAsSoonAsBodyCrossesLimit() async {
        ImageURLProtocolFixture.reset(
            .declaredLength(
                1,
                data: Data(repeating: 1, count: 5 * 1_024 * 1_024 + 1)
            )
        )

        await #expect(throws: ImageLoaderError.responseTooLarge) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
        await ImageURLProtocolFixture.waitUntilStopped()
        #expect(ImageURLProtocolFixture.stopCount == 1)
    }

    @Test
    func rejectsNonSuccessfulStatusWithoutReturningBody() async {
        ImageURLProtocolFixture.reset(.status(404, data: Data([1])))

        await #expect(throws: ImageLoaderError.invalidStatus) {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/missing")!,
                policy: policy
            )
        }
    }

    @Test
    func callerCancellationStopsTheUnderlyingTask() async {
        ImageURLProtocolFixture.reset(.hold)
        let task = Task {
            try await makeTransport().fetch(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
        await ImageURLProtocolFixture.waitUntilStarted()

        task.cancel()

        await #expect(throws: ImageLoaderError.cancelled) {
            try await task.value
        }
        await ImageURLProtocolFixture.waitUntilStopped()
        #expect(ImageURLProtocolFixture.stopCount == 1)
    }

    @Test
    func loaderTimeoutCancelsUnderlyingURLSessionTask() async {
        ImageURLProtocolFixture.reset(.hold)
        let clock = AppClock(
            now: Date.init,
            monotonicNow: { ContinuousClock().now },
            sleep: { _ in await ImageURLProtocolFixture.waitUntilStarted() }
        )

        await #expect(throws: ImageLoaderError.timedOut) {
            try await ProductImageLoader(
                transport: makeTransport(),
                clock: clock
            ).load(
                URL(string: "https://images.example.test/image")!,
                policy: policy
            )
        }
        await ImageURLProtocolFixture.waitUntilStopped()
        #expect(ImageURLProtocolFixture.stopCount == 1)
    }

    @Test
    func delayedStopFromPriorGenerationCannotPolluteCurrentScenario() {
        let state = ImageURLProtocolFixtureState()
        let url = URL(string: "https://images.example.test/image")!
        state.reset(.hold)
        let priorGeneration = state.recordStart(url).generation

        state.reset(.hold)
        let currentGeneration = state.recordStart(url).generation
        state.recordStop(generation: priorGeneration)

        #expect(state.stopCount == 0)
        state.recordStop(generation: currentGeneration)
        #expect(state.stopCount == 1)
    }

    private func makeTransport() -> URLSessionImageHTTPTransport {
        URLSessionImageHTTPTransport(
            protocolClasses: [ImageURLProtocolFixture.self]
        )
    }
}

nonisolated
private final class ImageURLProtocolFixture: URLProtocol, @unchecked Sendable {
    enum Scenario: Sendable {
        case success(data: Data)
        case status(Int, data: Data)
        case declaredLength(Int, data: Data)
        case chunks([Data])
        case redirect(URL)
        case responseURL(URL)
        case hold
    }

    private static let state = ImageURLProtocolFixtureState()
    private let loadGeneration = Mutex<UInt64?>(nil)

    static var requestedURLs: [URL] { state.requestedURLs }
    static var stopCount: Int { state.stopCount }

    static func reset(_ scenario: Scenario) {
        state.reset(scenario)
    }

    static func waitUntilStarted() async {
        await state.waitUntilStarted()
    }

    static func waitUntilStopped() async {
        await state.waitUntilStopped()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let load = Self.state.recordStart(url)
        loadGeneration.withLock { $0 = load.generation }
        switch load.scenario {
        case let .success(data):
            respond(status: 200, headers: ["Content-Type": "image/png"], chunks: [data])
        case let .status(status, data):
            respond(status: status, headers: ["Content-Type": "image/png"], chunks: [data])
        case let .declaredLength(length, data):
            respond(
                status: 200,
                headers: [
                    "Content-Type": "image/png",
                    "Content-Length": String(length)
                ],
                chunks: [data]
            )
        case let .chunks(chunks):
            respond(status: 200, headers: ["Content-Type": "image/png"], chunks: chunks)
        case let .redirect(destination):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": destination.absoluteString]
            )!
            client?.urlProtocol(
                self,
                wasRedirectedTo: URLRequest(url: destination),
                redirectResponse: response
            )
        case let .responseURL(responseURL):
            respond(
                status: 200,
                headers: ["Content-Type": "image/png"],
                chunks: [Data()],
                responseURL: responseURL
            )
        case .hold:
            break
        }
    }

    override func stopLoading() {
        guard let generation = loadGeneration.withLock({ generation in
            defer { generation = nil }
            return generation
        }) else { return }
        Self.state.recordStop(generation: generation)
    }

    private func respond(
        status: Int,
        headers: [String: String],
        chunks: [Data],
        responseURL: URL? = nil
    ) {
        let response = HTTPURLResponse(
            url: responseURL ?? request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

nonisolated
private final class ImageURLProtocolFixtureState: @unchecked Sendable {
    private struct Storage {
        var scenario: ImageURLProtocolFixture.Scenario = .success(data: Data())
        var generation: UInt64 = 0
        var requestedURLs: [URL] = []
        var stopCount = 0
        var started = false
        var waiters: [CheckedContinuation<Void, Never>] = []
        var stopWaiters: [CheckedContinuation<Void, Never>] = []
    }

    private let storage = Mutex(Storage())

    var requestedURLs: [URL] { storage.withLock { $0.requestedURLs } }
    var stopCount: Int { storage.withLock { $0.stopCount } }

    func reset(_ scenario: ImageURLProtocolFixture.Scenario) {
        storage.withLock {
            precondition($0.generation < UInt64.max, "Image URL fixture generation exhausted")
            $0 = Storage(scenario: scenario, generation: $0.generation + 1)
        }
    }

    func recordStart(
        _ url: URL
    ) -> (scenario: ImageURLProtocolFixture.Scenario, generation: UInt64) {
        storage.withLock {
            $0.requestedURLs.append(url)
            $0.started = true
            let waiters = $0.waiters
            $0.waiters = []
            for waiter in waiters { waiter.resume() }
            return ($0.scenario, $0.generation)
        }
    }

    func recordStop(generation: UInt64) {
        storage.withLock {
            guard $0.generation == generation else { return }
            $0.stopCount += 1
            let waiters = $0.stopWaiters
            $0.stopWaiters = []
            for waiter in waiters { waiter.resume() }
        }
    }

    func waitUntilStarted() async {
        if storage.withLock({ $0.started }) { return }
        await withCheckedContinuation { continuation in
            storage.withLock {
                if $0.started {
                    continuation.resume()
                } else {
                    $0.waiters.append(continuation)
                }
            }
        }
    }

    func waitUntilStopped() async {
        if storage.withLock({ $0.stopCount > 0 }) { return }
        await withCheckedContinuation { continuation in
            storage.withLock {
                if $0.stopCount > 0 {
                    continuation.resume()
                } else {
                    $0.stopWaiters.append(continuation)
                }
            }
        }
    }
}
