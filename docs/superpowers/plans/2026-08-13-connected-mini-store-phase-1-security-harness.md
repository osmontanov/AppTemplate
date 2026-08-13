# Connected Mini Store — Phase 1: Security and Deterministic Harness

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Goal

Establish injected time, cookie-free credential transport, allowlisted diagnostics, typed DummyJSON operations, constrained image loading, and a fail-closed UI-test harness.

## Architecture

NetworkProvider receives AppClock and an optional diagnostic recorder. Authentication uses a dedicated ephemeral URLSession. RemoteService owns DummyJSON mapping while existing Example remote fixtures remain compiled. Product images flow only through IImageLoader. Typed UITestScenario values construct fresh in-memory graphs and an ordered scripted transport.

## Tech Stack

Swift 6, Swift Testing, SwiftUI, Foundation, ImageIO, Observation, Xcode 26, iOS/macOS 26.

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- Follow RED → GREEN → focused regression; each task leaves the project compiling. Tests never contact the public host.
- Network timeout is 15 seconds. NetworkProvider never retries automatically.
- Diagnostics never retain/render raw request, target, response, Error, header values, credentials, Keychain bytes, or response bytes.
- Auth sessions disable cookies, credential storage, URL cache, and cross-origin credential forwarding.
- Images require HTTPS, final host dummyjson.com/cdn.dummyjson.com, valid MIME/signature, ≤5 MiB, ≤4096×4096.
- Malformed --ui-testing input fails closed.
- Do not edit AppTemplate.xcodeproj/project.pbxproj or AppTemplate/Resources/Localizable.xcstrings; do not stage the design spec, graphify-out/, or unrelated changes.

## Task 1: Inject time and isolate credential transport

**Create:** `AppTemplate/App/Utilities/Time/AppClock.swift`, `AppTemplate/App/Networking/Transport/CookieFreeURLSessionConfiguration.swift`, `AppTemplate/App/Networking/Transport/CredentialRedirectPolicy.swift`, `AppTemplateTests/App/Utilities/Time/AppClockTests.swift`, `AppTemplateTests/App/Networking/CookieFreeURLSessionConfigurationTests.swift`, `AppTemplateTests/App/Networking/EphemeralURLSessionConfigurationTests.swift`, `AppTemplateTests/App/Networking/CredentialRedirectPolicyTests.swift`.

**Modify:** `AppTemplate/App/Networking/NetworkProvider.swift`, `AppTemplate/App/Networking/Core/NetworkTarget.swift`, `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift`, `AppTemplate/App/Networking/Transport/URLSessionTransport.swift`, `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`, `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift`.

**Test:** `AppTemplateTests/App/Utilities/Time/AppClockTests.swift`, `AppTemplateTests/App/Networking/CookieFreeURLSessionConfigurationTests.swift`, `AppTemplateTests/App/Networking/EphemeralURLSessionConfigurationTests.swift`, `AppTemplateTests/App/Networking/CredentialRedirectPolicyTests.swift`.

**Consumes / Produces**

~~~swift
nonisolated struct AppClock: Sendable {
    let now: @Sendable () -> Date
    let monotonicNow: @Sendable () -> ContinuousClock.Instant
    let sleep: @Sendable (Duration) async throws -> Void
    static let live: AppClock
}
nonisolated enum CookieFreeURLSessionConfiguration {
    static func make(timeout: TimeInterval = 15, protocolClasses: [AnyClass]? = nil) -> URLSessionConfiguration
}
nonisolated enum EphemeralURLSessionConfiguration {
    static func make(timeout: TimeInterval = 15, protocolClasses: [AnyClass]? = nil) -> URLSessionConfiguration
}
nonisolated struct CredentialRedirectPolicy: Sendable {
    func prepare(_ request: URLRequest) -> URLRequest
    func redirectedRequest(_ proposed: URLRequest, from originalURL: URL?) -> URLRequest?
}
extension URLSessionTransport {
    static func cookieFree(timeout: TimeInterval = 15) -> URLSessionTransport
    static func ephemeral(timeout: TimeInterval = 15) -> URLSessionTransport
}
protocol NetworkTarget: Sendable {
    var shouldHandleCookies: Bool { get }
}
extension NetworkTarget {
    var shouldHandleCookies: Bool { true }
}
init(
    transport: any NetworkTransport = URLSessionTransport(),
    adapters: [any RequestAdapter] = [],
    monitors: [any NetworkEventMonitor] = [],
    jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = { JSONEncoder() },
    stubBehavior: @escaping @Sendable (Target) -> StubBehavior = { _ in .never },
    clock: AppClock = .live
)
~~~

- [ ] **RED:** Add deterministic sleep and isolation tests. For both configuration factories assert request/resource timeout exactly 15 seconds, ephemeral cache policy, and no URL cache/cookie/credential stores; auth additionally cannot handle cookies. Cover default-port normalization, same-origin Authorization/body preservation, cross-origin host/port/scheme rejection, HTTPS downgrade rejection, nil original URL rejection, cookie/proxy-header removal, and a 307 integration fixture proving a login/refresh body never reaches another origin.

