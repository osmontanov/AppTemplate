import Foundation
import Testing
@testable import AppTemplate

struct NetworkProviderTests {
    @Test
    func mapsLiveHTTPTransportResponse() async throws {
        let body = Data(#"{"value":"ok"}"#.utf8)
        let transport = makeHTTPTransport(
            statusCode: 201,
            data: body,
            headers: ["X-Request-ID": "request-123"]
        )
        let provider = NetworkProvider<ProviderTarget>(transport: transport)

        let response = try await provider.request(
            ProviderTarget(path: "/created", method: .post)
        )
        let requests = await transport.recordedRequests()

        #expect(response.statusCode == 201)
        #expect(response.data == body)
        #expect(response.url?.absoluteString == "https://api.example.test/created")
        #expect(response.headers.values.contains("request-123"))
        #expect(response.request == requests.first)
    }

    @Test
    func adaptersComposeInRegistrationOrderBeforeTransport() async throws {
        let transport = makeHTTPTransport(statusCode: 200)
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            adapters: [
                AppendingHeaderAdapter(value: "first"),
                AppendingHeaderAdapter(value: "second")
            ]
        )

        _ = try await provider.request(ProviderTarget())
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)

        #expect(
            request.value(forHTTPHeaderField: "X-Adapter-Order") ==
                "first|second"
        )
    }

    @Test
    func monitorsObserveWillSendAndCompletionInRegistrationOrder() async throws {
        let transport = makeHTTPTransport(statusCode: 204)
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "first", recorder: recorder),
                RecordingNetworkEventMonitor(name: "second", recorder: recorder)
            ]
        )

        _ = try await provider.request(ProviderTarget())
        let events = await recorder.recordedEvents()

        #expect(events == [
            .willSend(monitor: "first"),
            .willSend(monitor: "second"),
            .didComplete(
                monitor: "first",
                outcome: .success(statusCode: 204)
            ),
            .didComplete(
                monitor: "second",
                outcome: .success(statusCode: 204)
            )
        ])
    }

    @Test
    func defaultValidationRejectsNonSuccessfulStatusAndRetainsBody() async {
        let body = Data(#"{"error":"missing"}"#.utf8)
        let transport = makeHTTPTransport(statusCode: 404, data: body)
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected status validation to fail")
        } catch let NetworkError.unacceptableStatus(response) {
            #expect(response.statusCode == 404)
            #expect(response.data == body)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(
                monitor: "observer",
                outcome: .unacceptableStatus(statusCode: 404)
            )
        ])
    }

    @Test(arguments: [
        ValidationExpectation(
            name: "redirects",
            validation: .successfulAndRedirects,
            statusCode: 302
        ),
        ValidationExpectation(
            name: "custom range",
            validation: .range(418..<419),
            statusCode: 418
        ),
        ValidationExpectation(
            name: "disabled",
            validation: .none,
            statusCode: 503
        )
    ])
    func acceptsConfiguredStatusCode(_ expectation: ValidationExpectation) async throws {
        let provider = NetworkProvider<ProviderTarget>(
            transport: makeHTTPTransport(statusCode: expectation.statusCode)
        )
        let target = ProviderTarget(validation: expectation.validation)

        let response = try await provider.request(target)

        #expect(response.statusCode == expectation.statusCode)
    }

    @Test
    func rejectsNonHTTPResponse() async {
        let url = URL(string: "https://api.example.test/resource")!
        let transport = InMemoryNetworkTransport { _ in
            (
                Data(),
                URLResponse(
                    url: url,
                    mimeType: nil,
                    expectedContentLength: 0,
                    textEncodingName: nil
                )
            )
        }
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected a non-HTTP response failure")
        } catch NetworkError.nonHTTPResponse {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .nonHTTPResponse)
        ])
    }

    @Test
    func mapsCancellationErrorToCancelled() async {
        let transport = InMemoryNetworkTransport { _ in
            throw CancellationError()
        }
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected cancellation")
        } catch NetworkError.cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }

    @Test
    func mapsURLSessionCancellationToCancelled() async {
        let transport = InMemoryNetworkTransport { _ in
            throw URLError(.cancelled)
        }
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected cancellation")
        } catch NetworkError.cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }

    @Test
    func retainsUnderlyingTransportError() async {
        let transport = InMemoryNetworkTransport { _ in
            throw ProviderFixtureError.offline
        }
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected transport failure")
        } catch let NetworkError.transport(underlying) {
            #expect((underlying as? ProviderFixtureError) == .offline)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .transportFailure)
        ])
    }

    @Test
    func wrapsMismatchedAdapterNetworkErrorAtAdaptationBoundary() async {
        let transport = makeHTTPTransport(statusCode: 200)
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            adapters: [MismatchedNetworkErrorAdapter()],
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected adaptation failure")
        } catch let NetworkError.requestAdaptation(underlying) {
            guard case let NetworkError.transport(nested) = underlying else {
                Issue.record("Expected mismatched transport error to be retained")
                return
            }
            #expect((nested as? ProviderFixtureError) == .offline)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let requests = await transport.recordedRequests()
        let events = await recorder.recordedEvents()
        #expect(requests.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func wrapsMismatchedTransportNetworkErrorAtExecutionBoundary() async {
        let transport = InMemoryNetworkTransport { _ in
            throw NetworkError.requestConstruction
        }
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected transport failure")
        } catch let NetworkError.transport(underlying) {
            guard case NetworkError.requestConstruction = underlying else {
                Issue.record("Expected mismatched construction error to be retained")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .transportFailure)
        ])
    }

    @Test
    func constructionFailureDoesNotStartTransportOrMonitoring() async {
        let transport = makeHTTPTransport(statusCode: 200)
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )
        let target = ProviderTarget(
            baseURL: URL(string: "relative-base")!
        )

        do {
            _ = try await provider.request(target)
            Issue.record("Expected request construction failure")
        } catch NetworkError.requestConstruction {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let requests = await transport.recordedRequests()
        let events = await recorder.recordedEvents()
        #expect(requests.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func adaptationFailureDoesNotStartTransportOrMonitoring() async {
        let transport = makeHTTPTransport(statusCode: 200)
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<ProviderTarget>(
            transport: transport,
            adapters: [ThrowingAdapter()],
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ]
        )

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected adaptation failure")
        } catch let NetworkError.requestAdaptation(underlying) {
            #expect((underlying as? ProviderFixtureError) == .adaptation)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let requests = await transport.recordedRequests()
        let events = await recorder.recordedEvents()
        #expect(requests.isEmpty)
        #expect(events.isEmpty)
    }
}

