# URLSession Network Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Moya-inspired, Swift 6 networking layer that describes endpoints as typed targets and executes them with async/await and `URLSession`.

**Architecture:** Feature code continues to use the domain-facing `IRemoteService`; `RemoteService` owns a generic `NetworkProvider<ExampleTarget>`. The provider composes a pure request builder, ordered asynchronous adapters and monitors, a replaceable transport, target-level stubbing, status validation, and raw response decoding without exposing networking details to features.

**Tech Stack:** Swift 6, Foundation, URLSession, Swift Testing, Xcode 26.6; no third-party packages.

## Global Constraints

- Keep `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `MACOSX_DEPLOYMENT_TARGET = 26.0`; support iPhone, iPad, and macOS.
- Keep `SWIFT_VERSION = 6.0`, strict concurrency, and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Declare networking value types, protocols, protocol extensions, and helpers `nonisolated`; keep `RemoteService` as an actor.
- Import only Foundation in the networking implementation.
- Provide async/await APIs only; do not add callbacks, Combine, RxSwift, or ReactiveSwift.
- Support plain requests, `[URLQueryItem]`, JSON bodies, and raw `Data` bodies only.
- Validate `200..<300` by default and retain complete raw responses in status and decoding errors.
- Keep adapters and monitors ordered, asynchronous, and `Sendable`.
- Do not add multipart upload, file download, progress, retries, token refresh, reachability, caching, request deduplication, certificate pinning, or authentication-challenge handling.
- Do not log headers or bodies by default.
- Do not perform public-internet or wall-clock-delay work in unit tests.
- Use test-first red-green-refactor cycles; every production behavior must first be observed failing for the intended reason.
- Files under `AppTemplate` and `AppTemplateTests` are synchronized Xcode groups and require no `project.pbxproj` edits.

## File Map

- `AppTemplate/App/Networking/Core/HTTPMethod.swift` — supported HTTP verbs.
- `AppTemplate/App/Networking/Core/NetworkBody.swift` — deferred JSON and raw request bodies.
- `AppTemplate/App/Networking/Core/NetworkTask.swift` — composable query and body description.
- `AppTemplate/App/Networking/Core/StatusCodeValidation.swift` — target status acceptance policy.
- `AppTemplate/App/Networking/Core/NetworkTarget.swift` — endpoint contract and defaults.
- `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift` — pure `NetworkTarget` to `URLRequest` construction.
- `AppTemplate/App/Networking/Response/NetworkResponse.swift` — raw HTTP result and decoding entry point.
- `AppTemplate/App/Networking/Response/NetworkError.swift` — normalized construction, transport, validation, and decoding failures.
- `AppTemplate/App/Networking/Pipeline/RequestAdapter.swift` — asynchronous request mutation boundary.
- `AppTemplate/App/Networking/Pipeline/NetworkEventMonitor.swift` — ordered, read-only lifecycle observation.
- `AppTemplate/App/Networking/Transport/NetworkTransport.swift` — external I/O boundary.
- `AppTemplate/App/Networking/Transport/URLSessionTransport.swift` — live Foundation transport.
- `AppTemplate/App/Networking/Stubbing/StubResponse.swift` — target sample status, headers, and body.
- `AppTemplate/App/Networking/Stubbing/StubBehavior.swift` — never, immediate, and delayed stub policy.
- `AppTemplate/App/Networking/NetworkProvider.swift` — request pipeline orchestration.
- `AppTemplate/App/Services/Remote/ExampleTarget.swift` — neutral example endpoint.
- `AppTemplate/App/Services/Remote/IRemoteService.swift` — domain-facing example operation.
- `AppTemplate/App/Services/Remote/RemoteService.swift` — provider-owning service actor.
- `AppTemplateTests/TestSupport/Networking/InMemoryNetworkTransport.swift` — deterministic transport and request recorder.
- `AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift` — reusable ordered monitor recorder.
- `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift` — URL, method, query, header, and body behavior.
- `AppTemplateTests/App/Networking/NetworkResponseTests.swift` — decoding behavior and retained failure context.
- `AppTemplateTests/App/Networking/NetworkProviderTests.swift` — live pipeline, adapter, monitor, status, and error behavior.
- `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift` — immediate, delayed, validation, and cancellation stubs.
- `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift` — end-to-end domain service behavior.
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift` — injected test service conformance.
- `docs/ARCHITECTURE.md` — networking ownership and execution model.
- `docs/CUSTOMIZATION.md` — production adoption checklist.

---

### Task 1: Core Request Construction and Response Decoding

**Files:**
- Create: `AppTemplate/App/Networking/Core/HTTPMethod.swift`
- Create: `AppTemplate/App/Networking/Core/NetworkBody.swift`
- Create: `AppTemplate/App/Networking/Core/NetworkTask.swift`
- Create: `AppTemplate/App/Networking/Core/StatusCodeValidation.swift`
- Create: `AppTemplate/App/Networking/Core/NetworkTarget.swift`
- Create: `AppTemplate/App/Networking/Stubbing/StubResponse.swift`
- Create: `AppTemplate/App/Networking/Response/NetworkError.swift`
- Create: `AppTemplate/App/Networking/Response/NetworkResponse.swift`
- Create: `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift`
- Test: `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift`
- Test: `AppTemplateTests/App/Networking/NetworkResponseTests.swift`

**Interfaces:**
- Consumes: Foundation `URL`, `URLComponents`, `URLQueryItem`, `URLRequest`, `Data`, `JSONEncoder`, and `JSONDecoder`.
- Produces: `HTTPMethod`, `NetworkBody`, `NetworkTask`, `StatusCodeValidation`, `NetworkTarget`, `StubResponse`, `NetworkError`, `NetworkResponse`, and `NetworkRequestBuilder.build<Target: NetworkTarget>(_:) throws -> URLRequest`.