~~~swift
private actor SleepCounter {
    private var count = 0
    func increment() { count += 1 }
    func read() -> Int { count }
}
@Test func delayedStubUsesClock() async throws {
    let counter = SleepCounter()
    let clock = AppClock(
        now: { Date(timeIntervalSince1970: 42) },
        monotonicNow: { ContinuousClock().now },
        sleep: { _ in await counter.increment() }
    )
    _ = try await NetworkProvider<TestTarget>(
        stubBehavior: { _ in .delayed(.seconds(9)) },
        clock: clock
    ).request(.success)
    #expect(await counter.read() == 1)
}
@Test func credentialConfigurationHasNoAmbientState() {
    let value = CookieFreeURLSessionConfiguration.make()
    #expect(value.httpShouldSetCookies == false)
    #expect(value.httpCookieStorage == nil)
    #expect(value.urlCredentialStorage == nil)
    #expect(value.urlCache == nil)
}
~~~

- [ ] Run RED; expect missing AppClock/configuration/policy and clock/shouldHandleCookies arguments.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppClockTests -only-testing:AppTemplateTests/CookieFreeURLSessionConfigurationTests -only-testing:AppTemplateTests/EphemeralURLSessionConfigurationTests -only-testing:AppTemplateTests/CredentialRedirectPolicyTests
~~~

- [ ] **GREEN:** Replace provider sleep with clock.sleep; set request.httpShouldHandleCookies from the target in the builder, then reapply a false value and remove any explicit Cookie header after all adapters so an adapter cannot weaken an auth target. Both factories use `URLSessionConfiguration.ephemeral`, set `timeoutIntervalForRequest` and `timeoutIntervalForResource` to 15, and nil every persistent store; the cookie-free variant also disables cookie handling and installs the private retained redirect delegate. `CredentialRedirectPolicy.prepare` always sets `httpShouldHandleCookies = false` and removes Cookie/Proxy-Authorization. A redirect is allowed only when original and proposed URLs have the same lowercased scheme/host and normalized effective port (80 for HTTP, 443 for HTTPS); same-origin retains Authorization and body. Missing original URL, a different host/port/scheme, or an HTTPS downgrade returns nil, so no 307/308 redirect can replay a password, bearer token, refresh token, or body to another origin.

~~~swift
static let live = AppClock(
    now: Date.init,
    monotonicNow: { ContinuousClock().now },
    sleep: { try await Task.sleep(for: $0) }
)
~~~

- [ ] Run PASS.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppClockTests -only-testing:AppTemplateTests/CookieFreeURLSessionConfigurationTests -only-testing:AppTemplateTests/EphemeralURLSessionConfigurationTests -only-testing:AppTemplateTests/CredentialRedirectPolicyTests -only-testing:AppTemplateTests/NetworkProviderStubTests -only-testing:AppTemplateTests/NetworkRequestBuilderTests
~~~

- [ ] Commit.

~~~bash
git add AppTemplate/App/Utilities/Time/AppClock.swift AppTemplate/App/Networking/Transport/CookieFreeURLSessionConfiguration.swift AppTemplate/App/Networking/Transport/CredentialRedirectPolicy.swift AppTemplate/App/Networking/NetworkProvider.swift AppTemplate/App/Networking/Core/NetworkTarget.swift AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift AppTemplate/App/Networking/Transport/URLSessionTransport.swift AppTemplateTests/App/Utilities/Time/AppClockTests.swift AppTemplateTests/App/Networking/CookieFreeURLSessionConfigurationTests.swift AppTemplateTests/App/Networking/EphemeralURLSessionConfigurationTests.swift AppTemplateTests/App/Networking/CredentialRedirectPolicyTests.swift AppTemplateTests/App/Networking/NetworkProviderStubTests.swift AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift
git commit -m "feat: isolate credential transport"
~~~

## Task 2: Add allowlisted diagnostics and DummyJSON side-by-side

**Create:** `AppTemplate/App/Networking/Diagnostics/NetworkDiagnosticEvent.swift`, `AppTemplate/App/Networking/Diagnostics/NetworkDiagnosticRecorder.swift`, `AppTemplate/App/Models/Remote/ProductDTO.swift`, `AppTemplate/App/Models/Remote/ProductPageDTO.swift`, `AppTemplate/App/Models/Remote/ProductCategoryDTO.swift`, `AppTemplate/App/Models/Remote/ProductPageRequest.swift`, `AppTemplate/App/Models/Remote/AuthDTOs.swift`, `AppTemplate/App/Models/Remote/HTTPDiagnosticDTOs.swift`, `AppTemplate/App/Services/Remote/DummyJSONTarget.swift`, `AppTemplate/App/Services/Remote/RemoteServiceError.swift`, `AppTemplateTests/App/Networking/NetworkDiagnosticRedactionTests.swift`, `AppTemplateTests/App/Services/Remote/DummyJSONTargetTests.swift`, `AppTemplateTests/App/Services/Remote/DummyJSONRemoteServiceTests.swift`.

