# URLSession Network Layer Design

**Date:** 2026-08-05

**Status:** Approved

## Context

AppTemplate currently provides an empty `IRemoteService` protocol and an empty
`RemoteService` actor. The placeholders demonstrate dependency ownership but do
not provide HTTP behavior. The project targets iOS 26, iPadOS 26, and macOS 26,
uses Swift 6 strict concurrency, and does not currently depend on a networking
package.

The new networking layer will preserve Moya's most useful idea—describing API
operations as typed targets and executing them through a provider—while using
`URLSession`, structured concurrency, and Swift 6 `Sendable` boundaries. It is
Moya-inspired, not source-compatible with Moya.

Because the application target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
all networking value types, protocols, protocol extensions, and helper
functions will be declared `nonisolated`. `RemoteService` remains an actor.
This keeps request work off the UI isolation domain and makes concurrency
intent explicit at every networking boundary.

## Goals

- Provide compile-time endpoint definitions through `NetworkTarget` values.
- Build and execute requests with Foundation and `URLSession` only.
- Make async/await and structured cancellation the only asynchronous API.
- Support plain requests, typed query items, JSON bodies, and raw data bodies.
- Validate HTTP status codes before domain decoding.
- Preserve raw response details for diagnostics and server-error handling.
- Support asynchronous request adapters and ordered event monitors.
- Treat immediate and delayed target stubs as first-class behavior.
- Keep application features behind domain-facing service protocols.
- Make all networking components safe to pass across Swift 6 isolation
  boundaries.
- Test request construction and provider behavior without live network traffic.

## Non-goals

- Moya API or source compatibility.
- Alamofire or another third-party networking dependency.
- Callback, Combine, RxSwift, or ReactiveSwift APIs.
- Multipart uploads, file downloads, or progress reporting.
- Automatic retries, token refresh, reachability, caching, or request
  deduplication.
- Certificate pinning or custom URL authentication challenges.
- A production backend configuration for the template.
- Logging request headers or bodies by default.

## Architectural boundary

Feature code will depend on narrow domain service protocols such as
`IRemoteService`; it will not construct targets or call providers directly.
`RemoteService` will own the provider needed for its API and translate between
domain-facing methods and network targets.

The reusable networking implementation will live under
`AppTemplate/App/Networking`. The existing remote service will remain under
`AppTemplate/App/Services/Remote`.

```text
Feature or ViewModel
        |
        v
IRemoteService / RemoteService
        |
        v
NetworkProvider<ExampleTarget>
        |
        +--> NetworkRequestBuilder
        +--> RequestAdapter(s)
        +--> NetworkEventMonitor(s)
        +--> target sample response when stubbing
        `--> NetworkTransport
                `--> URLSessionTransport
```

## Core request model

### `HTTPMethod`

`HTTPMethod` will be a `String`, `Sendable` enum containing the initial methods
`get`, `post`, `put`, `patch`, `delete`, and `head`. The request builder will
write its raw value into `URLRequest.httpMethod`.

### `NetworkBody`

`NetworkBody` will be a `Sendable` enum with two cases:

- `json(any Encodable & Sendable)` for values encoded by the provider's fresh
  `JSONEncoder`;
- `data(Data, contentType: String?)` for already encoded bodies.

The JSON case deliberately requires the payload to be `Sendable`. The provider
will create a new encoder for each request rather than share mutable encoder
state across requests. A provider accepts a `@Sendable () -> JSONEncoder`
factory so an app can consistently configure dates, keys, and other strategies.

### `NetworkTask`

`NetworkTask` will be a `Sendable` value containing:

- `queryItems: [URLQueryItem]`;
- `body: NetworkBody?`.

Static constructors will provide the normal call sites:

- `.plain`;
- `.query(_:)`;
- `.json(_:, queryItems:)`, with an empty query-item default;
- `.data(_:contentType:queryItems:)`, with empty content-type and query-item
  defaults.

This composable value avoids Moya's growing set of composite enum cases while
still making common requests concise. Query parameters remain typed
`URLQueryItem` values; `[String: Any]` is not part of the API.

### `StatusCodeValidation`

`StatusCodeValidation` will be a `Sendable` enum with:

- `.successful`, accepting `200..<300`;
- `.successfulAndRedirects`, accepting `200..<400`;
- `.range(Range<Int>)`;
- `.none`.

Targets default to `.successful`. Validation happens after a complete HTTP
response is formed and before it is returned to the service.

### `NetworkTarget`

`NetworkTarget` will be a `Sendable` protocol with these requirements:

```swift
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
```

Defaults will be empty headers, `.successful` validation, `.plain` task, and a
status-200 empty sample response. A target may be an enum, struct, or other
`Sendable` value. The name intentionally differs from Moya's `TargetType` so
consumers do not assume drop-in compatibility.