- [ ] **Step 1: Write failing request-builder tests**

Create `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct NetworkRequestBuilderTests {
    @Test
    func buildsJSONRequestWithEncodedQueryAndTargetHeaders() throws {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "https://api.example.test/v1")!,
            path: "/items",
            method: .post,
            task: .json(
                Payload(name: "Moya replacement"),
                queryItems: [
                    URLQueryItem(name: "q", value: "swift moya"),
                    URLQueryItem(name: "page", value: "2")
                ]
            ),
            headers: ["X-Client": "AppTemplate"]
        )

        let request = try NetworkRequestBuilder().build(target)
        let body = try #require(request.httpBody)
        let object = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(
            request.url?.absoluteString ==
                "https://api.example.test/v1/items?q=swift%20moya&page=2"
        )
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Client") == "AppTemplate")
        #expect(object == ["name": "Moya replacement"])
    }

    @Test
    func plainRequestHasNoBodyOrGeneratedContentType() throws {
        let request = try NetworkRequestBuilder().build(
            RequestBuilderTarget(task: .plain)
        )

        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test
    func preservesBaseQueryWhenAppendingTargetQuery() throws {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "https://api.example.test/v1?locale=en")!,
            path: "/items",
            task: .query([URLQueryItem(name: "page", value: "3")])
        )

        let request = try NetworkRequestBuilder().build(target)
        let queryItems = URLComponents(
            url: try #require(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems

        #expect(queryItems?.first { $0.name == "locale" }?.value == "en")
        #expect(queryItems?.first { $0.name == "page" }?.value == "3")
    }

    @Test
    func usesConfiguredJSONEncoderFactory() throws {
        let builder = NetworkRequestBuilder {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }
        let target = RequestBuilderTarget(
            task: .json(CamelCasePayload(itemName: "Configured"))
        )

        let request = try builder.build(target)
        let body = try #require(request.httpBody)
        let object = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(object == ["item_name": "Configured"])
    }

    @Test(arguments: [
        MethodExpectation(method: .get, rawValue: "GET"),
        MethodExpectation(method: .post, rawValue: "POST"),
        MethodExpectation(method: .put, rawValue: "PUT"),
        MethodExpectation(method: .patch, rawValue: "PATCH"),
        MethodExpectation(method: .delete, rawValue: "DELETE"),
        MethodExpectation(method: .head, rawValue: "HEAD")
    ])
    func writesEverySupportedHTTPMethod(_ expectation: MethodExpectation) throws {
        let target = RequestBuilderTarget(method: expectation.method)

        let request = try NetworkRequestBuilder().build(target)

        #expect(request.httpMethod == expectation.rawValue)
    }

    @Test
    func buildsRawBodyAndAllowsCaseInsensitiveContentTypeOverride() throws {
        let payload = Data([0x01, 0x02, 0x03])
        let target = RequestBuilderTarget(
            path: "/upload",
            method: .put,
            task: .data(payload, contentType: "application/octet-stream"),
            headers: ["content-type": "application/vnd.example.binary"]
        )

        let request = try NetworkRequestBuilder().build(target)

        #expect(request.httpBody == payload)
        #expect(
            request.value(forHTTPHeaderField: "Content-Type") ==
                "application/vnd.example.binary"
        )
    }

    @Test
    func rejectsRelativeBaseURL() {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "relative-base")!
        )

        do {
            _ = try NetworkRequestBuilder().build(target)
            Issue.record("Expected request construction to fail")
        } catch NetworkError.requestConstruction {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func wrapsJSONEncodingFailure() {
        let target = RequestBuilderTarget(task: .json(ThrowingPayload()))

        do {
            _ = try NetworkRequestBuilder().build(target)
            Issue.record("Expected request encoding to fail")
        } catch let NetworkError.requestEncoding(underlying) {
            #expect(underlying is TestEncodingError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

nonisolated
private struct MethodExpectation: Sendable, CustomTestStringConvertible {
    let method: HTTPMethod
    let rawValue: String

    var testDescription: String { rawValue }
}

nonisolated
private struct RequestBuilderTarget: NetworkTarget {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let task: NetworkTask
    let headers: [String: String]

    init(
        baseURL: URL = URL(string: "https://api.example.test")!,
        path: String = "/resource",
        method: HTTPMethod = .get,
        task: NetworkTask = .plain,
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.task = task
        self.headers = headers
    }
}

nonisolated
private struct Payload: Encodable, Sendable {
    let name: String
}

nonisolated
private struct CamelCasePayload: Encodable, Sendable {
    let itemName: String
}

nonisolated
private struct ThrowingPayload: Encodable, Sendable {
    func encode(to encoder: Encoder) throws {
        throw TestEncodingError.expected
    }
}

nonisolated
private enum TestEncodingError: Error {
    case expected
}
```

- [ ] **Step 2: Write failing response-decoding tests**

Create `AppTemplateTests/App/Networking/NetworkResponseTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct NetworkResponseTests {
    @Test
    func decodesModelFromRawData() throws {
        let response = makeResponse(
            data: Data(#"{"id":"example-42","title":"Remote example"}"#.utf8)
        )

        let value = try response.decode(ExampleResponse.self)

        #expect(
            value == ExampleResponse(
                id: "example-42",
                title: "Remote example"
            )
        )
    }

    @Test
    func decodingFailureRetainsOriginalResponse() {
        let response = makeResponse(data: Data(#"{"id":42}"#.utf8))

        do {
            let _: ExampleResponse = try response.decode(ExampleResponse.self)
            Issue.record("Expected decoding to fail")
        } catch let NetworkError.decoding(underlying, retainedResponse) {
            #expect(underlying is DecodingError)
            #expect(retainedResponse.statusCode == 200)
            #expect(retainedResponse.data == response.data)
            #expect(retainedResponse.request.url == response.request.url)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func makeResponse(data: Data) -> NetworkResponse {
    let url = URL(string: "https://api.example.test/examples")!
    return NetworkResponse(
        request: URLRequest(url: url),
        url: url,
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        data: data
    )
}
```