**Type ownership:** `NetworkDiagnosticEvent.swift` defines `NetworkDiagnosticDescriptor`, `NetworkDiagnosticFailure`, `NetworkDiagnosticSummary`, and `NetworkDiagnosticEvent`; `NetworkDiagnosticRecorder.swift` defines the actor. `RemoteServiceError.swift` defines only `RemoteServiceError`. `ProductPageRequest.swift` owns canonical `ProductQueryMode`, `ProductSort`, and `ProductPageRequest`. `AuthDTOs.swift` owns all authentication DTOs; `HTTPDiagnosticDTOs.swift` owns `HTTPDiagnosticRequest` and `HTTPDiagnosticDTO`.

**Modify:** `AppTemplate/App/Networking/Core/NetworkTarget.swift`, `AppTemplate/App/Networking/NetworkProvider.swift`, `AppTemplate/App/Networking/Response/NetworkResponse.swift`, `AppTemplate/App/Services/Remote/IRemoteService.swift`, `AppTemplate/App/Services/Remote/RemoteService.swift`, `AppTemplate/App/AppDependencies/AppDependencies.swift`, `AppTemplateTests/App/Composition/AppDependenciesTests.swift`, `AppTemplateTests/App/Networking/NetworkResponseTests.swift`, `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift`.

**Test:** `AppTemplateTests/App/Networking/NetworkDiagnosticRedactionTests.swift`, `AppTemplateTests/App/Networking/NetworkResponseTests.swift`, `AppTemplateTests/App/Services/Remote/DummyJSONTargetTests.swift`, `AppTemplateTests/App/Services/Remote/DummyJSONRemoteServiceTests.swift`.

**Consumes / Produces**

