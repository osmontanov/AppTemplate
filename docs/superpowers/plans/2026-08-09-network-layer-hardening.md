# Network Layer Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the Foundation networking layer so sandboxed macOS builds can connect, request and response metadata is deterministic, provider execution respects concurrency and cancellation boundaries, and each request lifecycle is observable.

**Architecture:** Keep the existing `NetworkTarget -> NetworkRequestBuilder -> RequestAdapter -> NetworkEventMonitor -> NetworkTransport` pipeline and the `RemoteService` actor boundary. Replace internal string-dictionary header contracts with a deterministic value type, create one post-adaptation request context per attempt, and preserve one normalized result path for live and stubbed requests.

**Tech Stack:** Swift 6, Foundation, URLSession, Swift Testing, XCTest UI tests, Xcode 26.6; no third-party networking or reactive dependency.

## Global Constraints

- Keep `AppTemplate/App/Networking` Foundation-only; do not add third-party networking, reactive, or logging dependencies.
- Keep `NetworkProvider.request(_:)` as the only asynchronous request API, and keep `RemoteService` as the actor-facing domain boundary.
- Preserve `Sendable` boundaries, `.successful` (`200..<300`) default validation, and target-level `.never`, `.immediate`, and `.delayed(Duration)` stubbing.
- Do not add redirect policy, retries, token refresh, caching, reachability, request coalescing, certificate pinning, multipart, upload/download progress, or a multi-value header model.
- Do not create a manually managed entitlements file. Only the application target receives outgoing-network capability; test targets do not.
- Request construction snapshots `baseURL`, `path`, `method`, `task`, and `headers` once. Empty paths preserve the base URL byte-for-byte, and existing encoded query bytes are never decoded and re-encoded.
- `HTTPHeaders` accepts only non-empty ASCII HTTP token names. Trusted request and stub construction preconditions invalid names; untrusted live response mapping skips them.
- Monitor callbacks are awaited sequentially in registration order. They are read-only observers, must return quickly, and must enqueue expensive telemetry internally.
- Every implementation task follows RED/GREEN and ends in an independent commit. Executor and cancellation changes are separate tasks and commits.
- Combined execution order is fixed: complete Network Tasks 1–6, implement the separately approved macOS UI-test window-isolation plan, and only then run Network Task 7. Task 7 verifies the combined branch, so it must not preserve or allow the former five-test UI baseline.

---

## File Map

### Create

- `AppTemplate/App/Networking/Core/HTTPHeaders.swift` — validated, deterministic case-insensitive single-value HTTP fields.
- `AppTemplate/App/Networking/Pipeline/NetworkRequestContext.swift` — immutable ID plus final adapted request passed to monitors.
- `AppTemplateTests/App/Networking/HTTPHeadersTests.swift` — header validation, equality, ordering, and live-response collision tests.
- `AppTemplateTests/TestSupport/Networking/ControlledRequestStart.swift` — deterministic test-only child-task start/permit coordination.

### Modify

- `AppTemplate.xcodeproj/project.pbxproj` — enable sandbox client networking in app Debug and Release only.
- `AppTemplate/App/Networking/Core/NetworkTarget.swift` — migrate target headers to `HTTPHeaders`.
- `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift` — snapshot targets, preserve URLs, and apply sorted header fields.
- `AppTemplate/App/Networking/Response/NetworkResponse.swift` — expose `HTTPHeaders`.
- `AppTemplate/App/Networking/Stubbing/StubResponse.swift` — expose `HTTPHeaders` and enforce trusted header construction.
- `AppTemplate/App/Networking/NetworkProvider.swift` — response-header conversion, `@concurrent` request execution, cancellation checkpoints, and monitor context propagation.
- `AppTemplate/App/Networking/Pipeline/NetworkEventMonitor.swift` — context-first lifecycle callback contract and sequential-observer documentation.
- `AppTemplate/App/Services/Remote/ExampleTarget.swift` — migrate the example target header fixture.
- `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift` — exact URL, full target-snapshot, and header-application regressions.
- `AppTemplateTests/App/Networking/NetworkProviderTests.swift` — live response headers, executor liveness, and context correlation tests.
- `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift` — deterministic child-task cancellation and stub-context tests.
- `AppTemplateTests/App/Networking/NetworkResponseTests.swift` — response-header case-insensitive access.
- `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift` — migrate target/header fixture types.
- `AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift` — record lifecycle phase, request ID, and final request.
- `docs/ARCHITECTURE.md` — describe the hardened pipeline contract.
- `docs/CUSTOMIZATION.md` — describe production session and monitor configuration.
- `docs/RELEASE_CHECKLIST.md` — record exact signed-entitlement inspection requirements.

---

### Task 1: Enable macOS Client Networking and Verify It Locally

**Files:**

- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Interfaces:**

- Consumes: App target Debug and Release build configurations, whose sandbox is already enabled.
- Produces: signed Debug and Release `AppTemplate.app` products with `com.apple.security.app-sandbox == true`, `com.apple.security.network.client == true`, and no `com.apple.security.network.server` key.

- [ ] **Step 1: Capture app and test-target effective settings**

```bash
set -euo pipefail

for configuration in Debug Release; do
  app_settings="$(xcodebuild -project AppTemplate.xcodeproj -target AppTemplate \
    -configuration "$configuration" -sdk macosx -showBuildSettings)"
  printf '%s\n' "$app_settings" \
    | rg 'ENABLE_(APP_SANDBOX|OUTGOING_NETWORK_CONNECTIONS|INCOMING_NETWORK_CONNECTIONS)'
  printf '%s\n' "$app_settings" | rg -q 'ENABLE_APP_SANDBOX = YES'
  if printf '%s\n' "$app_settings" | rg -q 'ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES'; then
    exit 1
  fi

  for target in AppTemplateTests AppTemplateUITests; do
    test_settings="$(xcodebuild -project AppTemplate.xcodeproj -target "$target" \
      -configuration "$configuration" -sdk macosx -showBuildSettings)"
    if printf '%s\n' "$test_settings" | rg -q \
      'ENABLE_(OUTGOING_NETWORK_CONNECTIONS|INCOMING_NETWORK_CONNECTIONS) = YES'; then
      exit 1
    fi
  done
done
```

Expected: app sandbox is enabled while outgoing client networking is not yet enabled; both test targets have neither outgoing nor incoming networking enabled in Debug and Release.