- [ ] **Step 3: Run the focused tests and verify the RED state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests
```

Expected: exit 65 because `NetworkTarget`, `NetworkRequestBuilder`,
`NetworkResponse`, and the other networking types do not exist. Confirm these
missing symbols—not a fixture typo—cause the failure.

- [ ] **Step 4: Implement the core request and response values**

Create `AppTemplate/App/Networking/Core/HTTPMethod.swift`:

```swift
nonisolated
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
}
```

Create `AppTemplate/App/Networking/Core/NetworkBody.swift`:

```swift
import Foundation

nonisolated
enum NetworkBody: Sendable {
    case json(any Encodable & Sendable)
    case data(Data, contentType: String?)
}
```

Create `AppTemplate/App/Networking/Core/NetworkTask.swift`:

```swift
import Foundation

nonisolated
struct NetworkTask: Sendable {
    let queryItems: [URLQueryItem]
    let body: NetworkBody?

    static let plain = NetworkTask(queryItems: [], body: nil)

    static func query(_ queryItems: [URLQueryItem]) -> NetworkTask {
        NetworkTask(queryItems: queryItems, body: nil)
    }

    static func json<Payload: Encodable & Sendable>(
        _ payload: Payload,
        queryItems: [URLQueryItem] = []
    ) -> NetworkTask {
        NetworkTask(queryItems: queryItems, body: .json(payload))
    }

    static func data(
        _ data: Data,
        contentType: String? = nil,
        queryItems: [URLQueryItem] = []
    ) -> NetworkTask {
        NetworkTask(
            queryItems: queryItems,
            body: .data(data, contentType: contentType)
        )
    }
}
```

Create `AppTemplate/App/Networking/Core/StatusCodeValidation.swift`:

```swift
nonisolated
enum StatusCodeValidation: Sendable {
    case successful
    case successfulAndRedirects
    case range(Range<Int>)
    case none

    func accepts(_ statusCode: Int) -> Bool {
        switch self {
        case .successful:
            (200..<300).contains(statusCode)
        case .successfulAndRedirects:
            (200..<400).contains(statusCode)
        case let .range(range):
            range.contains(statusCode)
        case .none:
            true
        }
    }
}
```

Create `AppTemplate/App/Networking/Stubbing/StubResponse.swift`:

```swift
import Foundation

nonisolated
struct StubResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    init(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }
}
```

Create `AppTemplate/App/Networking/Core/NetworkTarget.swift`:

```swift
import Foundation

nonisolated
protocol NetworkTarget: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String] { get }
    var validation: StatusCodeValidation { get }
    var sampleResponse: StubResponse { get }
}

nonisolated
extension NetworkTarget {
    var task: NetworkTask { .plain }
    var headers: [String: String] { [:] }
    var validation: StatusCodeValidation { .successful }
    var sampleResponse: StubResponse { StubResponse() }
}
```

Create `AppTemplate/App/Networking/Response/NetworkError.swift`:

```swift
import Foundation

nonisolated
enum NetworkError: Error {
    case requestConstruction
    case requestEncoding(underlying: any Error)
    case requestAdaptation(underlying: any Error)
    case transport(underlying: any Error)
    case cancelled
    case nonHTTPResponse
    case unacceptableStatus(NetworkResponse)
    case decoding(underlying: any Error, response: NetworkResponse)
}
```

Create `AppTemplate/App/Networking/Response/NetworkResponse.swift`:

```swift
import Foundation

nonisolated
struct NetworkResponse: Sendable {
    let request: URLRequest
    let url: URL?
    let statusCode: Int
    let headers: [String: String]
    let data: Data

    func decode<Value: Decodable>(
        _ type: Value.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decoding(
                underlying: error,
                response: self
            )
        }
    }
}
```

- [ ] **Step 5: Implement deterministic request construction**

Create `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift`:

```swift
import Foundation

nonisolated
struct NetworkRequestBuilder: Sendable {
    private let jsonEncoderFactory: @Sendable () -> JSONEncoder

    init(
        jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = {
            JSONEncoder()
        }
    ) {
        self.jsonEncoderFactory = jsonEncoderFactory
    }

    func build<Target: NetworkTarget>(_ target: Target) throws -> URLRequest {
        let urlWithPath = target.baseURL.appending(path: target.path)
        guard
            var components = URLComponents(
                url: urlWithPath,
                resolvingAgainstBaseURL: false
            ),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            throw NetworkError.requestConstruction
        }

        if !target.task.queryItems.isEmpty {
            components.queryItems =
                (components.queryItems ?? []) + target.task.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.requestConstruction
        }

        var request = URLRequest(url: url)
        request.httpMethod = target.method.rawValue

        if let body = target.task.body {
            try apply(body, to: &request)
        }

        for (name, value) in target.headers {
            let normalizedName =
                name.caseInsensitiveCompare("Content-Type") == .orderedSame
                ? "Content-Type"
                : name
            request.setValue(value, forHTTPHeaderField: normalizedName)
        }

        return request
    }

    private func apply(
        _ body: NetworkBody,
        to request: inout URLRequest
    ) throws {
        switch body {
        case let .json(payload):
            do {
                request.httpBody = try jsonEncoderFactory().encode(payload)
            } catch {
                throw NetworkError.requestEncoding(underlying: error)
            }
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )

        case let .data(data, contentType):
            request.httpBody = data
            if let contentType {
                request.setValue(
                    contentType,
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }
    }
}
```

- [ ] **Step 6: Run focused tests and verify the GREEN state**

Run the Step 3 command again.

Expected: `NetworkRequestBuilderTests` and `NetworkResponseTests` pass with no
warnings. Confirm that temporarily changing `.successful` to accept `300` does
not affect these tests; status behavior is intentionally protected in Task 2.

- [ ] **Step 7: Commit the request-construction slice**

```bash
git add \
  AppTemplate/App/Networking/Core \
  AppTemplate/App/Networking/RequestBuilding \
  AppTemplate/App/Networking/Response \
  AppTemplate/App/Networking/Stubbing/StubResponse.swift \
  AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift \
  AppTemplateTests/App/Networking/NetworkResponseTests.swift