~~~swift
nonisolated struct NetworkDiagnosticDescriptor: Equatable, Sendable {
    let operation: String
    let safePath: String
    let queryKeys: [String]
}
nonisolated struct NetworkDiagnosticEvent: Equatable, Sendable {
    let operationID: UUID
    let operation: String
    let method: HTTPMethod
    let safePath: String
    let queryKeys: [String]
    let statusClass: Int?
    let elapsed: Duration
    let failure: NetworkDiagnosticFailure?
    let summary: NetworkDiagnosticSummary?
}
nonisolated enum NetworkDiagnosticFailure: Equatable, Sendable {
    case cancelled, transport, invalidResponse
    case statusClass(Int)
}
nonisolated enum NetworkDiagnosticSummary: Equatable, Sendable {
    case productPage(count: Int, total: Int)
    case product(id: Int)
    case categories(count: Int)
    case profile(id: Int)
    case tokenRefresh
    case http(status: Int)
}
actor NetworkDiagnosticRecorder {
    init(capacity: Int = 100)
    func record(_ event: NetworkDiagnosticEvent)
    func annotate(operationID: UUID, summary: NetworkDiagnosticSummary)
    func events() -> [NetworkDiagnosticEvent]
    func clear()
}
nonisolated protocol NetworkTarget: Sendable {
    var baseURL: URL { get }; var path: String { get }; var method: HTTPMethod { get }
    var task: NetworkTask { get }; var headers: HTTPHeaders { get }
    var validation: StatusCodeValidation { get }; var sampleResponse: StubResponse { get }
    var shouldHandleCookies: Bool { get }
    var diagnosticDescriptor: NetworkDiagnosticDescriptor? { get }
}
nonisolated extension NetworkTarget {
    var shouldHandleCookies: Bool { true }
    var diagnosticDescriptor: NetworkDiagnosticDescriptor? { nil }
}
nonisolated struct NetworkResponse: Sendable {
    let operationID: UUID; let request: URLRequest; let url: URL?
    let statusCode: Int; let headers: HTTPHeaders; let data: Data
    func decode<Value: Decodable>(
        _ type: Value.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value
}
init(
    transport: any NetworkTransport = URLSessionTransport(),
    adapters: [any RequestAdapter] = [],
    monitors: [any NetworkEventMonitor] = [],
    jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = { JSONEncoder() },
    stubBehavior: @escaping @Sendable (Target) -> StubBehavior = { _ in .never },
    clock: AppClock = .live,
    diagnosticRecorder: NetworkDiagnosticRecorder? = nil
)
nonisolated enum ProductQueryMode: Equatable, Sendable {
    case all
    case search(String)
    case category(String)
}
nonisolated enum ProductSort: String, CaseIterable, Codable, Equatable, Sendable {
    case titleAscending
    case titleDescending
    case priceAscending
    case priceDescending
}
nonisolated struct ProductPageRequest: Equatable, Sendable {
    let mode: ProductQueryMode
    let sort: ProductSort?
    let limit: Int
    let skip: Int
}
nonisolated struct ProductReviewDTO: Codable, Equatable, Sendable {
    let rating: Int; let comment: String; let date: Date; let reviewerName: String
}
nonisolated struct ProductDTO: Codable, Equatable, Sendable {
    let id: Int; let title: String; let description: String; let category: String
    let price: Decimal; let rating: Double; let stock: Int; let brand: String?
    let availabilityStatus: String?; let reviews: [ProductReviewDTO]
    let images: [URL]; let thumbnail: URL?
}
nonisolated struct ProductPageDTO: Codable, Equatable, Sendable {
    let products: [ProductDTO]; let total: Int; let skip: Int; let limit: Int
}
nonisolated struct ProductCategoryDTO: Codable, Equatable, Sendable {
    let slug: String; let name: String; let url: URL
}
nonisolated struct LoginRequestDTO: Codable, Equatable, Sendable {
    let username: String; let password: String; let expiresInMins: Int
}
nonisolated struct UserProfileDTO: Codable, Equatable, Sendable {
    let id: Int; let username: String; let firstName: String; let lastName: String
    let email: String; let image: URL?
}
nonisolated struct AuthSessionDTO: Codable, Equatable, Sendable {
    let id: Int; let username: String; let firstName: String; let lastName: String
    let email: String; let image: URL?; let accessToken: String; let refreshToken: String
}
nonisolated struct RefreshRequestDTO: Codable, Equatable, Sendable {
    let refreshToken: String; let expiresInMins: Int
}
nonisolated struct AuthTokensDTO: Codable, Equatable, Sendable {
    let accessToken: String; let refreshToken: String
}
nonisolated struct AuthErrorDTO: Codable, Equatable, Sendable { let message: String }
nonisolated enum HTTPDiagnosticRequest: Equatable, Sendable {
    case delay(milliseconds: Int); case status(code: Int)
}
nonisolated struct HTTPDiagnosticDTO: Equatable, Sendable { let statusCode: Int }
nonisolated enum RemoteServiceError: Error, Equatable, Sendable {
    case cancelled, transport
    case status(code: Int, authenticationError: AuthErrorDTO?)
    case invalidResponse
}
nonisolated protocol IRemoteService: Sendable {
    func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO
    func categories() async throws -> [ProductCategoryDTO]
    func product(id: Int) async throws -> ProductDTO
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO
    func me(accessToken: String) async throws -> UserProfileDTO
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO
}
nonisolated enum DummyJSONTarget: NetworkTarget {
    case products(baseURL: URL, ProductPageRequest)
    case categories(baseURL: URL)
    case product(baseURL: URL, id: Int)
    case login(baseURL: URL, LoginRequestDTO)
    case me(baseURL: URL, accessToken: String)
    case refresh(baseURL: URL, RefreshRequestDTO)
    case diagnostic(baseURL: URL, HTTPDiagnosticRequest)
}
actor RemoteService: IRemoteService {
    nonisolated static let defaultBaseURL: URL
    nonisolated static let defaultDummyJSONBaseURL: URL
    init(
        baseURL: URL = RemoteService.defaultBaseURL,
        provider: NetworkProvider<ExampleTarget> = NetworkProvider(),
        dummyJSONBaseURL: URL = RemoteService.defaultDummyJSONBaseURL,
        dummyJSONProvider: NetworkProvider<DummyJSONTarget>? = nil,
        authenticationProvider: NetworkProvider<DummyJSONTarget>? = nil,
        diagnosticRecorder: NetworkDiagnosticRecorder? = nil
    )
}
~~~

- [ ] **RED:** Cover target paths/samples/cookie flags, all-mode `/products`, `/products/search`, `/products/category/<slug>`, object-valued `/products/categories`, `/auth/login`, `/auth/me`, `/auth/refresh`, `/products?delay=<milliseconds>`, and `/http/<status>`. Freeze delay validation to DummyJSON's documented `0...5000` milliseconds, supported HTTP diagnostic codes to `100...599`, list/search/category paging query names, and `sortBy`/`order` mapping. Place sentinel secrets in URL value, header, login body, target, success bytes, error bytes, and nested Error; none may appear in the DTO or rendered description. Composition tests prove live uses the bounded ephemeral public/auth providers, while preview/UI-test/test factories require injected scripted/fail-closed `IRemoteService` and never evaluate `RemoteService()` as a default argument.

Before any target/provider call, test the injected DummyJSON base origin against one exact trusted rule: HTTPS, lowercase-normalized host exactly `dummyjson.com`, effective port 443, empty user/password/query/fragment, and root path only. HTTP, suffix hosts, IPs, non-443 ports, userinfo, query, fragment, and non-root base paths fail with `.invalidResponse`; transport receives zero calls, so login passwords and bearer/refresh tokens cannot be sent to an injected foreign initial origin.

~~~swift
@Test func diagnosticsCannotContainSentinels() async throws {
    let secrets = ["url-secret", "header-secret", "password-secret", "body-secret"]
    let rendered = try await makeRenderedDiagnosticWithSentinels(secrets)
    for secret in secrets { #expect(rendered.contains(secret) == false) }
}
~~~

- [ ] Run RED; expect missing diagnostics, DTOs, targets, and service methods.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/NetworkDiagnosticRedactionTests -only-testing:AppTemplateTests/DummyJSONTargetTests -only-testing:AppTemplateTests/DummyJSONRemoteServiceTests
~~~

- [ ] **GREEN:** Build diagnostics only from constant descriptors, query-key names, typed summary/failure, status class, and monotonic timestamps. Validate the normalized initial DummyJSON origin in `RemoteService` before constructing every target; authentication never relies on redirect policy as its first-origin trust check. Add list/search/category/detail/category-objects/login/me/refresh/delay/status targets at https://dummyjson.com; use `/products/categories` for `ProductCategoryDTO`, not the string-only `/products/category-list`. Delay maps milliseconds to DummyJSON's `delay` query item on `/products`; status maps to `/http/<code>`. Auth targets disable cookies and use `expiresInMins = 30`. Decode review dates with JSONDecoder.dateDecodingStrategy = .iso8601. Map underlying failures to safe RemoteServiceError.

~~~swift
func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
    let response = try await requestMapped(.products(request))
    let value = try response.decode(ProductPageDTO.self)
    await recorder?.annotate(
        operationID: response.operationID,
        summary: .productPage(count: value.products.count, total: value.total)
    )
    return value
}
~~~

Keep ExampleRequest.swift, ExampleResponse.swift, ExampleTarget.swift and fetchExample physically available through Phase 8. The constructor retains existing baseURL/provider labels. Inside its actor initializer, a nil public override becomes `NetworkProvider(transport: .ephemeral(timeout: 15), diagnosticRecorder: diagnosticRecorder)` and a nil auth override becomes `NetworkProvider(transport: .cookieFree(timeout: 15), diagnosticRecorder: diagnosticRecorder)`; login/me/refresh use only the latter. Both live DummyJSON providers therefore receive the fixed request/resource timeout and neither falls back to a default/shared session. `AppDependencies.live` is the only factory allowed to construct that live `RemoteService`; make `remoteService` explicit in preview/test factories, and build the UI-test factory only from the parsed `UITestScenario` scripted transport so no `RemoteService()` default expression can execute before fail-closed composition. `AppDependencies` gains one app-scoped `let diagnostics: NetworkDiagnosticRecorder`, injects that exact actor into its `RemoteService`, and later exposes the same actor to Services; live, preview, test, and fail-closed UI-testing graphs never create a second recorder. Tests and fail-closed composition that pass provider overrides construct both with the same recorder instance and assert base event plus summary share one operation ID. This avoids a default provider silently missing the recorder. Update the injected IRemoteService conformer in AppDependenciesTests and existing RemoteServiceTests in the same task.

- [ ] Run PASS.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/NetworkDiagnosticRedactionTests -only-testing:AppTemplateTests/DummyJSONTargetTests -only-testing:AppTemplateTests/DummyJSONRemoteServiceTests -only-testing:AppTemplateTests/RemoteServiceTests -only-testing:AppTemplateTests/NetworkResponseTests
~~~

- [ ] Commit.

~~~bash
git add AppTemplate/App/Networking/Diagnostics AppTemplate/App/Networking/Core/NetworkTarget.swift AppTemplate/App/Networking/NetworkProvider.swift AppTemplate/App/Networking/Response/NetworkResponse.swift AppTemplate/App/Models/Remote/ProductDTO.swift AppTemplate/App/Models/Remote/ProductPageDTO.swift AppTemplate/App/Models/Remote/ProductCategoryDTO.swift AppTemplate/App/Models/Remote/ProductPageRequest.swift AppTemplate/App/Models/Remote/AuthDTOs.swift AppTemplate/App/Models/Remote/HTTPDiagnosticDTOs.swift AppTemplate/App/Services/Remote/DummyJSONTarget.swift AppTemplate/App/Services/Remote/RemoteServiceError.swift AppTemplate/App/Services/Remote/IRemoteService.swift AppTemplate/App/Services/Remote/RemoteService.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/App/Networking/NetworkResponseTests.swift AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift AppTemplateTests/App/Networking/NetworkDiagnosticRedactionTests.swift AppTemplateTests/App/Services/Remote/DummyJSONTargetTests.swift AppTemplateTests/App/Services/Remote/DummyJSONRemoteServiceTests.swift
git commit -m "feat: add safe dummyjson diagnostics"
~~~

## Task 3: Enforce product image policy

**Create:** `AppTemplate/App/Services/Images/IImageLoader.swift`, `AppTemplate/App/Services/Images/ImageLoadPolicy.swift`, `AppTemplate/App/Services/Images/LoadedImage.swift`, `AppTemplate/App/Services/Images/ImageLoaderError.swift`, `AppTemplate/App/Services/Images/ImageHTTPTransport.swift`, `AppTemplate/App/Services/Images/URLSessionImageHTTPTransport.swift`, `AppTemplate/App/Services/Images/ProductImageLoader.swift`, `AppTemplate/App/UI/Components/RemoteProductImage.swift`, `AppTemplateTests/App/Services/Images/URLSessionImageHTTPTransportTests.swift`, `AppTemplateTests/App/Services/Images/ProductImageLoaderTests.swift`.

**Type ownership:** `IImageLoader.swift` defines only the public protocol, `ImageLoadPolicy.swift` defines `ImageLoadPolicy`, `LoadedImage.swift` defines `LoadedImage`, and `ImageLoaderError.swift` defines `ImageLoaderError`. `ImageHTTPTransport.swift` defines the feature-internal `ImageHTTPResponse` and `IImageHTTPTransport`; only `URLSessionImageHTTPTransport` touches URLSession redirects/bytes.

**Modify:** `AppTemplate/App/AppDependencies/AppDependencies.swift`, `AppTemplateTests/App/Composition/AppDependenciesTests.swift`.

**Test:** `AppTemplateTests/App/Services/Images/URLSessionImageHTTPTransportTests.swift`, `AppTemplateTests/App/Services/Images/ProductImageLoaderTests.swift`.

**Consumes / Produces**

~~~swift
nonisolated struct ImageLoadPolicy: Equatable, Sendable {
    let allowedHosts: Set<String>
    let timeout: Duration
    let maximumEncodedBytes: Int
    let maximumPixelWidth: Int
    let maximumPixelHeight: Int
    static let product: ImageLoadPolicy
}
nonisolated struct LoadedImage: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}
nonisolated enum ImageLoaderError: Error, Equatable, Sendable {
    case invalidURL, disallowedOrigin, invalidStatus, invalidMIMEType
    case invalidSignature, responseTooLarge, dimensionsTooLarge
    case timedOut, cancelled, transport
}
nonisolated protocol IImageLoader: Sendable {
    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage
}
nonisolated struct ImageHTTPResponse: Sendable {
    let finalURL: URL
    let statusCode: Int
    let mimeType: String?
    let data: Data
}
nonisolated protocol IImageHTTPTransport: Sendable {
    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse
}
nonisolated struct URLSessionImageHTTPTransport: IImageHTTPTransport {
    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse
}
// ProductImageLoader initializer:
init(transport: any IImageHTTPTransport = URLSessionImageHTTPTransport(), clock: AppClock = .live)
~~~