## Request construction

`NetworkRequestBuilder` will synchronously turn a target into a `URLRequest`.
It has one responsibility: deterministic request construction.

The builder will:

1. append `path` to `baseURL` using Foundation URL APIs;
2. merge the task's query items through `URLComponents` so names and values are
   percent encoded correctly;
3. set the HTTP method;
4. encode a JSON body with a newly created encoder, or attach raw body data;
5. apply a task-generated content type;
6. apply target headers last so an endpoint can override the generated default.

JSON bodies receive `Content-Type: application/json` unless the target provides
another value. Raw bodies use their optional content type. Header-name matching
for this override is case-insensitive.

The builder does not perform network I/O, apply authentication, validate status
codes, or decode a response.

## Request adaptation and observation

Moya's plugin responsibilities will be separated into two smaller protocols.

### `RequestAdapter`

```swift
nonisolated
protocol RequestAdapter: Sendable {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest
}
```

Adapters run sequentially in registration order. Each adapter receives the
output of the previous adapter. This supports actor-backed credential sources
without blocking or unsafe shared state. An adapter may overwrite headers set
by the target because adaptation is the final request-mutation phase.

### `NetworkEventMonitor`

```swift
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
```

Monitors run sequentially in registration order to keep event ordering
deterministic. They cannot mutate a request or alter a result, and their methods
do not throw. Implementations are expected to return quickly or dispatch their
own expensive work. The layer will not ship a logger that prints headers or
bodies; an adopter may add a redacting monitor explicitly.

`willSend` occurs after the request is built and adapted, immediately before a
live or stubbed operation starts. Once `willSend` has occurred, exactly one
`didComplete` event occurs, including cancellation, transport failure, non-HTTP
responses, and rejected status codes. Construction or adaptation failures occur
before `willSend` and therefore emit neither event.

## Transport

`NetworkTransport` is the only interface that performs external I/O:

```swift
nonisolated
protocol NetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
```

`URLSessionTransport` implements the protocol with
`URLSession.data(for:delegate:)`. Its initializer accepts a `URLSession`, and
the live default uses `.shared`. URLSession cancellation remains linked to the
calling Swift task.

Tests will use a small in-memory transport that records requests and returns a
configured response or throws a configured error. Production code will not
depend on `URLProtocol` interception.

## Stubbing

Each target supplies a `StubResponse` containing a status code, data, and
headers. A provider accepts a target-specific, sendable closure that returns:

- `.never`;
- `.immediate`;
- `.delayed(Duration)`.

The live default is `.never`. Immediate and delayed stubs still run through
adapters, monitor notifications, `NetworkResponse` creation, and status
validation. They bypass only `NetworkTransport`.

The provider accepts a sendable sleep closure with a production default based
on `Task.sleep(for:)`. Tests replace the closure to verify delayed behavior
without wall-clock waiting. Cancellation while waiting for a delayed stub maps
to `NetworkError.cancelled` and produces the matching `didComplete` event.

## Provider and data flow

`NetworkProvider<Target: NetworkTarget>` will be a `Sendable` value initialized
with a transport, adapters, monitors, JSON encoder factory, stub-behavior
closure, and sleep closure. Its public operation is:

```swift
func request(_ target: Target) async throws -> NetworkResponse
```

A request follows this order:

1. Build the `URLRequest`.
2. Apply each adapter in registration order.
3. Notify every monitor with `willSend`.
4. Resolve the configured stub behavior.
5. Return sample data after any configured stub delay, or call the transport.
6. Convert the result into `NetworkResponse`; reject non-HTTP responses.
7. Validate the status code according to the target.
8. Notify every monitor once with `didComplete`.
9. Return the response or throw the same `NetworkError` seen by monitors.

The provider does not decode domain types. This keeps raw server responses
available and prevents the generic provider from coupling a target to an
unrelated inferred response type.

## Responses and decoding

`NetworkResponse` will be a `Sendable` value with:

- the final `URLRequest`;
- response URL;
- integer status code;
- string HTTP headers;
- raw `Data`.

It will expose:

```swift
func decode<Value: Decodable>(
    _ type: Value.Type,
    using decoder: JSONDecoder = JSONDecoder()
) throws -> Value
```

Decoding failures become `NetworkError.decoding` and retain the complete
`NetworkResponse`. Decoding happens synchronously in the calling service. A
domain value returned across an actor or `Sendable` protocol boundary must
itself meet Swift's isolation requirements.

Empty-body success is represented by inspecting `NetworkResponse` directly;
the initial scope will not introduce a synthetic `EmptyResponse` model.

## Errors

`NetworkError` will conform to `Error` and contain these cases:

```swift
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

Construction errors describe an unusable URL after path or query composition.
JSON encoding and adapter failures retain their underlying errors. A thrown
`CancellationError` or `URLError.cancelled` maps to `.cancelled`; other session
errors map to `.transport`. A status error retains the response body so a
domain service may decode a server-defined error document.

After `willSend`, provider failures are normalized once and the same normalized
value is sent to monitors and thrown to the caller. Construction and adaptation
failures are normalized and thrown before monitoring begins. Monitor callbacks
cannot replace errors.

## App-facing example service

The existing neutral `ExampleRequest` and `ExampleResponse` models will provide
one end-to-end example without being used by a screen.

`ExampleTarget` will define a search request with an injected base URL, a
`/examples` path, GET method, and `query` and `page` URL query items. It will
provide a small JSON `sampleResponse` matching `ExampleResponse`.

`IRemoteService` will gain one semantic requirement:

```swift
func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse
```

`RemoteService` will own `NetworkProvider<ExampleTarget>` and a base URL. The
method will request the target and decode `ExampleResponse`. The default live
composition will use the reserved `https://example.invalid` host, making the
template's unconfigured backend explicit and preventing accidental traffic to
a real service. No existing feature will call the example operation.

Tests and adopters can inject another base URL and provider. Production adopters
must replace the placeholder URL and example operation with their backend and
domain-specific service contracts.

## File organization

Production files will be grouped by responsibility:

```text
AppTemplate/App/Networking/
├── Core/
│   ├── HTTPMethod.swift
│   ├── NetworkBody.swift
│   ├── NetworkTarget.swift
│   ├── NetworkTask.swift
│   └── StatusCodeValidation.swift
├── Pipeline/
│   ├── NetworkEventMonitor.swift
│   └── RequestAdapter.swift
├── RequestBuilding/
│   └── NetworkRequestBuilder.swift
├── Response/
│   ├── NetworkError.swift
│   └── NetworkResponse.swift
├── Stubbing/
│   ├── StubBehavior.swift
│   └── StubResponse.swift
├── Transport/
│   ├── NetworkTransport.swift
│   └── URLSessionTransport.swift
└── NetworkProvider.swift

AppTemplate/App/Services/Remote/
├── ExampleTarget.swift
├── IRemoteService.swift
└── RemoteService.swift
```

Tests will mirror these ownership boundaries under
`AppTemplateTests/App/Networking` and `AppTemplateTests/App/Services/Remote`.
Reusable spies and in-memory transports will live in
`AppTemplateTests/TestSupport/Networking` rather than production code.

## Testing strategy

All new behavior will be developed test-first with Swift Testing.

`NetworkRequestBuilderTests` will verify:

- normalized base URL and path joining;
- preservation and percent encoding of query items;
- each HTTP method;
- JSON and raw body construction;
- generated content types, case-insensitive target overrides, and custom
  headers;
- request-construction and JSON-encoding failures.

`NetworkProviderTests` will verify:

- transport success and complete `NetworkResponse` mapping;
- sequential adapter composition;
- ordered `willSend` and `didComplete` monitor events;
- immediate stubs bypass transport;
- delayed stubs call the injected sleep closure and bypass transport;
- successful, redirect, custom-range, and disabled validation;
- transport, cancellation, non-HTTP, rejected-status, construction, and
  adaptation errors;
- the terminal monitor event observes the same normalized result returned or
  thrown by the provider.

`NetworkResponseTests` will verify successful model decoding and decoding errors
that retain the original response.

`RemoteServiceTests` will use a stubbed provider to prove the complete
`ExampleRequest` to `ExampleTarget` to `ExampleResponse` flow. Composition tests
will continue to prove that live, preview, UI-test, and explicit test factories
provide the intended service instances.

No unit test will depend on public internet access or elapsed wall-clock delay.

## Documentation changes

The architecture guide will replace the description of the empty remote-service
placeholder with the new provider, transport, service boundary, and placeholder
base-URL behavior. The customization guide will tell adopters to replace the
example target, domain operation, placeholder base URL, adapters, and monitoring
policy before using networking in production.

## Success criteria

- The project builds with Swift 6 for iOS, iPadOS, and macOS targets.
- The networking implementation imports only Foundation.
- A target can produce a correctly encoded `URLRequest` for every in-scope task.
- `NetworkProvider` can execute through `URLSession` or return deterministic
  target samples without changing consumer code.
- Cancellation, transport failures, invalid responses, rejected statuses, and
  decoding failures remain distinguishable.
- Adapters and monitors are asynchronous, ordered, and `Sendable`.
- App-facing code uses `IRemoteService.fetchExample` rather than constructing a
  target or provider.
- The full unit-test suite passes without live network traffic.