git commit -m "feat: add network request primitives"
```

---

### Task 2: Live Provider Pipeline, Adapters, Monitors, and Validation

**Files:**
- Create: `AppTemplate/App/Networking/Pipeline/RequestAdapter.swift`
- Create: `AppTemplate/App/Networking/Pipeline/NetworkEventMonitor.swift`
- Create: `AppTemplate/App/Networking/Transport/NetworkTransport.swift`
- Create: `AppTemplate/App/Networking/Transport/URLSessionTransport.swift`
- Create: `AppTemplate/App/Networking/NetworkProvider.swift`
- Create: `AppTemplateTests/TestSupport/Networking/InMemoryNetworkTransport.swift`
- Create: `AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift`
- Test: `AppTemplateTests/App/Networking/NetworkProviderTests.swift`

**Interfaces:**
- Consumes: `NetworkTarget`, `NetworkRequestBuilder`, `NetworkResponse`, `NetworkError`, and `StatusCodeValidation.accepts(_:)` from Task 1.
- Produces: `RequestAdapter.adapt(_:target:)`, `NetworkEventMonitor.willSend(_:target:)`, `NetworkEventMonitor.didComplete(_:target:)`, `NetworkTransport.data(for:)`, `URLSessionTransport`, and `NetworkProvider<Target>.request(_:) async throws -> NetworkResponse` for live transport execution.

- [ ] **Step 1: Add deterministic transport and monitor test support**

Create `AppTemplateTests/TestSupport/Networking/InMemoryNetworkTransport.swift`:

```swift
import Foundation
@testable import AppTemplate