- [ ] **RED:** In transport integration tests, use URLProtocol plus a redirect delegate fixture to prove HTTPS/default-port/exact-host validation occurs before the first request and before every redirect; disallow userinfo, fragments, non-443 ports, host suffixes, cross-origin final responses, and HTTPS downgrade. Prove declared Content-Length >5 MiB rejects before iteration, chunked/lying responses stop and cancel as soon as collected bytes would exceed 5 MiB, timeout cancels the task, and cancellation leaves no retained session/task. In loader tests, cover normalized MIME with parameters, MIME/signature agreement, ImageIO dimensions, cancellation, and valid PNG/JPEG/GIF/WebP fixtures.

~~~swift
@Test func rejectsOriginBeforeTransport() async {
    let transport = CountingImageTransport()
    await #expect(throws: ImageLoaderError.disallowedOrigin) {
        try await ProductImageLoader(transport: transport).load(
            URL(string: "https://evil.example/x.png")!,
            policy: .product
        )
    }
    #expect(await transport.callCount == 0)
}
~~~

- [ ] Run RED; expect missing transport/loader/policy/result/error types.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/URLSessionImageHTTPTransportTests -only-testing:AppTemplateTests/ProductImageLoaderTests
~~~

- [ ] **GREEN:** `URLSessionImageHTTPTransport` creates a per-operation ephemeral session with no cache/cookie/credential stores and a retained task delegate. Validate the initial URL, allow only exact lowercased hosts with HTTPS effective port 443, and return nil for any disallowed redirect before it is followed. Validate HTTP status/final origin and expected content length before consuming bytes; accumulate through delegate/async chunks with a checked `maximumEncodedBytes + 1` ceiling and cancel immediately on overflow. The injected clock races a cancellation-cooperative transport against `policy.timeout`; tests prove both live and scripted transports terminate after cancellation. Only then does `ProductImageLoader` validate MIME/signature/ImageIO dimensions and create `LoadedImage`. `AppDependencies` gains one `let imageLoader: any IImageLoader` for live and deterministic graphs; Store receives that exact instance. `RemoteProductImage` renders only that validated payload and never uses AsyncImage, URLSession.shared, or a global cache.