- [ ] **Step 2: Add the application capability**

In each `AppTemplate` target Debug and Release configuration, add only:

```text
ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
```

Keep `ENABLE_APP_SANDBOX = YES`; do not add `ENABLE_INCOMING_NETWORK_CONNECTIONS` anywhere and do not edit unit/UI test target settings.

- [ ] **Step 3: Run the safe local signed-product gate**

```bash
set -euo pipefail

entitlement_root="$(mktemp -d /tmp/AppTemplate-entitlements.XXXXXX)"
test -d "$entitlement_root"
test ! -L "$entitlement_root"
case "$entitlement_root" in
  /tmp/AppTemplate-entitlements.*) ;;
  *) exit 1 ;;
esac

assert_effective_settings() {
  local configuration="$1"
  local app_settings
  local test_settings

  app_settings="$(xcodebuild -project AppTemplate.xcodeproj -target AppTemplate \
    -configuration "$configuration" -sdk macosx -showBuildSettings)"
  printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_APP_SANDBOX = YES$'
  printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES$'
  if printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_INCOMING_NETWORK_CONNECTIONS = YES$'; then
    return 1
  fi

  for target in AppTemplateTests AppTemplateUITests; do
    test_settings="$(xcodebuild -project AppTemplate.xcodeproj -target "$target" \
      -configuration "$configuration" -sdk macosx -showBuildSettings)"
    if printf '%s\n' "$test_settings" \
      | rg -q '^[[:space:]]*ENABLE_(OUTGOING|INCOMING)_NETWORK_CONNECTIONS = YES$'; then
      return 1
    fi
  done
}

for configuration in Debug Release; do
  assert_effective_settings "$configuration"

  derived_data="$entitlement_root/DerivedData-$configuration"
  xcodebuild build \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration "$configuration" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES

  app="$derived_data/Build/Products/$configuration/AppTemplate.app"
  codesign --verify --deep --strict --verbose=2 "$app"
  codesign --display --entitlements - --xml "$app" 2>/dev/null \
    | plutil -convert json -o - - \
    | jq -e '."com.apple.security.app-sandbox" == true
        and ."com.apple.security.network.client" == true
        and (has("com.apple.security.network.server") | not)'
done
```

Do not delete `entitlement_root` as part of this command; it is a uniquely created, inspectable local artifact.

Expected: Debug and Release effective settings require app sandbox/client networking, forbid app server networking, and forbid client/server networking on both test targets. Both builds, both signature checks, and both JSON entitlement checks then exit zero. This verifies embedded development/ad-hoc entitlements only; it does not establish distribution signing, notarization, or Gatekeeper acceptance.

- [ ] **Step 4: Update the release checklist**

Add this checklist item under macOS signing/sandbox verification:

```markdown
- [ ] Inspect signed Debug and Release macOS app entitlements: require
  `com.apple.security.app-sandbox = true` and
  `com.apple.security.network.client = true`, and require
  `com.apple.security.network.server` to be absent.
```

- [ ] **Step 5: Commit the entitlement and local gate**

```bash
git add AppTemplate.xcodeproj/project.pbxproj docs/RELEASE_CHECKLIST.md
git commit -m "fix: enable and verify macOS client networking"
```

---

### Task 2: Snapshot Targets and Preserve URL Bytes

**Files:**

- Modify: `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift`

**Interfaces:**

- Consumes: `NetworkTarget.baseURL`, `path`, `method`, `task`, and `headers`.
- Produces: `func build<Target: NetworkTarget>(_ target: Target) throws -> URLRequest` that reads each consumed target property once and uses only local snapshots after that point.

- [ ] **Step 1: Write exact URL and snapshot RED tests**

Add these tests plus a lock-protected `SnapshotRecorder` whose computed target properties increment independently:

```swift
@Test
func emptyPathPreservesBaseURLExactly() throws {
    let target = RequestBuilderTarget(
        baseURL: URL(string: "https://api.example.test/v1")!,
        path: ""
    )

    let request = try NetworkRequestBuilder().build(target)

    #expect(request.url?.absoluteString == "https://api.example.test/v1")
}

@Test
func preservesPercentEncodedBaseQueryWhenAppendingTargetQuery() throws {
    let target = RequestBuilderTarget(
        baseURL: URL(string: "https://api.example.test/v1?signature=a%2Fb%2Bc%3Dd%26e%3Df")!,
        path: "/items",
        task: .query([URLQueryItem(name: "page", value: "2")])
    )

    let request = try NetworkRequestBuilder().build(target)
    let components = try #require(URLComponents(
        url: try #require(request.url), resolvingAgainstBaseURL: false
    ))

    #expect(components.percentEncodedQuery == "signature=a%2Fb%2Bc%3Dd%26e%3Df&page=2")
}

@Test
func snapshotsEveryConsumedTargetPropertyOnce() throws {
    let recorder = SnapshotRecorder()
    let request = try NetworkRequestBuilder().build(
        ComputedSnapshotTarget(recorder: recorder)
    )

    #expect(recorder.reads == .init(baseURL: 1, path: 1, method: 1, task: 1, headers: 1))
    #expect(request.url?.query == "snapshot=1")
}
```

Place these complete fixtures below `RequestBuilderTarget` in the same test file:

```swift
nonisolated
private struct SnapshotReadCounts: Equatable, Sendable {
    var baseURL = 0
    var path = 0
    var method = 0
    var task = 0
    var headers = 0
}

nonisolated
private final class SnapshotRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var counts = SnapshotReadCounts()

    var reads: SnapshotReadCounts { lock.withLock { counts } }

    func nextBaseURL() -> URL {
        lock.withLock {
            counts.baseURL += 1
            return URL(string: "https://api.example.test")!
        }
    }

    func nextPath() -> String {
        lock.withLock {
            counts.path += 1
            return "/snapshot"
        }
    }

    func nextMethod() -> HTTPMethod {
        lock.withLock {
            counts.method += 1
            return .get
        }
    }

    func nextTask() -> NetworkTask {
        lock.withLock {
            counts.task += 1
            return .query([
                URLQueryItem(name: "snapshot", value: String(counts.task))
            ])
        }
    }

    func nextHeaders() -> [String: String] {
        lock.withLock {
            counts.headers += 1
            return ["X-Snapshot": String(counts.headers)]
        }
    }
}

nonisolated
private struct ComputedSnapshotTarget: NetworkTarget {
    let recorder: SnapshotRecorder

    var baseURL: URL { recorder.nextBaseURL() }
    var path: String { recorder.nextPath() }
    var method: HTTPMethod { recorder.nextMethod() }
    var task: NetworkTask { recorder.nextTask() }
    var headers: [String: String] { recorder.nextHeaders() }
}
```

