# Network Layer Hardening Design Addendum

**Date:** 2026-08-09

**Status:** Approved

**Supersedes:** The conflicting request-header, response-header, monitor, and
provider-execution details in
`2026-08-05-urlsession-network-layer-design.md`. All other decisions in the
approved design remain unchanged.

## Context

The implemented URLSession networking layer follows the approved architecture,
but project and code review found several correctness and runtime gaps:

- the sandboxed macOS application is not entitled to make outgoing network
  connections;
- request construction can add a trailing slash to an empty target path,
  rewrite an already percent-encoded base query, and observe different values
  from a computed target task;
- `[String: String]` does not model HTTP field-name case insensitivity and can
  apply case-variant duplicates nondeterministically;
- provider setup inherits the caller's actor executor despite the design goal
  of keeping request work off the UI isolation domain;
- a task already marked as cancelled can still start live transport or return
  a stubbed success;
- terminal monitor events do not carry the final request or a lifecycle ID, so
  concurrent identical targets cannot be correlated reliably.

This addendum hardens the existing boundaries rather than replacing them. It is
based only on review and testing of AppTemplate. It introduces no Moya,
Alamofire, other third-party networking dependency, or behavior copied from the
referenced Medium article.

## Goals

- Make live URLSession requests possible in the sandboxed macOS app.
- Preserve the caller's exact base URL and raw encoded query where required.
- Give request and response headers deterministic, case-insensitive semantics.
- Keep synchronous provider setup away from a caller actor such as MainActor.
- Make cancellation observable before live or stub work begins.
- Correlate every monitored request lifecycle, including failures and stubs.
- Preserve the existing target → builder → adapter → monitor → transport and
  domain-service architecture.

## Non-goals

- Redirect-policy changes, retries, token refresh, caching, reachability, or
  request deduplication.
- A multi-value HTTP header collection or lossless repeated-field model.
- Fire-and-forget or concurrently invoked monitor callbacks.
- A new public networking abstraction, a third-party dependency, or API
  compatibility with another networking library.
- Fixing unrelated application UI-test failures discovered in the baseline.

## Design decisions

### 1. macOS client-network entitlement

The AppTemplate application target will set
`ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` in both Debug and Release. The
existing sandbox remains enabled and incoming network connections remain
disabled. Test targets do not receive the capability, and no manually managed
entitlements file is introduced.

Build verification will inspect the signed Debug and Release macOS products and
assert all three properties:

- `com.apple.security.app-sandbox` is `true`;
- `com.apple.security.network.client` is `true`;
- `com.apple.security.network.server` is absent.

CI will add a `macos-entitlements` job using Xcode 26.6. Its executable contract
is two separate builds and assertions equivalent to:

```bash
set -euo pipefail

xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$RUNNER_TEMP/DerivedData-entitlements-Debug" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

DEBUG_APP="$RUNNER_TEMP/DerivedData-entitlements-Debug/Build/Products/Debug/AppTemplate.app"
codesign --verify --deep --strict --verbose=2 "$DEBUG_APP"
codesign --display --entitlements - --xml "$DEBUG_APP" 2>/dev/null \
  | plutil -convert json -o - - \
  | jq -e '."com.apple.security.app-sandbox" == true
      and ."com.apple.security.network.client" == true
      and (has("com.apple.security.network.server") | not)'

xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$RUNNER_TEMP/DerivedData-entitlements-Release" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

RELEASE_APP="$RUNNER_TEMP/DerivedData-entitlements-Release/Build/Products/Release/AppTemplate.app"
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
codesign --display --entitlements - --xml "$RELEASE_APP" 2>/dev/null \
  | plutil -convert json -o - - \
  | jq -e '."com.apple.security.app-sandbox" == true
      and ."com.apple.security.network.client" == true
      and (has("com.apple.security.network.server") | not)'
```

A locally ad-hoc-signed Release product proves the embedded entitlements for
this change; it is not evidence of distribution signing, notarization, or
Gatekeeper acceptance.

### 2. deterministic request snapshots and URL composition

`NetworkRequestBuilder.build` will snapshot `baseURL`, `path`, `method`,
`task`, and `headers` once before construction. All later work uses that
snapshot. In particular, a computed `task` property is evaluated exactly once.