~~~swift
static let product = ImageLoadPolicy(
    allowedHosts: ["dummyjson.com", "cdn.dummyjson.com"],
    timeout: .seconds(15),
    maximumEncodedBytes: 5 * 1_024 * 1_024,
    maximumPixelWidth: 4_096,
    maximumPixelHeight: 4_096
)
~~~

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/URLSessionImageHTTPTransportTests -only-testing:AppTemplateTests/ProductImageLoaderTests -only-testing:AppTemplateTests/AppDependenciesTests
git add AppTemplate/App/Services/Images AppTemplate/App/UI/Components/RemoteProductImage.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplateTests/App/Services/Images/URLSessionImageHTTPTransportTests.swift AppTemplateTests/App/Services/Images/ProductImageLoaderTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: add constrained image loader"
~~~

## Task 4: Build typed, isolated, fail-closed UI scenarios

**Create:** `AppTemplate/App/Entry/UITesting/UITestScenario.swift`, `AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift`, `AppTemplate/App/Entry/UITesting/ScriptedNetworkStep.swift`, `AppTemplate/App/Entry/UITesting/ScriptedNetworkTransport.swift`, `AppTemplate/App/Entry/UITesting/ScriptedImageLoader.swift`, `AppTemplate/App/Entry/UITesting/UITestScriptConsumptionTracker.swift`, `AppTemplate/App/Entry/UITesting/InvalidUITestDependencies.swift`, `AppTemplateTests/App/Entry/UITestScenarioTests.swift`, `AppTemplateTests/App/Entry/ScriptedNetworkTransportTests.swift`, `AppTemplateTests/App/Entry/ScriptedImageLoaderTests.swift`, `AppTemplateTests/App/Entry/UITestScriptConsumptionTrackerTests.swift`.