actor InMemoryNetworkTransport: NetworkTransport {
    typealias Handler = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let handler: Handler
    private var requests: [URLRequest] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try await handler(request)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
```

Create `AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift`:

```swift
import Foundation
@testable import AppTemplate

nonisolated
enum RecordedNetworkOutcome: Equatable, Sendable {
    case success(statusCode: Int)
    case unacceptableStatus(statusCode: Int)
    case cancelled
    case otherFailure
}

nonisolated
enum RecordedNetworkEvent: Equatable, Sendable {
    case willSend(monitor: String)
    case didComplete(monitor: String, outcome: RecordedNetworkOutcome)
}

actor NetworkEventRecorder {
    private var events: [RecordedNetworkEvent] = []

    func append(_ event: RecordedNetworkEvent) {
        events.append(event)
    }

    func recordedEvents() -> [RecordedNetworkEvent] {
        events
    }
}

nonisolated
struct RecordingNetworkEventMonitor: NetworkEventMonitor {
    let name: String
    let recorder: NetworkEventRecorder

    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async {
        await recorder.append(.willSend(monitor: name))
    }

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async {
        let outcome: RecordedNetworkOutcome
        switch result {
        case let .success(response):
            outcome = .success(statusCode: response.statusCode)
        case let .failure(.unacceptableStatus(response)):
            outcome = .unacceptableStatus(statusCode: response.statusCode)
        case .failure(.cancelled):
            outcome = .cancelled
        case .failure:
            outcome = .otherFailure
        }

        await recorder.append(
            .didComplete(monitor: name, outcome: outcome)
        )
    }
}
```

- [ ] **Step 2: Write failing live-provider tests**

Create `AppTemplateTests/App/Networking/NetworkProviderTests.swift`:

```swift
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
        let provider = NetworkProvider<ProviderTarget>(transport: transport)

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected a non-HTTP response failure")
        } catch NetworkError.nonHTTPResponse {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func mapsCancellationErrorToCancelled() async {
        let transport = InMemoryNetworkTransport { _ in
            throw CancellationError()
        }
        let provider = NetworkProvider<ProviderTarget>(transport: transport)

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected cancellation")
        } catch NetworkError.cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func mapsURLSessionCancellationToCancelled() async {
        let transport = InMemoryNetworkTransport { _ in
            throw URLError(.cancelled)
        }
        let provider = NetworkProvider<ProviderTarget>(transport: transport)

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected cancellation")
        } catch NetworkError.cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func retainsUnderlyingTransportError() async {
        let transport = InMemoryNetworkTransport { _ in
            throw ProviderFixtureError.offline
        }
        let provider = NetworkProvider<ProviderTarget>(transport: transport)

        do {
            _ = try await provider.request(ProviderTarget())
            Issue.record("Expected transport failure")
        } catch let NetworkError.transport(underlying) {
            #expect((underlying as? ProviderFixtureError) == .offline)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
private struct ValidationExpectation: Sendable, CustomTestStringConvertible {
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
```

- [ ] **Step 3: Run the provider tests and verify the RED state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/NetworkProviderTests
```

Expected: exit 65 because `NetworkTransport`, `RequestAdapter`,
`NetworkEventMonitor`, and `NetworkProvider` do not exist. Confirm the test
support compiles as far as those missing production interfaces.

- [ ] **Step 4: Implement adapter, monitor, and transport boundaries**

Create `AppTemplate/App/Networking/Pipeline/RequestAdapter.swift`:

```swift
import Foundation

nonisolated
protocol RequestAdapter: Sendable {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest
}
```

Create `AppTemplate/App/Networking/Pipeline/NetworkEventMonitor.swift`:

```swift
import Foundation

nonisolated
protocol NetworkEventMonitor: Sendable {
    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async
}

nonisolated
extension NetworkEventMonitor {
    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async {}

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async {}
}
```

Create `AppTemplate/App/Networking/Transport/NetworkTransport.swift`:

```swift
import Foundation

nonisolated
protocol NetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
```

Create `AppTemplate/App/Networking/Transport/URLSessionTransport.swift`:

```swift
import Foundation

nonisolated
struct URLSessionTransport: NetworkTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request, delegate: nil)
    }
}
```

- [ ] **Step 5: Implement live provider execution and normalization**

Create `AppTemplate/App/Networking/NetworkProvider.swift`:

```swift
import Foundation

nonisolated
struct NetworkProvider<Target: NetworkTarget>: Sendable {
    private let transport: any NetworkTransport
    private let adapters: [any RequestAdapter]
    private let monitors: [any NetworkEventMonitor]
    private let requestBuilder: NetworkRequestBuilder

    init(
        transport: any NetworkTransport = URLSessionTransport(),
        adapters: [any RequestAdapter] = [],
        monitors: [any NetworkEventMonitor] = [],
        jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = {
            JSONEncoder()
        }
    ) {
        self.transport = transport
        self.adapters = adapters
        self.monitors = monitors
        requestBuilder = NetworkRequestBuilder(
            jsonEncoderFactory: jsonEncoderFactory
        )
    }

    func request(_ target: Target) async throws -> NetworkResponse {
        var request = try requestBuilder.build(target)

        do {
            for adapter in adapters {
                request = try await adapter.adapt(request, target: target)
            }
        } catch {
            throw normalize(
                error,
                fallback: { .requestAdaptation(underlying: $0) }
            )
        }

        for monitor in monitors {
            await monitor.willSend(request, target: target)
        }

        let result = await liveResult(for: request, target: target)

        for monitor in monitors {
            await monitor.didComplete(result, target: target)
        }

        return try result.get()
    }

    private func liveResult(
        for request: URLRequest,
        target: Target
    ) async -> Result<NetworkResponse, NetworkError> {
        do {
            let (data, urlResponse) = try await transport.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkError.nonHTTPResponse
            }

            let response = NetworkResponse(
                request: request,
                url: httpResponse.url,
                statusCode: httpResponse.statusCode,
                headers: stringHeaders(from: httpResponse),
                data: data
            )

            guard target.validation.accepts(response.statusCode) else {
                throw NetworkError.unacceptableStatus(response)
            }

            return .success(response)
        } catch {
            return .failure(
                normalize(
                    error,
                    fallback: { .transport(underlying: $0) }
                )
            )
        }
    }

    private func normalize(
        _ error: any Error,
        fallback: (any Error) -> NetworkError
    ) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .cancelled
        }
        return fallback(error)
    }

    private func stringHeaders(
        from response: HTTPURLResponse
    ) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, field in
            guard let name = field.key as? String else { return }
            headers[name] = String(describing: field.value)
        }
    }
}
```

- [ ] **Step 6: Run provider and core tests and verify the GREEN state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests \
  -only-testing:AppTemplateTests/NetworkProviderTests
```

Expected: all focused tests pass without warnings. Mutation check: changing
the default accepted range to `200..<400`, reversing either adapter or monitor
iteration, or returning an empty body must fail at least one named test.

- [ ] **Step 7: Commit the live provider slice**

```bash
git add \
  AppTemplate/App/Networking/Pipeline \
  AppTemplate/App/Networking/Transport \
  AppTemplate/App/Networking/NetworkProvider.swift \
  AppTemplateTests/TestSupport/Networking \
  AppTemplateTests/App/Networking/NetworkProviderTests.swift
git commit -m "feat: execute live network targets"
```

---

### Task 3: Deterministic Immediate and Delayed Target Stubs

**Files:**
- Create: `AppTemplate/App/Networking/Stubbing/StubBehavior.swift`
- Modify: `AppTemplate/App/Networking/NetworkProvider.swift`
- Test: `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`

**Interfaces:**
- Consumes: the live `NetworkProvider<Target>` pipeline, `Target.sampleResponse`, adapter/monitor protocols, validation, and test support from Tasks 1–2.
- Produces: `StubBehavior.never`, `.immediate`, `.delayed(Duration)`, plus provider initializer arguments `stubBehavior: @Sendable (Target) -> StubBehavior` and `sleep: @Sendable (Duration) async throws -> Void`.

- [ ] **Step 1: Write failing target-stub tests**

Create `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct NetworkProviderStubTests {
    @Test
    func immediateStubRunsAdapterAndMonitorButBypassesTransport() async throws {
        let data = Data(#"{"source":"sample"}"#.utf8)
        let transport = unexpectedTransport()
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: transport,
            adapters: [StubHeaderAdapter()],
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ],
            stubBehavior: { _ in .immediate }
        )
        let target = StubTarget(
            sampleResponse: StubResponse(
                statusCode: 201,
                data: data,
                headers: ["X-Stub": "true"]
            )
        )

        let response = try await provider.request(target)
        let requests = await transport.recordedRequests()
        let events = await recorder.recordedEvents()

        #expect(response.statusCode == 201)
        #expect(response.data == data)
        #expect(response.headers == ["X-Stub": "true"])
        #expect(response.request.value(forHTTPHeaderField: "X-Stub-Adapter") == "applied")
        #expect(requests.isEmpty)
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(
                monitor: "observer",
                outcome: .success(statusCode: 201)
            )
        ])
    }

    @Test
    func delayedStubUsesInjectedSleepWithoutWallClockWaiting() async throws {
        let sleepRecorder = SleepRecorder()
        let transport = unexpectedTransport()
        let provider = NetworkProvider<StubTarget>(
            transport: transport,
            stubBehavior: { _ in .delayed(.seconds(2)) },
            sleep: { duration in
                await sleepRecorder.record(duration)
            }
        )

        let response = try await provider.request(StubTarget())
        let durations = await sleepRecorder.recordedDurations()
        let requests = await transport.recordedRequests()

        #expect(response.statusCode == 200)
        #expect(durations == [.seconds(2)])
        #expect(requests.isEmpty)
    }

    @Test
    func cancellationDuringDelayedStubIsNormalizedAndMonitored() async {
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ],
            stubBehavior: { _ in .delayed(.seconds(10)) },
            sleep: { _ in throw CancellationError() }
        )

        do {
            _ = try await provider.request(StubTarget())
            Issue.record("Expected delayed stub cancellation")
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
    func stubResponseStillUsesTargetStatusValidation() async {
        let body = Data(#"{"error":"unavailable"}"#.utf8)
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            stubBehavior: { _ in .immediate }
        )
        let target = StubTarget(
            sampleResponse: StubResponse(statusCode: 503, data: body)
        )

        do {
            _ = try await provider.request(target)
            Issue.record("Expected stub validation to fail")
        } catch let NetworkError.unacceptableStatus(response) {
            #expect(response.statusCode == 503)
            #expect(response.data == body)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

nonisolated
private struct StubTarget: NetworkTarget {
    let baseURL = URL(string: "https://api.example.test")!
    let path = "/stubbed"
    let method = HTTPMethod.get
    let sampleResponse: StubResponse

    init(sampleResponse: StubResponse = StubResponse()) {
        self.sampleResponse = sampleResponse
    }
}

nonisolated
private struct StubHeaderAdapter: RequestAdapter {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        var request = request
        request.setValue("applied", forHTTPHeaderField: "X-Stub-Adapter")
        return request
    }
}

private actor SleepRecorder {
    private var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }

    func recordedDurations() -> [Duration] {
        durations
    }
}

nonisolated
private enum StubFixtureError: Error {
    case unexpectedTransport
}

private func unexpectedTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw StubFixtureError.unexpectedTransport
    }
}
```

- [ ] **Step 2: Run stub tests and verify the RED state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/NetworkProviderStubTests
```