- [ ] **Step 2: Run the builder RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkBuilder-Red \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests
```

Expected: the empty-path assertion sees an appended slash, encoded-base-query assertion sees rewritten bytes, and the computed task count is greater than one.

- [ ] **Step 3: Snapshot first and append only new encoded query bytes**

At the top of `build(_:)`, materialize all consumed values exactly once:

```swift
let baseURL = target.baseURL
let path = target.path
let method = target.method
let task = target.task
let headers = target.headers

let urlWithPath = path.isEmpty ? baseURL : baseURL.appending(path: path)
```

Encode only the new query values with a temporary component and concatenate it to the preserved encoded query:

```swift
if !task.queryItems.isEmpty {
    var appended = URLComponents()
    appended.queryItems = task.queryItems
    guard let appendedQuery = appended.percentEncodedQuery else {
        throw NetworkError.requestConstruction
    }

    if let existingQuery = components.percentEncodedQuery, !existingQuery.isEmpty {
        components.percentEncodedQuery = existingQuery + "&" + appendedQuery
    } else {
        components.percentEncodedQuery = appendedQuery
    }
}
```

Use only `method`, `task`, and `headers` in the remainder of the method. Task 3 changes the header loop to `headers.fields`.

- [ ] **Step 4: Run the builder GREEN gate**

Run the Step 2 command with `-derivedDataPath /tmp/AppTemplate-NetworkBuilder-Green`.

Expected: all `NetworkRequestBuilderTests` pass.

- [ ] **Step 5: Commit the URL construction contract**

```bash
git add AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift \
  AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift
git commit -m "fix: preserve deterministic request URL construction"
```

---

### Task 3: Replace Header Dictionaries with Deterministic HTTPHeaders

**Files:**

- Create: `AppTemplate/App/Networking/Core/HTTPHeaders.swift`
- Create: `AppTemplateTests/App/Networking/HTTPHeadersTests.swift`
- Modify: `AppTemplate/App/Networking/Core/NetworkTarget.swift`
- Modify: `AppTemplate/App/Networking/RequestBuilding/NetworkRequestBuilder.swift`
- Modify: `AppTemplate/App/Networking/Response/NetworkResponse.swift`
- Modify: `AppTemplate/App/Networking/Stubbing/StubResponse.swift`
- Modify: `AppTemplate/App/Networking/NetworkProvider.swift`
- Modify: `AppTemplate/App/Services/Remote/ExampleTarget.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkRequestBuilderTests.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderTests.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkResponseTests.swift`
- Modify: `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift`

**Interfaces:**

- Produces:

```swift
nonisolated
struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    nonisolated struct Field: Sendable, Equatable {
        let name: String
        let value: String
    }

    init()
    init(dictionaryLiteral elements: (String, String)...)
    subscript(_ name: String) -> String? { get }
    mutating func set(_ value: String, for name: String)
    var fields: [Field] { get }
    static func isValidFieldName(_ name: String) -> Bool
}
```

- Produces: `NetworkTarget.headers`, `StubResponse.headers`, and `NetworkResponse.headers` typed as `HTTPHeaders`; no `[String: String]` conversion initializer.

- [ ] **Step 1: Write header and response-mapping RED tests**

Create `HTTPHeadersTests` with lookup, ordered literal replacement, mutation replacement, canonical ordering, spelling-insensitive equality, and field-name validity tests:

```swift
@Test
func orderedWritesUseCaseInsensitiveLastWriteWins() {
    var headers: HTTPHeaders = [
        "Authorization": "Bearer old",
        "authorization": "Bearer new"
    ]
    headers.set("Bearer final", for: "AUTHORIZATION")

    #expect(headers["authorization"] == "Bearer final")
    #expect(headers.fields == [
        HTTPHeaders.Field(name: "AUTHORIZATION", value: "Bearer final")
    ])
}

@Test
func equalityIgnoresPresentationSpellingAndFieldsUseCanonicalOrder() {
    let first: HTTPHeaders = ["X-Zebra": "z", "content-type": "application/json"]
    let second: HTTPHeaders = ["Content-Type": "application/json", "x-zebra": "z"]

    #expect(first == second)
    #expect(first.fields.map(\.name) == ["content-type", "X-Zebra"])
}

@Test
func onlyASCIIHTTPTokenNamesAreValidAndInvalidLookupIsNil() {
    #expect(HTTPHeaders.isValidFieldName("!#$%&'*+-.^_`|~AZaz09"))
    #expect(!HTTPHeaders.isValidFieldName(""))
    #expect(!HTTPHeaders.isValidFieldName("bad name"))
    #expect(!HTTPHeaders.isValidFieldName("bad:name"))
    #expect(!HTTPHeaders.isValidFieldName("café"))

    let headers: HTTPHeaders = ["X-Valid": "yes"]
    #expect(headers["bad name"] == nil)
    #expect(headers["café"] == nil)
}
```

Add a `SyntheticHTTPURLResponse` test subclass that overrides `allHeaderFields`; pass it through `InMemoryNetworkTransport` so the production provider mapper is tested without a production-only test API:

```swift
nonisolated
private final class SyntheticHTTPURLResponse: HTTPURLResponse, @unchecked Sendable {
    private let syntheticFields: [AnyHashable: Any]