nonisolated
private struct ProviderTarget: NetworkTarget {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let task: NetworkTask
    let headers: [String: String]
    let validation: StatusCodeValidation
    let sampleResponse: StubResponse

    init(
        baseURL: URL = URL(string: "https://api.example.test")!,
        path: String = "/resource",
        method: HTTPMethod = .get,
        task: NetworkTask = .plain,
        headers: [String: String] = [:],
        validation: StatusCodeValidation = .successful,
        sampleResponse: StubResponse = StubResponse()
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.task = task
        self.headers = headers
        self.validation = validation
        self.sampleResponse = sampleResponse
    }
}

nonisolated
struct ValidationExpectation: Sendable, CustomTestStringConvertible {
    let name: String
    let validation: StatusCodeValidation
    let statusCode: Int

    var testDescription: String { name }
}

nonisolated
private struct AppendingHeaderAdapter: RequestAdapter {
    let value: String

    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        var request = request
        let existing = request.value(forHTTPHeaderField: "X-Adapter-Order")
        request.setValue(
            [existing, value].compactMap { $0 }.joined(separator: "|"),
            forHTTPHeaderField: "X-Adapter-Order"
        )
        return request
    }
}

nonisolated
private struct ThrowingAdapter: RequestAdapter {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        throw ProviderFixtureError.adaptation
    }
}

nonisolated
private struct MismatchedNetworkErrorAdapter: RequestAdapter {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        throw NetworkError.transport(underlying: ProviderFixtureError.offline)
    }
}

nonisolated
private enum ProviderFixtureError: Error, Equatable {
    case offline
    case adaptation
}

private func makeHTTPTransport(
    statusCode: Int,
    data: Data = Data(),
    headers: [String: String] = [:]
) -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { request in
        let url = request.url ?? URL(string: "https://api.example.test")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (data, response)
    }
}