An empty path leaves the base URL unchanged, including the absence of a trailing
slash. A non-empty path continues to use Foundation's path-appending behavior.

When query items are added to a base URL, the builder preserves the base URL's
existing `percentEncodedQuery` bytes. It encodes only the target's new
`URLQueryItem` values with a temporary `URLComponents` value, then joins the two
encoded query strings with `&`. The builder does not decode and re-encode the
existing base query.

### 3. deterministic, case-insensitive `HTTPHeaders`

The networking layer will replace its internal `[String: String]` request and
response header contracts with a `Sendable`, `Equatable`,
`ExpressibleByDictionaryLiteral` value named `HTTPHeaders`.

Header field names must be non-empty ASCII HTTP token strings. Canonicalization
changes only `A...Z` to `a...z`; every other allowed token byte is unchanged.
Besides ASCII letters and digits, the permitted token bytes are:

```text
! # $ % & ' * + - . ^ _ ` | ~
```

Request and stub construction treat an invalid or non-ASCII name as a
programmer error and fail a precondition. Live response mapping ignores a
non-string or invalid field name rather than allowing remote input to trigger a
precondition.

Storage is keyed by the canonical field name while retaining one presentation
spelling for Foundation interoperation. Setting a field replaces the previous
value for the same case-insensitive name; deterministic last-write-wins applies
to ordered dictionary literals and explicit mutation.

There will be no initializer from `[String: String]`, because a Swift
dictionary cannot define a deterministic winner for case-variant duplicates.
The collection exposes fields in canonical-key order when applying them to a
`URLRequest`.

The testable module API is:

```swift
nonisolated
struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral {
    nonisolated
    struct Field: Sendable, Equatable {
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

Invalid lookup returns `nil`; `set` and dictionary-literal construction enforce
the trusted-input precondition. `fields` is sorted by canonical name. The live
response mapper calls `isValidFieldName` before `set`.

`HTTPHeaders` implements a custom `==` that compares canonical field names and
values while ignoring retained presentation spelling; synthesized equality is
not used. Therefore `Content-Type: application/json` equals
`content-type: application/json`.

Live response conversion first keeps only string keys with valid field names,
then stringifies their values. It sorts entries ascending by canonical field
name, original field-name UTF-8 bytes, and stringified value before insertion.
Because insertion is last-write-wins, the lexicographically greatest original
name/value tuple is the exact winner for case-variant duplicates. Stub headers
use the same type and case-insensitive identity. This is a single-value
replacement model: repeated wire-level fields are outside this change and may
already have been combined by Foundation.

This is an intentional source change inside the app target. `NetworkTarget`,
`StubResponse`, `NetworkResponse`, request construction, fixtures, and tests
will migrate together in one branch.

### 4. provider executor semantics

`NetworkProvider.request` will be declared `@concurrent`. This is independent
of cancellation behavior and gives the provider's synchronous build, encoding,
stub mapping, and pipeline setup an executor that does not inherit a caller
actor such as MainActor.

The required runtime test is a MainActor-liveness gate: a request launched from
MainActor enters a synchronously paused encoder factory while a separate
MainActor operation must resume and release it before a bounded timeout. The
test fails under caller-actor inheritance and passes with `@concurrent`. It does
not assert a physical thread identity. `Thread.isMainThread`, if retained as an
Apple-platform smoke observation, is explicitly non-authoritative and is not an
acceptance gate. `RemoteService` remains an actor and all crossed values remain
`Sendable`.

### 5. provider cancellation checkpoints

Once the final adapted request has been emitted through `willSend`, the provider
will check for cancellation before resolving or starting either live transport
or stub execution. Cancellation observed at that checkpoint produces
`NetworkError.cancelled`, skips transport and sample-response success, and
emits the paired terminal monitor event exactly once.

Construction and adaptation still happen before that checkpoint. Their errors
take precedence over a task's pre-existing cancellation and create no monitor
lifecycle, preserving the approved pipeline contract. Cancellation is
normalized to `.cancelled` only after construction and adaptation succeed and
`willSend` has been emitted.

For delayed stubs, the provider checks cancellation again after the injected
sleep returns. This covers injected sleep implementations that do not throw or
otherwise cooperate with task cancellation. A cancellation thrown by the real
sleep or transport continues through the existing normalization path.

The rule is universal across `.never`, `.immediate`, and `.delayed` behaviors:
after `willSend`, an observed cancellation yields exactly one matching
`didComplete`; no successful result is returned after that observation.

Tests cancel a child task rather than the Swift Testing parent task, so the test
runner itself remains uncancelled.

Pre-cancellation tests cover `.never`, `.immediate`, and `.delayed` separately.
Each cancels the child task before `request`, observes no returned response,
asserts that live transport (and delayed sleep where applicable) was not
started, and records exactly one `willSend` plus the matching
`didComplete(.cancelled)`. A separate delayed-stub test cancels after sleep has
started, uses an injected sleep that returns without throwing, and verifies the
post-sleep checkpoint prevents sample-response success.

### 6. correlated monitor lifecycle context

Monitoring will use one immutable context created after all adapters have run:

```swift
nonisolated
struct NetworkRequestContext: Sendable {
    let id: UUID
    let request: URLRequest
}
```

`NetworkRequestContext.swift` imports Foundation. The provider creates exactly
one context per request attempt, containing a fresh ID and the final adapted
request, and passes that same context value to both callbacks:

```swift
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

Monitor callbacks remain awaited sequentially in registration order. They are
read-only observers and must return quickly; implementations performing
expensive telemetry must enqueue that work internally. The provider does not
detach callbacks, reorder them, or allow monitor failures to alter a result.

Tests cover live and stub lifecycles, the final adapted request, success and
failure correlation, and concurrent identical targets. For concurrent targets,
each completion ID must match exactly one start ID, and the two request IDs must
be distinct.

## Delivery order

Changes will be implemented test-first in these independently reviewable
steps:

1. macOS entitlement and signed-product/CI assertions;
2. request snapshot and URL composition;
3. `HTTPHeaders` and all migrated call sites;
4. `@concurrent` executor behavior;
5. universal cancellation checkpoints;
6. correlated `NetworkRequestContext` monitor events;
7. architecture/customization documentation and platform verification.

Each behavior change starts with a test or configuration assertion that fails
for the expected reason. Executor and cancellation work are separate commits so
their effects remain independently reviewable.

## Verification

Targeted Networking tests will run after every step. Required local acceptance
gates use separate Derived Data locations, select only `AppTemplateTests`, and
treat Swift and Clang warnings as errors for the same platform set as CI:

- macOS;
- iPhone 17 simulator with iOS 26.5;
- iPad (A16) simulator with iOS 26.5.

All three `xcodebuild test` commands must exit zero. Debug and Release macOS
builds plus the embedded-entitlement assertions are additional zero-exit gates.
CI retains its existing full-scheme three-platform matrix and must pass before
integration; this change does not weaken that job. CI also gains the Release
macOS entitlement gate described above.

The local full macOS scheme is a separate, non-gating diagnostic because its
baseline currently fails these five UI tests:

- `testBrowseOptionsCanBePresentedAndDismissed`;
- `testBrowseTabShowsBrowseScreen`;
- `testNavigationGuideCanBeOpened`;
- `testOnboardingRootIsVisible`;
- `testSettingsWindowCanBeOpened`.

Its nonzero result is reported explicitly and never described as passing. No
additional failing UI-test identifier is allowed after the Networking changes.
Fixing or suppressing these UI failures is outside this addendum.

## Success criteria

- Signed Debug and Release macOS products have sandboxed client networking and
  no server-network entitlement.
- Empty paths and existing percent-encoded base queries survive construction
  byte-for-byte, and computed target inputs are read once.
- Header lookup, replacement, equality, application, and response mapping are
  deterministic and ASCII case-insensitive; invalid-name behavior matches the
  trusted-construction and untrusted-response rules above.
- Provider setup does not inherit a MainActor caller's executor.
- Pre-existing cancellation prevents both live transport and stub success while
  preserving exactly one terminal monitor event after `willSend`.
- Every monitored lifecycle exposes the final adapted request and one stable,
  unique correlation ID.
- The three unit-test gates, Debug/Release entitlement gates, and full CI matrix
  pass under warnings-as-errors; the separate local UI diagnostic introduces no
  identifier beyond its fixed baseline allowlist.