    init(fields: [AnyHashable: Any]) {
        syntheticFields = fields
        super.init(
            url: URL(string: "https://api.example.test/resource")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
    }

    override var allHeaderFields: [AnyHashable: Any] { syntheticFields }

    required init?(coder: NSCoder) { fatalError("SyntheticHTTPURLResponse is test-only") }
}
```

Keep this fixture in `NetworkProviderTests.swift` next to its existing private `ProviderTarget` and `makeHTTPTransport` helpers. Return the synthetic response from an `InMemoryNetworkTransport` closure, then call `NetworkProvider<ProviderTarget>.request(_:)`; this exercises the private production mapping through its real transport boundary.

Use fields containing `"X-Rate-Limit": "old"`, `"x-rate-limit": "new"`, `"X-Retry-After": NSNumber(value: 3)`, `"bad name": "ignored"`, and `AnyHashable(7): "ignored"`. Assert the response has exactly one usable rate-limit field whose value is `"new"`, `response.headers["x-retry-after"] == "3"`, and invalid/non-string field names are absent. The retry assertion exercises `String(describing:)` for a valid live field whose value is not already a string; the collision assertion proves sorting makes the lexicographically greatest original spelling/value tuple win, independent of dictionary iteration.

- [ ] **Step 2: Run the header RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-HTTPHeaders-Red \
  -only-testing:AppTemplateTests/HTTPHeadersTests \
  -only-testing:AppTemplateTests/NetworkProviderTests
```

Expected: compilation fails because `HTTPHeaders` does not exist and existing response headers remain a dictionary.

- [ ] **Step 3: Implement the validated value type**

Use canonical-key storage, byte-wise ASCII canonicalization, explicit equality, and trusted-input preconditions:

```swift
private var storage: [String: Field] = [:]

static func isValidFieldName(_ name: String) -> Bool {
    !name.isEmpty && name.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (65...90).contains(byte) ||
        (97...122).contains(byte) ||
        [33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126].contains(byte)
    }
}

subscript(_ name: String) -> String? {
    guard Self.isValidFieldName(name) else { return nil }
    return storage[Self.canonicalName(name)]?.value
}

mutating func set(_ value: String, for name: String) {
    precondition(Self.isValidFieldName(name), "Invalid HTTP field name")
    storage[Self.canonicalName(name)] = Field(name: name, value: value)
}

static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.storage.mapValues(\.value) == rhs.storage.mapValues(\.value)
}
```

`canonicalName(_:)` must transform only ASCII bytes `65...90` to `97...122`; all valid punctuation and digits stay unchanged. `fields` sorts `storage` by canonical key and returns the retained `Field` values. Dictionary-literal initialization calls `set` in source order.

Do not add a brittle subprocess crash harness for `precondition`. The executable tests cover the shared `isValidFieldName(_:)` predicate for valid and invalid names, invalid untrusted lookup behavior, and dictionary-literal/`set` behavior for trusted valid names. During review, inspect that both dictionary-literal initialization and `set` route trusted names through the shown precondition before canonical storage; describe this as an inspected invariant rather than a directly crash-tested branch.

- [ ] **Step 4: Migrate contracts and make live mapping deterministic**

Change all three header properties and defaults to `HTTPHeaders`, then apply request fields in canonical order:

```swift
for field in headers.fields {
    request.setValue(field.value, forHTTPHeaderField: field.name)
}
```

Remove the special `Content-Type` spelling branch. Build the live response header value by filtering, sorting, and then calling `set` only on trusted names:

```swift
let entries = response.allHeaderFields.compactMap { key, value -> (String, String)? in
    guard let name = key as? String, HTTPHeaders.isValidFieldName(name) else {
        return nil
    }
    return (name, String(describing: value))
}.sorted {
    let leftCanonical = HTTPHeaders.canonicalName($0.0)
    let rightCanonical = HTTPHeaders.canonicalName($1.0)
    if leftCanonical != rightCanonical { return leftCanonical < rightCanonical }
    if $0.0 != $1.0 { return $0.0.utf8.lexicographicallyPrecedes($1.0.utf8) }
    return $0.1 < $1.1
}

return entries.reduce(into: HTTPHeaders()) { headers, entry in
    headers.set(entry.1, for: entry.0)
}
```

Make `canonicalName(_:)` module-visible rather than production-public if the mapper needs it; its behavior remains covered by the public `fields` and lookup tests. Migrate every fixture that conforms to `NetworkTarget` or constructs `StubResponse`/`NetworkResponse` from `[String: String]` to `HTTPHeaders`; dictionary literals remain valid at call sites, but do not add a dictionary initializer. In particular, Task 2's `SnapshotRecorder.nextHeaders()` and `ComputedSnapshotTarget.headers`, plus `RequestBuilderTarget.headers`, `ProviderTarget.headers`, and `StubTarget.headers`, must return `HTTPHeaders` after this task.

Keep Foundation-boundary helpers such as
`makeHTTPTransport(headers: [String: String])` dictionary-typed because they
feed `HTTPURLResponse(headerFields:)`, not the networking layer's header
contract. Convert only after `HTTPURLResponse.allHeaderFields` crosses back
through the production provider mapper.

- [ ] **Step 5: Run the header GREEN gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-HTTPHeaders-Green \
  -only-testing:AppTemplateTests/HTTPHeadersTests \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests \
  -only-testing:AppTemplateTests/RemoteServiceTests
```

Expected: selected tests pass; live and stub responses both support case-insensitive lookup and the synthetic collision winner is deterministic.

- [ ] **Step 6: Commit the header migration**

```bash
git add AppTemplate/App/Networking AppTemplate/App/Services/Remote/ExampleTarget.swift \
  AppTemplateTests/App/Networking AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift
git commit -m "refactor: make HTTP headers deterministic"
```

---

### Task 4: Make Provider Setup Independent of the Caller Actor

**Files:**

- Modify: `AppTemplate/App/Networking/NetworkProvider.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderTests.swift`

**Interfaces:**

- Produces:

```swift
@concurrent
func request(_ target: Target) async throws -> NetworkResponse
```

- Guarantees: synchronous request building, JSON encoding, stub mapping, and pipeline setup do not inherit a caller actor such as `MainActor`; structured cancellation and task-local values still flow through the request.

- [ ] **Step 1: Write the MainActor-liveness RED gate**

Create this lock/semaphore-backed helper. Its timeout is part of the assertion: the bad caller-actor path must unblock only after the recorded deadline, while the concurrent path is released promptly by MainActor.

```swift
nonisolated
private final class MainActorLivenessGate: @unchecked Sendable {
    private let entered = DispatchSemaphore(value: 0)
    private let released = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var releasedBeforeDeadline = false

    var wasReleasedBeforeDeadline: Bool {
        lock.withLock { releasedBeforeDeadline }
    }

    func pauseEncoder() {
        entered.signal()
        let releasedInTime = released.wait(timeout: .now() + .seconds(2)) == .success
        lock.withLock { releasedBeforeDeadline = releasedInTime }
    }