**Type ownership:** `UITestScenario.swift` defines `UITestScenario` and `UITestNetworkPolicy`; `UITestScenarioSeeds.swift` defines all seed structs; `ScriptedNetworkStep.swift` defines body/header expectations, `ScriptedNetworkResult`, `ScriptedNetworkFailure`, and `ScriptedNetworkStep`; `ScriptedNetworkTransport.swift` defines `ScriptedNetworkTransportError` and the actor; `ScriptedImageLoader.swift` defines its typed error and fail-closed loader; modified `AppLaunchConfiguration.swift` defines `UITestConfigurationError` and `AppLaunchConfiguration`.

**Modify:** `AppTemplate/App/Entry/AppLaunchConfiguration.swift`, `AppTemplate/App/AppDependencies/AppDependencies.swift`, `AppTemplate/App/Entry/AppTemplateApp.swift`, `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`, `AppTemplateTests/App/Composition/AppDependenciesTests.swift`, `AppTemplateUITests/AppTemplateUITests.swift`.

**Test:** `AppTemplateTests/App/Entry/UITestScenarioTests.swift`, `AppTemplateTests/App/Entry/ScriptedNetworkTransportTests.swift`, `AppTemplateTests/App/Entry/ScriptedImageLoaderTests.swift`, `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`.

**Consumes / Produces**

~~~swift
nonisolated struct UITestSessionSeed: Equatable, Sendable {
    let keychainData: Data?
}
nonisolated struct UITestLocalDatabaseSeed: Equatable, Sendable {
    let examples: [ExampleRecord]
}
nonisolated struct UITestPreferencesSeed: Equatable, Sendable {
    let encodedValues: [String: Data]
}
nonisolated struct UITestNotificationSeed: Equatable, Sendable {
    let authorizationStatus: LocalNotificationAuthorizationStatus
    let pendingRequests: [LocalNotificationRequest]
}
nonisolated struct UITestImageSeed: Equatable, Sendable {
    let steps: [ScriptedImageStep]
}
nonisolated struct UITestScenario: Equatable, Sendable {
    nonisolated enum Name: String, CaseIterable, Codable, Sendable {
        case guestStore = "guest-store"
        case protectedFavorite = "protected-favorite"
        case productReminder = "product-reminder"
        case servicesBasic = "services-basic"
        case accessibilitySmoke = "accessibility-smoke"
    }
    let id: Name
    let appState: AppState
    let sessionSeed: UITestSessionSeed
    let localDatabaseSeed: UITestLocalDatabaseSeed
    let preferencesSeed: UITestPreferencesSeed
    let notificationSeed: UITestNotificationSeed
    let imageSeed: UITestImageSeed
    let networkPolicy: UITestNetworkPolicy
    let remoteSteps: [ScriptedNetworkStep]
    static func named(_ id: String) throws -> UITestScenario
}
nonisolated enum UITestNetworkPolicy: Equatable, Sendable {
    case failClosed
}
nonisolated enum UITestConfigurationError: Error, Equatable, Sendable {
    case missingScenario
    case duplicateOption(String)
    case unknownOption(String)
    case unknownScenario(String)
    case malformedValue(option: String)
}
nonisolated enum ScriptedNetworkResult: Equatable, Sendable {
    case response(statusCode: Int, headers: HTTPHeaders, body: Data)
    case failure(ScriptedNetworkFailure)
}
nonisolated enum ScriptedNetworkFailure: Error, Equatable, Sendable {
    case cancelled, transport
}
nonisolated enum ScriptedBodyExpectation: Equatable, Sendable {
    case none
    case exact(Data)
    case json(Data)
}
nonisolated struct ScriptedNetworkStep: Equatable, Sendable {
    let origin: URL
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let headers: HTTPHeaders
    let shouldHandleCookies: Bool?
    let body: ScriptedBodyExpectation
    let result: ScriptedNetworkResult
}
nonisolated enum ScriptedNetworkTransportError: Error, Equatable, Sendable {
    case unexpectedRequest
    case requestMismatch
    case unconsumedSteps(Int)
}
nonisolated enum AppLaunchConfiguration: Equatable, Sendable {
    case live
    case uiTesting(UITestScenario)
    case invalidUITesting(UITestConfigurationError)
}
actor ScriptedNetworkTransport: NetworkTransport {
    init(steps: [ScriptedNetworkStep], tracker: UITestScriptConsumptionTracker? = nil)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func assertExhausted() throws
}
nonisolated enum ScriptedImageLoaderError: Error, Equatable, Sendable {
    case unexpectedURL, urlMismatch, scriptedFailure, unconsumedSteps(Int)
}
nonisolated enum ScriptedImageResult: Equatable, Sendable {
    case success(LoadedImage)
    case failure
}
nonisolated struct ScriptedImageStep: Equatable, Sendable {
    let url: URL
    let result: ScriptedImageResult
}
actor ScriptedImageLoader: IImageLoader {
    init(steps: [ScriptedImageStep], tracker: UITestScriptConsumptionTracker? = nil)
    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage
    func assertExhausted() throws
}
nonisolated enum UITestScriptComponent: Sendable { case network, image }
nonisolated enum UITestScriptConsumptionPresentation: Equatable, Sendable { case pending, exhausted, failed }
actor UITestScriptConsumptionTracker {
    init(networkSteps: Int, imageSteps: Int)
    func didConsume(_ component: UITestScriptComponent)
    func didFail(_ component: UITestScriptComponent)
    func updates() -> AsyncStream<UITestScriptConsumptionPresentation>
}
~~~