Expected: exit 65 because `StubBehavior`, `stubBehavior`, and `sleep` do not
exist. Confirm the failure is caused by the missing stub API.

- [ ] **Step 3: Add the stub policy**

Create `AppTemplate/App/Networking/Stubbing/StubBehavior.swift`:

```swift
import Foundation

nonisolated
enum StubBehavior: Sendable {
    case never
    case immediate
    case delayed(Duration)
}
```

- [ ] **Step 4: Extend the provider so live and stubbed responses share validation**

Replace `AppTemplate/App/Networking/NetworkProvider.swift` with:

```swift
import Foundation

nonisolated
struct NetworkProvider<Target: NetworkTarget>: Sendable {
    private let transport: any NetworkTransport
    private let adapters: [any RequestAdapter]
    private let monitors: [any NetworkEventMonitor]
    private let requestBuilder: NetworkRequestBuilder
    private let stubBehavior: @Sendable (Target) -> StubBehavior
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        transport: any NetworkTransport = URLSessionTransport(),
        adapters: [any RequestAdapter] = [],
        monitors: [any NetworkEventMonitor] = [],
        jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = {
            JSONEncoder()
        },
        stubBehavior: @escaping @Sendable (Target) -> StubBehavior = { _ in
            .never
        },
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.transport = transport
        self.adapters = adapters
        self.monitors = monitors
        requestBuilder = NetworkRequestBuilder(
            jsonEncoderFactory: jsonEncoderFactory
        )
        self.stubBehavior = stubBehavior
        self.sleep = sleep
    }

    func request(_ target: Target) async throws -> NetworkResponse {
        var request = try requestBuilder.build(target)

        do {
            for adapter in adapters {
                request = try await adapter.adapt(request, target: target)
            }
        } catch {
            throw normalize(
                error,
                fallback: { .requestAdaptation(underlying: $0) }
            )
        }

        for monitor in monitors {
            await monitor.willSend(request, target: target)
        }

        let result = await result(for: request, target: target)

        for monitor in monitors {
            await monitor.didComplete(result, target: target)
        }

        return try result.get()
    }

    private func result(
        for request: URLRequest,
        target: Target
    ) async -> Result<NetworkResponse, NetworkError> {
        do {
            let response: NetworkResponse
            switch stubBehavior(target) {
            case .never:
                response = try await liveResponse(for: request)
            case .immediate:
                response = stubResponse(for: request, target: target)
            case let .delayed(duration):
                try await sleep(duration)
                response = stubResponse(for: request, target: target)
            }

            guard target.validation.accepts(response.statusCode) else {
                throw NetworkError.unacceptableStatus(response)
            }

            return .success(response)
        } catch {
            return .failure(
                normalize(
                    error,
                    fallback: { .transport(underlying: $0) }
                )
            )
        }
    }

    private func liveResponse(
        for request: URLRequest
    ) async throws -> NetworkResponse {
        let (data, urlResponse) = try await transport.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.nonHTTPResponse
        }

        return NetworkResponse(
            request: request,
            url: httpResponse.url,
            statusCode: httpResponse.statusCode,
            headers: stringHeaders(from: httpResponse),
            data: data
        )
    }

    private func stubResponse(
        for request: URLRequest,
        target: Target
    ) -> NetworkResponse {
        NetworkResponse(
            request: request,
            url: request.url,
            statusCode: target.sampleResponse.statusCode,
            headers: target.sampleResponse.headers,
            data: target.sampleResponse.data
        )
    }

    private func normalize(
        _ error: any Error,
        fallback: (any Error) -> NetworkError
    ) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .cancelled
        }
        return fallback(error)
    }

    private func stringHeaders(
        from response: HTTPURLResponse
    ) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, field in
            guard let name = field.key as? String else { return }
            headers[name] = String(describing: field.value)
        }
    }
}
```