    func waitForEncoderEntry() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(
                    returning: self.entered.wait(timeout: .now() + .seconds(2)) == .success
                )
            }
        }
    }

    func releaseFromMainActor() { released.signal() }
}
```

Use it in this test; do not assert `Thread.isMainThread`:

```swift
@MainActor
@Test
func requestSetupDoesNotBlockTheMainActor() async throws {
    let gate = MainActorLivenessGate()
    let provider = NetworkProvider<ProviderTarget>(
        transport: makeHTTPTransport(statusCode: 200),
        jsonEncoderFactory: {
            gate.pauseEncoder()
            return JSONEncoder()
        }
    )
    let target = ProviderTarget(task: .json(ExecutorPayload(value: "liveness")))

    let requestTask = Task { try await provider.request(target) }
    let entered = await gate.waitForEncoderEntry()
    #expect(entered)

    let releaseTask = Task { @MainActor in
        gate.releaseFromMainActor()
    }
    await releaseTask.value
    _ = try await requestTask.value

    #expect(gate.wasReleasedBeforeDeadline)
}
```

Add this payload beside the existing provider test fixtures:

```swift
nonisolated
private struct ExecutorPayload: Encodable, Sendable {
    let value: String
}
```

Without `@concurrent`, the paused synchronous factory occupies MainActor and the release operation cannot run before the gate deadline. With the annotation, the waiting MainActor resumes and releases the factory. `Thread.isMainThread` may be kept only as a non-gating smoke observation.

- [ ] **Step 2: Run the executor RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkExecutor-Red \
  -only-testing:AppTemplateTests/NetworkProviderTests
```

Expected: `requestSetupDoesNotBlockTheMainActor` fails its bounded liveness assertion under caller-actor inheritance.

- [ ] **Step 3: Mark only the public request boundary concurrent**

Apply the declaration exactly:

```swift
@concurrent
func request(_ target: Target) async throws -> NetworkResponse {
```

Do not wrap the provider body in `Task.detached`, do not introduce a new task, and do not alter monitor, adapter, sleep, or transport call structure.

- [ ] **Step 4: Run the executor GREEN gate**

Run the Step 2 command with `-derivedDataPath /tmp/AppTemplate-NetworkExecutor-Green`.

Expected: the liveness release occurs before the fixed deadline and all selected provider tests pass.

- [ ] **Step 5: Commit the executor contract**

```bash
git add AppTemplate/App/Networking/NetworkProvider.swift \
  AppTemplateTests/App/Networking/NetworkProviderTests.swift
git commit -m "fix: run network provider setup concurrently"
```

---

### Task 5: Enforce Universal Post-Monitor Cancellation Checkpoints

**Files:**

- Create: `AppTemplateTests/TestSupport/Networking/ControlledRequestStart.swift`
- Modify: `AppTemplate/App/Networking/NetworkProvider.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderTests.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`

**Interfaces:**

- Consumes: a successfully built and adapted request after `willSend` has been emitted.
- Produces: `NetworkError.cancelled` before live transport, immediate stub success, or delayed-stub sleep/sample work when cancellation is observed; emits exactly one paired terminal monitor event.

- [ ] **Step 1: Create deterministic child-task coordination support**

Create `AppTemplateTests/TestSupport/Networking/ControlledRequestStart.swift` with this complete test-only API:

```swift
import Foundation
@testable import AppTemplate

actor ControlledRequestStart {
    private var started = false
    private var permitted = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var permitWaiter: CheckedContinuation<Void, Never>?

    func markStartedAndWaitForPermission() async {
        started = true
        startWaiter?.resume()
        startWaiter = nil
        guard !permitted else { return }
        await withCheckedContinuation { permitWaiter = $0 }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func permitRequestToContinue() {
        permitted = true
        permitWaiter?.resume()
        permitWaiter = nil
    }
}

nonisolated
func controlledRequest<Target: NetworkTarget>(
    provider: NetworkProvider<Target>,
    target: Target,
    start: ControlledRequestStart
) -> Task<Result<NetworkResponse, any Error>, Never> {
    Task {
        await start.markStartedAndWaitForPermission()
        do {
            return .success(try await provider.request(target))
        } catch {
            return .failure(error)
        }
    }
}
```

- [ ] **Step 2: Add the three pre-cancelled child-task RED tests**

Add this live-transport test to `NetworkProviderTests.swift`:

```swift
@Test
func preCancelledLiveRequestSkipsTransportAndCompletesMonitoring() async {
    let transport = makeHTTPTransport(statusCode: 200)
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: transport,
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)]
    )
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: ProviderTarget(), start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result, case NetworkError.cancelled = error else {
        Issue.record("Expected cancelled live request")
        return
    }
    let requests = await transport.recordedRequests()
    let events = await recorder.recordedEvents()
    #expect(requests.isEmpty)
    #expect(events == [
        .willSend(monitor: "observer"),
        .didComplete(monitor: "observer", outcome: .cancelled)
    ])
}
```

Add these immediate and delayed stub tests to `NetworkProviderStubTests.swift`:

```swift
@Test
func preCancelledImmediateStubReturnsCancelledWithoutSampleSuccess() async {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<StubTarget>(
        transport: unexpectedTransport(),
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
        stubBehavior: { _ in .immediate }
    )
    let target = StubTarget(sampleResponse: StubResponse(statusCode: 299, data: Data("sample".utf8)))
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: target, start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result, case NetworkError.cancelled = error else {
        Issue.record("Expected cancelled immediate stub")
        return
    }
    let events = await recorder.recordedEvents()
    #expect(events == [
        .willSend(monitor: "observer"),
        .didComplete(monitor: "observer", outcome: .cancelled)
    ])
}

@Test
func preCancelledDelayedStubSkipsSleepAndSampleSuccess() async {
    let sleepCalls = SleepCallRecorder()
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<StubTarget>(
        transport: unexpectedTransport(),
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
        stubBehavior: { _ in .delayed(.seconds(1)) },
        sleep: { _ in await sleepCalls.record() }
    )
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: StubTarget(), start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result, case NetworkError.cancelled = error else {
        Issue.record("Expected cancelled delayed stub")
        return
    }
    let sleepCount = await sleepCalls.count
    let events = await recorder.recordedEvents()
    #expect(sleepCount == 0)
    #expect(events == [
        .willSend(monitor: "observer"),
        .didComplete(monitor: "observer", outcome: .cancelled)
    ])
}

private actor SleepCallRecorder {
    private var calls = 0
    func record() { calls += 1 }
    var count: Int { calls }
}
```