- [ ] **RED:** Test exact `--ui-testing --ui-test-scenario <id>` parsing for every stable Name raw value, the supported leading macOS `-ApplePersistenceIgnoreState YES` pair, marker/option in either order, and malformed/duplicate/unknown app UI options. Any appearance of either UI-test option without a valid pair is invalid, never live; unrelated non-UI process arguments are ignored. Test ordered origin/method/path/canonical-query/header/cookie/body matching, semantic JSON-body equality independent of key order, mismatch without consuming the expected step, exhaustion/unconsumed steps, cancellation, fail-closed image exhaustion, and fresh dependency identity. Empty scripts reject every network/image request. Tracker tests prove only the shared network+image zero state publishes `.exhausted`, mismatch/unplanned access permanently publishes `.failed`, replay is atomic, and descriptions expose no step data.

~~~swift
@Test func malformedMarkerNeverBecomesLive() {
    #expect(
        AppLaunchConfiguration(arguments: ["AppTemplate", "--ui-testing"])
        == .invalidUITesting(.missingScenario)
    )
}
~~~

- [ ] Run RED; expect missing scenario/seeds/transport/invalid launch case.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/UITestScenarioTests -only-testing:AppTemplateTests/ScriptedNetworkTransportTests -only-testing:AppTemplateTests/ScriptedImageLoaderTests -only-testing:AppTemplateTests/UITestScriptConsumptionTrackerTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests
~~~

- [ ] **GREEN:** `named(_:)` parses `Name(rawValue:)`; composition builds each invocation from fresh in-memory AppState, Keychain, SwiftData, preferences, notifications, fixed clock, one shared `UITestScriptConsumptionTracker`, `ScriptedImageLoader`, and `ScriptedNetworkTransport`. Every catalog entry uses `networkPolicy.failClosed`. Normalize an origin to lowercased scheme/host/effective port, compare query pairs deterministically, require exactly the listed security-relevant headers, and compare `.json` bodies as JSON values rather than bytes. Peek and validate the first step completely before removing it; on a successful removal notify the matching tracker component, and on mismatch/unplanned access mark it failed. Error descriptions contain only mismatch categories, never header/body/query values. In a UI-testing launch, `AppTemplateApp` observes the tracker and exposes exactly one test-only accessibility marker: `ui-test.script-status.exhausted`, `ui-test.script-status.pending`, or `ui-test.script-status.failed`; no counts or request data enter the tree. This is the cross-process acceptance seam used by every XCUITest, because an in-process `assertExhausted()` alone cannot prove the launched app consumed its script. `invalidUITesting` renders static diagnostics with no live side effects. Previews use an explicit scenario but do not expose the marker.

~~~swift
func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    guard let step = remaining.first else {
        throw ScriptedNetworkTransportError.unexpectedRequest
    }
    guard step.matches(request) else {
        throw ScriptedNetworkTransportError.requestMismatch
    }
    let matched = remaining.removeFirst()
    return try matched.response(for: request)
}
~~~

- [ ] Run PASS, iOS build, and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/UITestScenarioTests -only-testing:AppTemplateTests/ScriptedNetworkTransportTests -only-testing:AppTemplateTests/ScriptedImageLoaderTests -only-testing:AppTemplateTests/UITestScriptConsumptionTrackerTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests -only-testing:AppTemplateTests/AppDependenciesTests
xcodebuild build -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
git add AppTemplate/App/Entry/UITesting AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplateTests/App/Entry/UITestScenarioTests.swift AppTemplateTests/App/Entry/ScriptedNetworkTransportTests.swift AppTemplateTests/App/Entry/ScriptedImageLoaderTests.swift AppTemplateTests/App/Entry/UITestScriptConsumptionTrackerTests.swift AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateUITests/AppTemplateUITests.swift
git commit -m "test: add deterministic ui scenarios"
~~~

## Phase 1 Verification

- [ ] Run the complete offline suite and inspect staged paths.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
git status --short
git diff --cached --name-only
~~~