- [ ] **Step 5: Run all networking tests and verify the GREEN state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests
```

Expected: all networking tests pass without warnings and no test waits for a
real delay. Mutation check: routing `.immediate` through the transport, skipping
the sleep closure, or validating only live responses must fail a named test.

- [ ] **Step 6: Commit deterministic stubbing**

```bash
git add \
  AppTemplate/App/Networking/Stubbing/StubBehavior.swift \
  AppTemplate/App/Networking/NetworkProvider.swift \
  AppTemplateTests/App/Networking/NetworkProviderStubTests.swift
git commit -m "feat: add deterministic network stubs"
```

---

### Task 4: Domain-Facing Example Remote Service

**Files:**
- Create: `AppTemplate/App/Services/Remote/ExampleTarget.swift`
- Modify: `AppTemplate/App/Services/Remote/IRemoteService.swift:1-2`
- Modify: `AppTemplate/App/Services/Remote/RemoteService.swift:1`
- Modify: `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift:1-11`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift:138`

**Interfaces:**
- Consumes: `NetworkProvider<ExampleTarget>`, `ExampleRequest`, `ExampleResponse`, target stubbing, and the in-memory test transport.
- Produces: `ExampleTarget.fetch(baseURL:request:)`, `IRemoteService.fetchExample(_:) async throws -> ExampleResponse`, and injectable `RemoteService.init(baseURL:provider:)` with `https://example.invalid` as its safe unconfigured default.

- [ ] **Step 1: Replace the marker-service test with failing end-to-end tests**

Replace `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift` with:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct RemoteServiceTests {
    @Test
    func fetchExampleBuildsTargetQueryAndDecodesTransportResponse() async throws {
        let responseData = Data(
            #"{"id":"example-42","title":"Remote example"}"#.utf8
        )
        let transport = InMemoryNetworkTransport { request in
            let url = request.url ?? URL(string: "https://api.example.test")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (responseData, response)
        }
        let provider = NetworkProvider<ExampleTarget>(transport: transport)
        let service = RemoteService(
            baseURL: URL(string: "https://api.example.test/v1")!,
            provider: provider
        )

        let response = try await service.fetchExample(
            ExampleRequest(query: "swift moya", page: 2)
        )
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)
        let queryItems = URLComponents(
            url: try #require(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems

        #expect(
            response == ExampleResponse(
                id: "example-42",
                title: "Remote example"
            )
        )
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/v1/examples")
        #expect(queryItems?.first { $0.name == "query" }?.value == "swift moya")
        #expect(queryItems?.first { $0.name == "page" }?.value == "2")
    }

    @Test
    func fetchExampleSampleResponseDecodesWithoutTransport() async throws {
        let transport = unexpectedRemoteTransport()
        let provider = NetworkProvider<ExampleTarget>(
            transport: transport,
            stubBehavior: { _ in .immediate }
        )
        let service = RemoteService(
            baseURL: URL(string: "https://api.example.test")!,
            provider: provider
        )

        let response = try await service.fetchExample(
            ExampleRequest(query: "sample", page: 1)
        )
        let requests = await transport.recordedRequests()

        #expect(
            response == ExampleResponse(
                id: "sample-id",
                title: "Sample response"
            )
        )
        #expect(requests.isEmpty)
    }
}

nonisolated
private enum RemoteFixtureError: Error {
    case unexpectedTransport
}

private func unexpectedRemoteTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw RemoteFixtureError.unexpectedTransport
    }
}
```

- [ ] **Step 2: Run remote-service and composition tests and verify the RED state**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/RemoteServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests
```

Expected: exit 65 because `ExampleTarget`, the injectable `RemoteService`
initializer, and `fetchExample(_:)` do not exist. Confirm those missing domain
interfaces cause the failure.

- [ ] **Step 3: Define the example target and domain service contract**

Create `AppTemplate/App/Services/Remote/ExampleTarget.swift`:

```swift
import Foundation

nonisolated
enum ExampleTarget: NetworkTarget {
    case fetch(baseURL: URL, request: ExampleRequest)

    var baseURL: URL {
        switch self {
        case let .fetch(baseURL, _):
            baseURL
        }
    }

    var path: String { "/examples" }

    var method: HTTPMethod { .get }

    var task: NetworkTask {
        switch self {
        case let .fetch(_, request):
            .query([
                URLQueryItem(name: "query", value: request.query),
                URLQueryItem(name: "page", value: String(request.page))
            ])
        }
    }

    var sampleResponse: StubResponse {
        StubResponse(
            statusCode: 200,
            data: Data(
                #"{"id":"sample-id","title":"Sample response"}"#.utf8
            ),
            headers: ["Content-Type": "application/json"]
        )
    }
}
```

Replace `AppTemplate/App/Services/Remote/IRemoteService.swift` with:

```swift
nonisolated
protocol IRemoteService: Sendable {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse
}
```

- [ ] **Step 4: Implement the provider-owning service actor**

Replace `AppTemplate/App/Services/Remote/RemoteService.swift` with:

```swift
import Foundation

actor RemoteService: IRemoteService {
    nonisolated static let defaultBaseURL = URL(
        string: "https://example.invalid"
    )!

    private let baseURL: URL
    private let provider: NetworkProvider<ExampleTarget>

    init(
        baseURL: URL = RemoteService.defaultBaseURL,
        provider: NetworkProvider<ExampleTarget> = NetworkProvider()
    ) {
        self.baseURL = baseURL
        self.provider = provider
    }

    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse {
        let response = try await provider.request(
            .fetch(baseURL: baseURL, request: request)
        )
        return try response.decode(ExampleResponse.self)
    }
}
```

- [ ] **Step 5: Update the composition-test double for the new semantic requirement**

Replace the one-line `InjectedRemoteService` declaration at the bottom of
`AppTemplateTests/App/Composition/AppDependenciesTests.swift` with:

```swift
private actor InjectedRemoteService: IRemoteService {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse {
        ExampleResponse(id: "injected", title: request.query)
    }
}
```