- [ ] **Step 3: Add the three construction/adaptation precedence RED tests**

Add these tests to `NetworkProviderTests.swift`; both intentionally cancel the child before `request(_:)`, and both must retain the pre-monitor failure:

```swift
@Test
func preCancellationDoesNotReplaceConstructionFailure() async {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: makeHTTPTransport(statusCode: 200),
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)]
    )
    let target = ProviderTarget(baseURL: URL(string: "relative-base")!)
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: target, start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result, case NetworkError.requestConstruction = error else {
        Issue.record("Expected request construction failure")
        return
    }
    let events = await recorder.recordedEvents()
    #expect(events.isEmpty)
}

@Test
func preCancellationDoesNotReplaceAdaptationFailure() async {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: makeHTTPTransport(statusCode: 200),
        adapters: [ThrowingAdapter()],
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)]
    )
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: ProviderTarget(), start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result,
          case NetworkError.requestAdaptation = error else {
        Issue.record("Expected request adaptation failure")
        return
    }
    let events = await recorder.recordedEvents()
    #expect(events.isEmpty)
}
```

Add a third adaptation-boundary test. It proves that an adapter which observes
the already-cancelled child still fails at the pre-monitor adaptation boundary,
rather than being normalized as a post-`willSend` cancellation:

```swift
@Test
func preCancellationObservedByAdapterRemainsAdaptationFailure() async {
    let transport = makeHTTPTransport(statusCode: 200)
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: transport,
        adapters: [CancellationCheckingAdapter()],
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)]
    )
    let start = ControlledRequestStart()
    let child = controlledRequest(provider: provider, target: ProviderTarget(), start: start)

    await start.waitUntilStarted()
    child.cancel()
    await start.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result,
          case let NetworkError.requestAdaptation(underlying) = error else {
        Issue.record("Expected adapter cancellation to stay an adaptation failure")
        return
    }
    #expect(underlying is CancellationError)
    let requests = await transport.recordedRequests()
    let events = await recorder.recordedEvents()
    #expect(requests.isEmpty)
    #expect(events.isEmpty)
}

nonisolated
private struct CancellationCheckingAdapter: RequestAdapter {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        try Task.checkCancellation()
        return request
    }
}
```

- [ ] **Step 4: Add the noncooperative delayed-sleep RED test**

Add this test to `NetworkProviderStubTests.swift`. The injected sleep returns normally after the parent has cancelled its child:

```swift
@Test
func cancellationAfterNoncooperativeDelayedSleepReturnsCancelled() async {
    let recorder = NetworkEventRecorder()
    let sleepStart = ControlledRequestStart()
    let provider = NetworkProvider<StubTarget>(
        transport: unexpectedTransport(),
        monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
        stubBehavior: { _ in .delayed(.seconds(1)) },
        sleep: { _ in await sleepStart.markStartedAndWaitForPermission() }
    )

    let child = Task { () -> Result<NetworkResponse, any Error> in
        do {
            return .success(try await provider.request(StubTarget()))
        } catch {
            return .failure(error)
        }
    }
    await sleepStart.waitUntilStarted()
    child.cancel()
    await sleepStart.permitRequestToContinue()
    let result = await child.value

    guard case let .failure(error) = result, case NetworkError.cancelled = error else {
        Issue.record("Expected cancellation after noncooperative sleep")
        return
    }
    let events = await recorder.recordedEvents()
    #expect(events == [
        .willSend(monitor: "observer"),
        .didComplete(monitor: "observer", outcome: .cancelled)
    ])
}
```

- [ ] **Step 5: Run the cancellation RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkCancellation-Red \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests
```

Expected: pre-cancelled `.never` starts transport, `.immediate` returns its sample, `.delayed` starts injected sleep, cancellation after non-throwing sleep returns a sample, and adapter-observed pre-cancellation is incorrectly normalized to `.cancelled` instead of `.requestAdaptation`.

- [ ] **Step 6: Add the two checkpoints without moving the pipeline boundary**

After all adapters succeed and `willSend` has completed, keep result resolution inside the existing terminal-event path and check before switching on stub behavior:

```swift
guard !Task.isCancelled else {
    return .failure(.cancelled)
}
```

For `.delayed`, preserve existing thrown-error normalization and repeat the guard after the injected sleep returns:

```swift
do {
    try await sleep(duration)
} catch {
    return .failure(executionError(from: error))
}
guard !Task.isCancelled else {
    return .failure(.cancelled)
}
response = stubResponse(for: request, target: target)
```

Do not add a cancellation check before construction or adaptation. Their failures continue to win and produce no monitor lifecycle.

Keep cancellation normalization out of the adaptation boundary. Replace
`adaptationError(from:)` so it preserves an existing `.requestAdaptation` but
wraps every other adapter error—including `CancellationError`—as adaptation:

```swift
private func adaptationError(from error: any Error) -> NetworkError {
    if
        let networkError = error as? NetworkError,
        case .requestAdaptation = networkError
    {
        return networkError
    }
    return .requestAdaptation(underlying: error)
}
```

- [ ] **Step 7: Run the cancellation GREEN gate**

Run the Step 5 command with `-derivedDataPath /tmp/AppTemplate-NetworkCancellation-Green`.

Expected: all seven new cancellation/precedence tests pass, live transport and delayed sleep stay unstarted for post-adaptation pre-cancellation, adapter-observed cancellation remains an unmonitored adaptation failure, and every post-`willSend` cancellation has one terminal monitor event.

- [ ] **Step 8: Commit cancellation checkpoints**

```bash
git add AppTemplate/App/Networking/NetworkProvider.swift \
  AppTemplateTests/App/Networking/NetworkProviderTests.swift \
  AppTemplateTests/App/Networking/NetworkProviderStubTests.swift \
  AppTemplateTests/TestSupport/Networking/ControlledRequestStart.swift
git commit -m "fix: honor network request cancellation checkpoints"
```

---

### Task 6: Correlate Ordered Monitor Lifecycles with Final Requests

**Files:**

- Create: `AppTemplate/App/Networking/Pipeline/NetworkRequestContext.swift`
- Modify: `AppTemplate/App/Networking/Pipeline/NetworkEventMonitor.swift`
- Modify: `AppTemplate/App/Networking/NetworkProvider.swift`
- Modify: `AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderTests.swift`
- Modify: `AppTemplateTests/App/Networking/NetworkProviderStubTests.swift`

**Interfaces:**

- Produces:

```swift
nonisolated
struct NetworkRequestContext: Sendable {
    let id: UUID
    let request: URLRequest
}

nonisolated
protocol NetworkEventMonitor: Sendable {
    func willSend(
        context: NetworkRequestContext,
        target: any NetworkTarget
    ) async

    func didComplete(
        context: NetworkRequestContext,
        result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async
}
```

- Guarantees: provider creates one fresh context after all adapters, then passes that same context to each monitor's start and completion callbacks in registration order.

- [ ] **Step 1: Replace the recorder with the context-aware test API**

In `NetworkEventRecorder.swift`, retain `RecordedNetworkEvent` and replace the recorder/monitor implementation with this complete addition (keep the existing `RecordedNetworkOutcome` switch cases):

```swift
nonisolated enum RecordedNetworkPhase: Equatable, Sendable {
    case willSend
    case didComplete
}

nonisolated struct RecordedNetworkContextEvent: Sendable {
    let monitor: String
    let phase: RecordedNetworkPhase
    let requestID: UUID
    let request: URLRequest
}

actor NetworkEventRecorder {
    private var events: [RecordedNetworkEvent] = []
    private var contextEvents: [RecordedNetworkContextEvent] = []

    func append(
        _ event: RecordedNetworkEvent,
        monitor: String,
        phase: RecordedNetworkPhase,
        context: NetworkRequestContext
    ) {
        events.append(event)
        contextEvents.append(.init(
            monitor: monitor,
            phase: phase,
            requestID: context.id,
            request: context.request
        ))
    }

    func recordedEvents() -> [RecordedNetworkEvent] { events }
    func recordedContextEvents() -> [RecordedNetworkContextEvent] { contextEvents }
}
```

Change `RecordingNetworkEventMonitor.willSend` to call `await recorder.append(.willSend(monitor: name), monitor: name, phase: .willSend, context: context)`. Change `didComplete` to preserve its existing outcome switch, then call `append(.didComplete(monitor: name, outcome: outcome), monitor: name, phase: .didComplete, context: context)`.

- [ ] **Step 2: Add concrete context RED tests**

Add these tests to `NetworkProviderTests.swift`:

```swift
@Test
func liveLifecycleContextContainsFinalAdaptedRequestAndOneID() async throws {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: makeHTTPTransport(statusCode: 200),
        adapters: [AppendingHeaderAdapter(value: "final")],
        monitors: [RecordingNetworkEventMonitor(name: "live", recorder: recorder)]
    )
    _ = try await provider.request(ProviderTarget())

    let events = (await recorder.recordedContextEvents()).filter { $0.monitor == "live" }
    try #require(events.count == 2)
    #expect(events.map(\.phase) == [.willSend, .didComplete])
    #expect(events[0].requestID == events[1].requestID)
    #expect(events[0].request.value(forHTTPHeaderField: "X-Adapter-Order") == "final")
    #expect(events[1].request == events[0].request)
}

@Test
func failureLifecycleContextUsesTheSameID() async throws {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: InMemoryNetworkTransport { _ in throw ProviderFixtureError.offline },
        monitors: [RecordingNetworkEventMonitor(name: "failure", recorder: recorder)]
    )
    _ = try? await provider.request(ProviderTarget())

    let events = (await recorder.recordedContextEvents()).filter { $0.monitor == "failure" }
    try #require(events.count == 2)
    #expect(events.map(\.phase) == [.willSend, .didComplete])
    #expect(events[0].requestID == events[1].requestID)
}

@Test
func concurrentIdenticalTargetsHaveFullyPairedDistinctContextIDs() async throws {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<ProviderTarget>(
        transport: makeHTTPTransport(statusCode: 200),
        monitors: [RecordingNetworkEventMonitor(name: "concurrent", recorder: recorder)]
    )
    async let first = provider.request(ProviderTarget())
    async let second = provider.request(ProviderTarget())
    _ = try await (first, second)

    let events = (await recorder.recordedContextEvents()).filter { $0.monitor == "concurrent" }
    let starts = events.filter { $0.phase == .willSend }.map(\.requestID)
    let completions = events.filter { $0.phase == .didComplete }.map(\.requestID)
    #expect(starts.count == 2)
    #expect(completions.count == 2)
    #expect(Set(starts).count == 2)
    #expect(Set(starts) == Set(completions))
    for id in Set(starts) {
        #expect(starts.filter { $0 == id }.count == 1)
        #expect(completions.filter { $0 == id }.count == 1)
    }
}
```

Add this immediate-stub test to `NetworkProviderStubTests.swift`:

```swift
@Test
func stubLifecycleContextContainsFinalAdaptedRequestAndOneID() async throws {
    let recorder = NetworkEventRecorder()
    let provider = NetworkProvider<StubTarget>(
        transport: unexpectedTransport(),
        adapters: [StubHeaderAdapter()],
        monitors: [RecordingNetworkEventMonitor(name: "stub", recorder: recorder)],
        stubBehavior: { _ in .immediate }
    )
    _ = try await provider.request(StubTarget())

    let events = (await recorder.recordedContextEvents()).filter { $0.monitor == "stub" }
    try #require(events.count == 2)
    #expect(events.map(\.phase) == [.willSend, .didComplete])
    #expect(events[0].requestID == events[1].requestID)
    #expect(events[0].request.value(forHTTPHeaderField: "X-Stub-Adapter") == "applied")
    #expect(events[1].request == events[0].request)
}
```

- [ ] **Step 3: Run the context RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkContext-Red \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests
```

Expected: compilation fails because `NetworkEventMonitor` still accepts bare request/result values rather than the required context labels.

- [ ] **Step 4: Create and propagate one immutable context**

Create `NetworkRequestContext.swift` with `import Foundation` and the interface above. After adaptation succeeds, create one value before any monitor callback:

```swift
let context = NetworkRequestContext(id: UUID(), request: request)

for monitor in monitors {
    await monitor.willSend(context: context, target: target)
}

let result = await result(for: request, target: target)

for monitor in monitors {
    await monitor.didComplete(context: context, result: result, target: target)
}
```