Do not add assertions against this double. It exists only to keep the explicit
dependency-injection tests compiling after the protocol gains real behavior.

- [ ] **Step 6: Run remote-service, composition, and networking tests**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork \
  -only-testing:AppTemplateTests/RemoteServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests
```

Expected: all selected tests pass without warnings. Mutation check: changing
the query key, omitting the page, decoding a different model, or sending the
sample through transport must fail a named `RemoteServiceTests` test.

- [ ] **Step 7: Commit domain-service integration**

```bash
git add \
  AppTemplate/App/Services/Remote \
  AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: connect example remote service"
```

---

### Task 5: Architecture Documentation and Cross-Platform Verification

**Files:**
- Modify: `docs/ARCHITECTURE.md:85-96`
- Modify: `docs/CUSTOMIZATION.md:53-66`

**Interfaces:**
- Consumes: the completed networking layer, example target, app-facing service, synchronized source groups, and existing CI destination matrix.
- Produces: adopter-facing ownership/configuration guidance and evidence that the complete application builds with warnings treated as errors on macOS and generic iOS.

- [ ] **Step 1: Document networking ownership and runtime behavior**

In `docs/ARCHITECTURE.md`, replace the paragraph beginning
`` `AppInfoService` reads display name `` through the end of the
`Dependency injection and services` section with:

```markdown
`AppInfoService` reads display name and short version from the app bundle and
is injected into Settings. `ILocalDatabaseService`/`LocalDatabaseService`
remain an intentionally empty local-storage example.

`IRemoteService` is the app-facing remote boundary. Its neutral
`fetchExample(_:)` operation demonstrates a semantic service method without
exposing targets, URL requests, or response decoding to features.
`RemoteService` is an actor that owns `NetworkProvider<ExampleTarget>` and
decodes the provider's raw response into `ExampleResponse`.

The reusable implementation under `App/Networking` is Moya-inspired but uses
Foundation directly. `NetworkTarget` values describe typed endpoints;
`NetworkRequestBuilder` creates requests; asynchronous `RequestAdapter`s mutate
them in order; `NetworkEventMonitor`s observe lifecycle events in order; and a
replaceable `NetworkTransport` performs I/O. `URLSessionTransport` is live,
while provider-level immediate and delayed sample responses support
deterministic tests. Status codes default to `200..<300`, and status or decoding
errors retain the raw `NetworkResponse`.

The template's live graph deliberately uses `https://example.invalid` because
it has no production backend. No existing feature calls the example operation.
Replace the URL, target, and service contract before product use; inject
feature-specific service slices rather than providers or `AppDependencies`
into ViewModels.
```

- [ ] **Step 2: Document the production adoption checklist**

In `docs/CUSTOMIZATION.md`, replace the first paragraph under
`## 5. Services and features` with:

```markdown
The local database service remains an empty example. The remote service now
demonstrates a URLSession-backed, Moya-inspired target/provider flow with a
reserved `https://example.invalid` base URL; it is not a configured production
API. Before enabling remote product behavior:

1. Replace `ExampleTarget`, `ExampleRequest`, `ExampleResponse`, and
   `fetchExample(_:)` with domain-specific operations and models.
2. Supply the real environment base URL at the composition root; do not leave
   the reserved placeholder or hide configuration in a global singleton.
3. Add actor-safe `RequestAdapter`s for credentials and explicit,
   privacy-reviewed `NetworkEventMonitor`s for diagnostics. Do not log secrets,
   authorization headers, or bodies by default.
4. Define each target's status validation and sample response, then test it
   with an in-memory transport or provider stubbing rather than public network
   access.
5. Expose only semantic methods through feature-scoped service protocols and
   dependency structs. Do not inject `NetworkProvider` or `AppDependencies`
   into a ViewModel.
```

Keep the existing following paragraph beginning `For a new feature` unchanged.
Human-facing prose does not receive source-text tests; verify formatting and
technical consistency through review.

- [ ] **Step 3: Run whitespace and focused static checks**

Run:

```bash
git diff --check
```

Expected: exit 0 with no whitespace errors.

Run:

```bash
rg -n 'import (Alamofire|Moya|Combine|RxSwift|ReactiveSwift)' \
  AppTemplate/App/Networking \
  AppTemplate/App/Services/Remote
```

Expected: exit 1 with no matches, confirming the implementation has no
forbidden networking dependency imports. This is a dependency-boundary check,
not a prose test.

- [ ] **Step 4: Run the complete macOS unit-test target with warnings as errors**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork-Final-macOS \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 0 with all `AppTemplateTests` tests passing and no warnings.

- [ ] **Step 5: Build the complete iOS/iPadOS application target with warnings as errors**

Run:

```bash
xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/AppTemplate-URLSessionNetwork-Final-iOS \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 0. The single iOS application target supports both iPhone and
iPad device families; the repository's CI matrix will additionally run the
unit and UI suites on named iPhone and iPad simulators.

- [ ] **Step 6: Review scope and commit documentation**

Run:

```bash
git status --short
git diff --stat HEAD
```

Expected: Tasks 1–4 are already committed, so the working-tree output contains
only `docs/ARCHITECTURE.md` and `docs/CUSTOMIZATION.md`. Inspect the preceding
commits if needed to confirm that no package dependency, project-file,
unrelated feature, or generated DerivedData change was included.

Commit the documentation:

```bash
git add docs/ARCHITECTURE.md docs/CUSTOMIZATION.md
git commit -m "docs: explain network layer customization"
```

- [ ] **Step 7: Perform the completion verification gate**

Invoke `superpowers:verification-before-completion`, re-run its required fresh
verification commands, and inspect:

```bash
git status --short
git log -5 --oneline
```

Expected: the working tree is clean; the five implementation commits are
present; macOS tests and generic iOS build have fresh successful output. Do not
claim completion from an earlier test run.

---