Update protocol defaults and every monitor implementation to the exact labeled signatures. Add a protocol comment stating callbacks are sequential, read-only, and responsible for internally enqueuing expensive telemetry.

- [ ] **Step 5: Run the context GREEN gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkContext-Green \
  -only-testing:AppTemplateTests/HTTPHeadersTests \
  -only-testing:AppTemplateTests/NetworkRequestBuilderTests \
  -only-testing:AppTemplateTests/NetworkResponseTests \
  -only-testing:AppTemplateTests/NetworkProviderTests \
  -only-testing:AppTemplateTests/NetworkProviderStubTests \
  -only-testing:AppTemplateTests/RemoteServiceTests
```

Expected: selected tests pass; context requests include final adapter changes, failure and success lifecycles pair correctly, and concurrent IDs are unique and fully paired.

- [ ] **Step 6: Commit lifecycle correlation**

```bash
git add AppTemplate/App/Networking/Pipeline \
  AppTemplate/App/Networking/NetworkProvider.swift \
  AppTemplateTests/TestSupport/Networking/NetworkEventRecorder.swift \
  AppTemplateTests/App/Networking/NetworkProviderTests.swift \
  AppTemplateTests/App/Networking/NetworkProviderStubTests.swift
git commit -m "feat: correlate network monitor lifecycles"
```

---

### Task 7: Document the Contract and Run Final Verification

**Files:**

- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Interfaces:**

- Consumes: the signed entitlement, URL, header, executor, cancellation, and monitor contracts from Tasks 1–6, plus the implemented and locally verified macOS UI-test window-isolation plan.
- Produces: user-facing project guidance and exact local verification evidence matching the final combined implementation.

- [ ] **Step 1: Update architecture and customization guidance**

In `docs/ARCHITECTURE.md`, document that request construction snapshots target inputs once; empty paths and encoded base queries are preserved; `HTTPHeaders` has validated ASCII-token names, case-insensitive single-value replacement, canonical application order, spelling-insensitive equality, and defensive live-response mapping; `request(_:)` is `@concurrent`; cancellation is checked after `willSend` and after delayed sleep; and one final adapted `NetworkRequestContext` correlates sequential monitor events.

In `docs/CUSTOMIZATION.md`, retain the prohibition on injecting providers into ViewModels. State that production composition injects a long-lived, explicitly configured `URLSession` into `URLSessionTransport` for timeout, cache, cookie, connectivity, redirect, or trust needs. State that redirects are validated at the terminal response under the session redirect policy, and that monitor implementations must return quickly and queue expensive telemetry internally.

- [ ] **Step 2: Run static scope checks**

```bash
git diff --check

if rg -n 'import (Alamofire|Combine|RxSwift|ReactiveSwift)' \
  AppTemplate/App/Networking AppTemplate/App/Services/Remote; then
  exit 1
fi
```

Expected: `git diff --check` exits zero and the import scan finds no matches.

- [ ] **Step 3: Run the three zero-exit unit-only platform gates**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-NetworkHardening-unit-macOS \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -derivedDataPath /tmp/AppTemplate-NetworkHardening-unit-iPhone17 \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -derivedDataPath /tmp/AppTemplate-NetworkHardening-unit-iPadA16 \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: all three commands exit zero. Each selects only `AppTemplateTests`, uses a separate DerivedData directory, and treats Swift and Clang warnings as errors.

- [ ] **Step 4: Re-run the Debug/Release effective-settings and entitlement gate**

Run the safe local script from Task 1 Step 3 unchanged, producing a fresh inspected directory. It must re-check effective app and test-target settings before each signed build as well as the three signed-entitlement predicates.

Expected: Debug and Release settings prove app sandbox/client networking is enabled, app server networking is not enabled, and neither networking capability is enabled on `AppTemplateTests` or `AppTemplateUITests`. Both signed products prove sandbox/client entitlement presence and server entitlement absence.

- [ ] **Step 5: Run the zero-exit full macOS scheme gate**

```bash
set -euo pipefail

verification_root="$(mktemp -d /tmp/AppTemplate-NetworkHardening-final-macOS.XXXXXX)"
test -d "$verification_root"
test ! -L "$verification_root"
case "$verification_root" in
  /tmp/AppTemplate-NetworkHardening-final-macOS.*) ;;
  *) exit 1 ;;
esac

derived_data="$verification_root/DerivedData"
result_bundle="$verification_root/full-macOS.xcresult"
test ! -e "$derived_data"
test ! -e "$result_bundle"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

test -d "$result_bundle"
```

Do not delete `verification_root` as part of this command; it is a uniquely created, inspectable local artifact.

Expected: the complete macOS scheme, including unit and UI tests, exits zero with warnings treated as errors. Any nonzero `xcodebuild` result fails Task 7; no former UI failure is allowlisted or reclassified as diagnostic.

- [ ] **Step 6: Confirm local verification scope and commit documentation**

Commit the documentation-only changes:

```bash
git add docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md
git commit -m "docs: describe hardened network contract"
```

---

## Self-Review

- Entitlement coverage: Task 1 enables only app-target client networking in Debug and Release; local effective-setting and signed-product gates check the app and both test targets, and assert sandbox/client/server properties on two signed products.
- URL coverage: Task 2 covers empty paths, raw encoded base query preservation, and all five target-property snapshots.
- Header coverage: Task 3 executable tests cover the shared token validator, invalid lookup, trusted valid writes, ordered replacement, canonical ordering, custom equality, request/stub/response migration, non-string live-value stringification, and deterministic untrusted response collision handling. The trusted invalid-name precondition is an explicitly inspected invariant shared by dictionary-literal initialization and `set`, not a directly crash-tested branch.
- Executor and cancellation coverage: Tasks 4 and 5 are independent commits. The executor gate measures MainActor liveness rather than thread identity; cancellation tests use cancellable children, all stub behaviors, post-sleep cancellation, and construction/adaptation precedence.
- Monitor coverage: Task 6 uses exact context labels, post-adaptation final request snapshots, sequential callbacks, live/stub/failure correlation, and fully paired concurrent IDs.
- Verification coverage: after Network Tasks 1–6 and the separately approved UI-isolation plan are implemented, Task 7 provides three local unit-only zero-exit platform gates, Debug/Release local effective-setting and signed-product gates, and a uniquely isolated complete macOS scheme gate requiring exit zero.
