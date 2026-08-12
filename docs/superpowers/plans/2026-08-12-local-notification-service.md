# Detailed Local Notification Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a detailed, typed Local Notification Service for iOS, iPadOS, and macOS, including permission/settings APIs, categories and actions, local attachments, Notification Center state management, process events, and deterministic per-scene deep-link navigation.

**Architecture:** A platform-neutral actor service validates public values and speaks to a narrow internal center client; the concrete client and mapper contain every UserNotifications type. One strongly held delegate bridge publishes decoded events through an actor hub, while a separate MainActor coordinator routes valid URLs into the existing per-scene `AppSceneNavigationLifecycle`.

**Tech Stack:** Swift 6.0 language mode, Foundation, UserNotifications, UniformTypeIdentifiers, SwiftUI, narrow AppKit interop on macOS, OSLog, Swift Testing, Xcode 26.6, iOS/iPadOS/macOS 26.0; no third-party dependency.

## Global Constraints

- Treat `docs/superpowers/specs/2026-08-12-local-notification-service-design.md` at commit `bf1d16860a2dc336c0631be3a49ea5164db1ca32` as normative.
- Use `bf1d16860a2dc336c0631be3a49ea5164db1ca32` as the immutable pre-implementation base. The implementation diff excludes the plan document and the existing untracked `graphify-out/` analysis artifact.
- Keep deployment targets at iOS/iPadOS/macOS 26.0, `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and Xcode 26.6.
- Follow RED → confirm intended RED → minimal GREEN → focused regression test → review → commit for every task. A test that passes before its production change is not valid RED evidence.
- Mark every cross-actor public value, protocol, error, mapper DTO, and test fixture explicitly `nonisolated` where MainActor-default isolation requires it.
- Public service files contain no `UN*` type. UserNotifications imports stay under `AppTemplate/App/Services/LocalNotifications/Internal` and the delegate bridge.
- `UNUserNotificationCenter` is the only persisted source of truth for pending and delivered requests. Do not add SwiftData, UserDefaults, Keychain, file, or process-cache schedule persistence.
- Do not add a location trigger, Core Location import, `.timeSensitive`, `.critical`, critical-alert option, Push Notifications capability, entitlement, background remote-notification mode, notification extension, or automatic permission prompt.
- Do not add an HTTP attachment path. Only readable local image/audio/video files are accepted, and the caller's original file is never handed to Notification Center.
- Use physical namespace `AppTemplate.LocalNotification` and return/remove only owned local requests. Never call the unscoped system remove-all methods.
- The delegate bridge is the sole owner of Notification Center callback completion and completes each callback exactly once after enqueueing, without waiting for navigation or Feature work.
- The event hub preserves FIFO order and does not drop events for a live subscription. It is process-local, not durable.
- Navigation goes only through `AppSceneNavigationLifecycle.receive(_:)`. Do not introduce a second router, global navigation path, global `NSWindow` lookup, or mutation of other scenes.
- Logs and errors never reveal notification title/subtitle/body, metadata, URL, user-entered text, physical IDs, named-sound resource names, attachment paths/names/content, raw `userInfo`, envelope bytes, or localized underlying errors.
- Preview and UI-test composition use fresh in-memory services and never touch `UNUserNotificationCenter.current()` or request permission.
- Preserve unrelated AppState, Keychain, UserDefaults, SwiftData, networking, navigation, Feature, and UI-test behavior.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`; filesystem-synchronized groups include new Swift files automatically.
- Use actor barriers/continuations for concurrency tests; do not use sleeps.
- Every focused and final `xcodebuild` invocation uses a new validated `mktemp -d` root, warnings-as-errors, and a unique result bundle.
- Keep commits task-scoped. Never stage `graphify-out/`.

## File Map

### Create: public service boundary

- `AppTemplate/App/Services/LocalNotifications/ILocalNotificationService.swift` — exact platform-neutral async protocol.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationIdentifiers.swift` — validated logical IDs and physical namespace encoding.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationAuthorization.swift` — settings and authorization option models.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationContent.swift` — content, sound, interruption, and foreground presentation.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationTrigger.swift` — immediate/interval/calendar trigger model.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationAttachment.swift` — local attachment and option models.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationCategory.swift` — categories, button actions, and text-input actions.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationMetadata.swift` — recursive JSON-shaped metadata.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationSnapshot.swift` — pending/delivered decoded-or-unreadable snapshots.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEvent.swift` — event and diagnostic models.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationServiceError.swift` — stable redacted errors and reason enums.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationDeepLinkPolicy.swift` — injected platform-neutral URL validity closure.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationValidator.swift` — shared pure validation.

### Create: live/in-memory service and internals

- `AppTemplate/App/Services/LocalNotifications/InMemoryLocalNotificationService.swift` — deterministic actor implementation and internal test hooks.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationService.swift` — live actor orchestration and system truth semantics.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift` — multicast streams and dedicated navigation FIFO.
- `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift` — runtime ownership and live/in-memory factories.
- `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationEnvelope.swift` — version-1 Codable envelope and strict codec.
- `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationSystemModels.swift` — Sendable DTOs between service and system client.
- `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationCenterClient.swift` — internal framework-neutral center protocol.
- `AppTemplate/App/Services/LocalNotifications/Internal/UserNotificationCenterClient.swift` — concrete UserNotifications adapter.
- `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationSystemMapper.swift` — DTO ↔ UserNotifications conversion.
- `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationAttachmentStager.swift` — safe staging-copy lifecycle.
- `AppTemplate/App/Services/LocalNotifications/Internal/NotificationCenterDelegateBridge.swift` — unique system delegate and event decoding.

### Create: navigation integration

- `AppTemplate/App/Navigation/Notifications/LocalNotificationNavigationCoordinator.swift` — MainActor scene registry and pending URL FIFO.
- `AppTemplate/App/Navigation/Notifications/LocalNotificationSceneReceiving.swift` — weak class-bound scene receiver seam.
- `AppTemplate/App/Navigation/Notifications/Platforms/macOS/LocalNotificationWindowActivityProbe.swift` — hosting-window key/resign-key observation only.

### Modify: composition and scenes

- `AppTemplate/App/AppDependencies/AppDependencies.swift` — own/inject `LocalNotificationDependencies`.
- `AppTemplate/App/Entry/AppTemplateApp.swift` — pass notification runtime into each scene.
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift` — bootstrap catalog, register lifecycle, track scene/window eligibility.
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift` — conform to the narrow receiver seam without changing routing behavior.

### Create: tests and support

- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationModelTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationValidationTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEnvelopeTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEventHubTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/InMemoryLocalNotificationServiceTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationSystemMapperTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationAttachmentStagerTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationServiceTests.swift`
- `AppTemplateTests/App/Services/LocalNotifications/NotificationCenterDelegateBridgeTests.swift`
- `AppTemplateTests/App/Navigation/Notifications/LocalNotificationNavigationCoordinatorTests.swift`
- `AppTemplateTests/App/Navigation/Notifications/LocalNotificationWindowActivityProbeTests.swift`
- `AppTemplateTests/TestSupport/LocalNotifications/LocalNotificationFixtures.swift`
- `AppTemplateTests/TestSupport/LocalNotifications/ScriptedLocalNotificationCenterClient.swift`
- Modify `AppTemplateTests/App/Composition/AppDependenciesTests.swift`.
- Modify `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift` only for notification receiver integration proof.

### Modify: active documentation

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CUSTOMIZATION.md`
- `docs/RELEASE_CHECKLIST.md`

---

### Task 1: Define Public Models, IDs, Errors, and Pure Validation

**Files:**

- Create every file listed under “public service boundary”.
- Create `AppTemplateTests/TestSupport/LocalNotifications/LocalNotificationFixtures.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationModelTests.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationValidationTests.swift`.

**Interfaces:**

- Produces the exact `ILocalNotificationService` protocol from the spec.
- Produces all `Hashable`/`Codable`/`Sendable` request, content, trigger, category, metadata, snapshot, event, settings, option, diagnostic, and error types consumed by Tasks 2–11.
- Produces `LocalNotificationNamespace`, with `physicalRequestID(_:)`, `logicalRequestID(_:)`, category/action/attachment equivalents, and strict ownership checks.
- Produces `LocalNotificationValidator` pure functions; it performs no file I/O, parser work, system call, logging, or mutation.
- Produces these test-only helpers in `LocalNotificationFixtures.swift` so later tasks use one stable model construction path:

```swift
enum LocalNotificationFixtures {
    static func request(
        id: String,
        body: String = "Body",
        attachmentURL: URL? = nil
    ) throws -> LocalNotificationRequest

    static func category(
        id: String = "category",
        actions: [LocalNotificationAction] = []
    ) throws -> LocalNotificationCategory

    static func diagnostic(
        _ reason: LocalNotificationDiagnosticReason
    ) throws -> LocalNotificationEvent

    static func threeDiagnostics() throws -> [LocalNotificationEvent]
    static func openedFixture(url: String) throws -> LocalNotificationEvent
}
```

- [ ] **Step 1: Write the public-contract and validation RED**

Create tests that compile these exact usage shapes and assert their semantics:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct LocalNotificationModelTests {
    @Test func identifiersRoundTripThroughThePhysicalNamespace() throws {
        let namespace = try LocalNotificationNamespace("AppTemplate.LocalNotification")
        let logical = try LocalNotificationID("Заказ / 42")
        let physical = namespace.physicalRequestID(logical)

        #expect(physical.hasPrefix("AppTemplate.LocalNotification.request."))
        #expect(namespace.logicalRequestID(physical) == logical)
        #expect(namespace.logicalRequestID("remote.request") == nil)
    }

    @Test func interruptionLevelContainsOnlyApprovedCases() {
        #expect(LocalNotificationInterruptionLevel.allCases == [.passive, .active])
    }

    @Test func authorizationOptionsRejectUnknownBits() {
        let unknown = LocalNotificationAuthorizationOptions(rawValue: 1 << 20)
        #expect(throws: LocalNotificationServiceError.invalidAuthorizationOptions) {
            try LocalNotificationValidator.validate(authorization: unknown)
        }
    }
}

struct LocalNotificationValidationTests {
    @Test func intervalBoundariesAreExact() throws {
        try LocalNotificationValidator.validate(
            trigger: .timeInterval(seconds: 0.001, repeats: false)
        )
        #expect(throws: LocalNotificationServiceError.self) {
            try LocalNotificationValidator.validate(
                trigger: .timeInterval(seconds: 59.999, repeats: true)
            )
        }
        try LocalNotificationValidator.validate(
            trigger: .timeInterval(seconds: 60, repeats: true)
        )
    }

    @Test func metadataRoundTripsWithoutAny() throws {
        let value: LocalNotificationMetadataValue = .object([
            "count": .integer(42),
            "flags": .array([.boolean(true), .null]),
            "ratio": .double(0.5)
        ])
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(LocalNotificationMetadataValue.self, from: data) == value)
    }
}
```

Also cover: 0/128/129-byte IDs, whitespace-only IDs, control characters, Codable initializer bypass attempts, content observability, NUL text, badge/summary/relevance rules, named-sound leaf names, unknown foreground bits, calendar field allowlist plus `nextTriggerDate`, attachment option numbers, category/action uniqueness and ten-action limit.

- [ ] **Step 2: Run the focused suite and confirm RED**

```bash
task_root="$(mktemp -d /tmp/AppTemplate-LocalNotifications-task1-red.XXXXXX)"
test -d "$task_root" && test ! -L "$task_root"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$task_root/DerivedData" \
  -resultBundlePath "$task_root/red.xcresult" \
  -only-testing:AppTemplateTests/LocalNotificationModelTests \
  -only-testing:AppTemplateTests/LocalNotificationValidationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: nonzero exit because the Local Notification public types do not exist.

- [ ] **Step 3: Implement the exact public protocol and closed models**

The protocol must compile with this signature:

```swift
nonisolated
protocol ILocalNotificationService: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool
    func setCategories(_ categories: [LocalNotificationCategory]) async throws
    func schedule(_ request: LocalNotificationRequest) async throws
    func pending() async -> [LocalNotificationPendingSnapshot]
    func delivered() async -> [LocalNotificationDeliveredSnapshot]
    func removePending(_ identifiers: Set<LocalNotificationID>) async
    func removeAllPending() async
    func removeDelivered(_ identifiers: Set<LocalNotificationID>) async
    func removeAllDelivered() async
    func setBadgeCount(_ count: Int) async throws
    func clearBadge() async throws
    func events() async -> AsyncStream<LocalNotificationEvent>
}
```

Use custom Codable implementations for validated IDs and OptionSets so decoding cannot bypass validation. Encode metadata as a tagged recursive enum with `String`, `Int64`, finite `Double`, `Bool`, arrays, objects, and null. Implement base64url as standard Base64 with `+`→`-`, `/`→`_`, and removed `=` padding; strict decoding restores only required padding and rejects a noncanonical re-encode.

- [ ] **Step 4: Run the focused suite and confirm GREEN**

Run the Step 2 command with a fresh root and `green.xcresult`. Expected: both suites pass with warnings-as-errors.

- [ ] **Step 5: Run exclusion guards**

```bash
! rg -n 'UN[A-Z]|UserNotifications|CoreLocation|timeSensitive|critical' \
  AppTemplate/App/Services/LocalNotifications \
  -g '!**/Internal/**'
```

Expected: no framework type or excluded capability in the public boundary. The literal exclusion-case test names may appear only in tests.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationModelTests.swift \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationValidationTests.swift \
  AppTemplateTests/TestSupport/LocalNotifications/LocalNotificationFixtures.swift
git commit -m "feat: define local notification contract"
```

---

### Task 2: Add Deep-Link Policy and Versioned Envelope

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationEnvelope.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEnvelopeTests.swift`.

**Interfaces:**

- Consumes validated public IDs, sound, metadata, foreground options, category/action routes, and `LocalNotificationDeepLinkPolicy` from Task 1.
- Produces `LocalNotificationEnvelopeV1`, `LocalNotificationDecodedEnvelope`, and `LocalNotificationEnvelopeCodec.encode/decode`.
- The envelope contains schema version 1, logical request/category IDs, sound specification, metadata, request deep link, foreground options, and immutable action-route snapshots. It contains no visible alert text or original attachment URL.

- [ ] **Step 1: Write envelope and deep-link RED tests**

Define this private factory in the envelope test so every field is explicit:

```swift
private extension LocalNotificationEnvelopeV1 {
    static func fixture(
        requestID: LocalNotificationID,
        sound: LocalNotificationSound,
        deepLink: URL?
    ) -> Self {
        Self(
            requestID: requestID,
            categoryID: nil,
            sound: sound,
            metadata: [:],
            defaultDeepLink: deepLink,
            foregroundPresentation: [.banner, .list],
            actionRoutes: []
        )
    }
}
```

```swift
@Test func envelopeRoundTripsAllServiceOwnedState() throws {
    let envelope = LocalNotificationEnvelopeV1.fixture(
        requestID: try .init("request"),
        sound: .named("reminder.aiff"),
        deepLink: URL(string: "apptemplate://projects/project/p1")!
    )
    let data = try LocalNotificationEnvelopeCodec.encode(envelope)
    #expect(try LocalNotificationEnvelopeCodec.decode(data) == .v1(envelope))
    #expect(!String(decoding: data, as: UTF8.self).contains("VISIBLE-TITLE"))
    #expect(!String(decoding: data, as: UTF8.self).contains("/private/source.mov"))
}

@Test func futureVersionIsTypedAndRedacted() {
    let future = Data(#"{"schemaVersion":99}"#.utf8)
    #expect(throws: LocalNotificationServiceError.unsupportedEnvelopeVersion(99)) {
        try LocalNotificationEnvelopeCodec.decode(future)
    }
}
```

Add missing, corrupt, ID-mismatch, noncanonical physical-ID, action-route, text-action route, and invalid deep-link policy cases.

- [ ] **Step 2: Run the focused RED**

Run the Task 1 xcodebuild template with only `LocalNotificationEnvelopeTests`. Expected: compile failure because the envelope codec is absent.

- [ ] **Step 3: Implement deterministic JSON envelope version 1**

Use a private wire enum with a mandatory `schemaVersion` field and `JSONEncoder`/`JSONDecoder` instances created per call. Decode the version discriminator before the full body. Validate decoded URLs through the injected policy and compare the logical ID in the envelope with the decoded physical request ID before returning a managed payload.

- [ ] **Step 4: Run focused GREEN and redaction assertions**

Run the focused suite with a fresh root. Expected: all envelope tests pass and rendered public errors contain none of the sentinel title, path, URL, metadata, or sound strings.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationEnvelope.swift \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEnvelopeTests.swift
git commit -m "feat: add local notification envelope"
```

---

### Task 3: Build Ordered Multicast Event Hub

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEventHubTests.swift`.

**Interfaces:**

- Produces actor methods `events() -> AsyncStream<LocalNotificationEvent>` and
  `publish(_:)`, plus immutable `nonisolated let navigationEvents:
  AsyncStream<LocalNotificationEvent>`.
- Produces internal `LocalNotificationEvent.navigationCandidate: URL?`, non-`nil`
  only for default-open, custom-action, or text-action events carrying a URL.
- The event-hub initializer synchronously creates the one dedicated navigation
  stream and retains its continuation before any delegate can be installed.
- Public streams and the navigation stream are unbounded FIFO streams.
  Termination removes public continuations.

- [ ] **Step 1: Write deterministic FIFO/multicast RED**

```swift
@Test(.timeLimit(.minutes(1)))
func twoSubscribersReceiveTheSameEventsInOrder() async throws {
    let hub = LocalNotificationEventHub()
    let first = await hub.events()
    let second = await hub.events()
    let expected = try LocalNotificationFixtures.threeDiagnostics()

    let firstTask = Task { await Array(first.prefix(expected.count)) }
    let secondTask = Task { await Array(second.prefix(expected.count)) }
    for event in expected { await hub.publish(event) }

    #expect(await firstTask.value == expected)
    #expect(await secondTask.value == expected)
}
```

Add navigation FIFO before/after consumer iteration begins, cancellation
cleanup, late-public-subscriber, and 100-event no-drop tests. Use an actor probe
rather than a sleep.

- [ ] **Step 2: Run focused RED**

Expected: compile failure because `LocalNotificationEventHub` is absent.

- [ ] **Step 3: Implement actor-owned continuations**

Create the navigation `AsyncStream.makeStream()` pair in the event-hub
initializer and expose only its immutable stream. Create each public stream and
install `onTermination` before returning it. `publish(_:)` assigns a
monotonically increasing internal sequence, yields only route-bearing events to
the retained navigation continuation, then yields every event to a stable
snapshot of public continuations, and never awaits consumer work.

- [ ] **Step 4: Run focused GREEN**

Expected: FIFO, multicast, cancellation, and 100-event tests pass without sleeps.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/LocalNotificationEventHub.swift \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationEventHubTests.swift
git commit -m "feat: add local notification event hub"
```

---

### Task 4: Implement the In-Memory Service

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/InMemoryLocalNotificationService.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/InMemoryLocalNotificationServiceTests.swift`.

**Interfaces:**

- Consumes the shared validator, deep-link policy, and event hub.
- Produces an actor conforming to every `ILocalNotificationService` requirement.
- Internal test hooks are `deliverForTesting(id:at:)`, `publishForTesting(_:)`, `registeredCategoriesForTesting()`, and `badgeCountForTesting()`; they are not protocol requirements.

- [ ] **Step 1: Write full contract RED**

Test settings without prompting, configurable authorization, category replacement, unknown-category scheduling rejection, same-ID replacement, deterministic pending/delivered ordering, point/all removals, badge clear, event publication, cancellation, and isolation between two instances.

Define a private `InMemoryLocalNotificationService.fixture()` test extension
that injects `.notDetermined` settings, an authorization result of `true`, an
empty category catalog, `DeepLinkParser(scheme: "apptemplate")` through
`LocalNotificationDeepLinkPolicy`, and a fresh event hub.

```swift
@Test func sameIdentifierReplacesOnlyPendingRequest() async throws {
    let service = InMemoryLocalNotificationService.fixture()
    let first = try LocalNotificationFixtures.request(id: "same", body: "first")
    let second = try LocalNotificationFixtures.request(id: "same", body: "second")

    try await service.schedule(first)
    try await service.schedule(second)

    let pending = await service.pending()
    #expect(pending.count == 1)
    let payload = try #require(pending.first?.payload)
    guard case let .decoded(request) = payload else {
        Issue.record("Expected a decoded pending request")
        return
    }
    #expect(request.content.body == "second")
}
```

- [ ] **Step 2: Run focused RED**

Expected: compile failure because the in-memory actor is absent.

- [ ] **Step 3: Implement deterministic actor state**

Store pending and delivered values by logical ID, keep the last successfully registered category dictionary, use injected settings/authorization result, and delegate every event subscription/publication to the Task 3 hub. Sort only at read boundaries using the specification order.

- [ ] **Step 4: Run focused GREEN and instance-isolation test**

Expected: all in-memory tests pass; scheduling on one instance leaves the second instance empty.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/InMemoryLocalNotificationService.swift \
  AppTemplateTests/App/Services/LocalNotifications/InMemoryLocalNotificationServiceTests.swift
git commit -m "feat: add in-memory local notifications"
```

---

### Task 5: Define System DTOs and User Notification Center Client

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationSystemModels.swift`.
- Create `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationCenterClient.swift`.
- Create `AppTemplate/App/Services/LocalNotifications/Internal/UserNotificationCenterClient.swift`.
- Create `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationSystemMapper.swift`.
- Create `AppTemplateTests/TestSupport/LocalNotifications/ScriptedLocalNotificationCenterClient.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationSystemMapperTests.swift`.

**Interfaces:**

- Produces framework-neutral, internal, Sendable `LocalNotificationSystemRequest`, `LocalNotificationSystemDelivered`, `LocalNotificationSystemCategory`, `LocalNotificationSystemAttachment`, and trigger/content DTOs.
- Produces `LocalNotificationCenterClient` with settings, authorization, managed-category replacement, add/list/remove, badge, and delegate-install operations.
- Produces `UserNotificationCenterClient` as the only owner of `UNUserNotificationCenter.current()`.
- Produces a scripted actor fake recording every operation and allowing injected results/errors.

- [ ] **Step 1: Write mapper/client RED**

Test exact authorization bits, settings cases including unknown/not-supported, foreground options, passive/active levels, content fields, interval/calendar triggers, categories/actions/text actions, and foreign-category preservation.

Define `UserNotificationCenterAPISpy` and the `.foreign`/`.fixture` category
factories as private test-only declarations in
`LocalNotificationSystemMapperTests.swift`; the spy stores category identifiers
in an actor and never resolves `UNUserNotificationCenter.current()`.

```swift
@Test func managedCategoryReplacementPreservesForeignCategories() async throws {
    let api = UserNotificationCenterAPISpy(
        categories: [.foreign(identifier: "remote.category")]
    )
    let client = UserNotificationCenterClient(api: api)
    try await client.replaceManagedCategories(
        prefix: "AppTemplate.LocalNotification.category.",
        categories: [.fixture(identifier: "AppTemplate.LocalNotification.category.bG9jYWw")]
    )
    #expect(await api.lastCategoryIdentifiers() == [
        "AppTemplate.LocalNotification.category.bG9jYWw",
        "remote.category"
    ])
}
```

- [ ] **Step 2: Run focused RED**

Expected: compile failure for missing client/DTO/mapper types.

- [ ] **Step 3: Implement the internal client seam and pure mappings**

The service-facing protocol is framework-neutral:

```swift
nonisolated
protocol LocalNotificationCenterClient: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) async throws -> Bool
    func replaceManagedCategories(prefix: String, categories: [LocalNotificationSystemCategory]) async throws
    func add(_ request: LocalNotificationSystemRequest) async throws
    func pending() async -> [LocalNotificationSystemRequest]
    func delivered() async -> [LocalNotificationSystemDelivered]
    func removePending(_ physicalIDs: Set<String>) async
    func removeDelivered(_ physicalIDs: Set<String>) async
    func setBadgeCount(_ count: Int) async throws
}
```

The concrete adapter maps UserNotifications values before they leave its boundary. `replaceManagedCategories` fetches the raw current set, removes only identifiers with the managed prefix, unions the new mapped set with raw foreign categories, and calls the system setter once.

- [ ] **Step 4: Run focused GREEN**

Expected: mapper/client tests pass without accessing the shared real center.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/Internal \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationSystemMapperTests.swift \
  AppTemplateTests/TestSupport/LocalNotifications/ScriptedLocalNotificationCenterClient.swift
git commit -m "feat: add notification center adapter"
```

---

### Task 6: Stage Local Attachments Safely

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationAttachmentStager.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationAttachmentStagerTests.swift`.

**Interfaces:**

- Produces `LocalNotificationAttachmentStager.stage(_:,requestID:)` returning disposable staged descriptors and `cleanup(_:)`.
- Produces internal `LocalNotificationMediaTypeResolving` with
  `func mediaKind(for:fileTypeHint:) -> LocalNotificationMediaKind?` and the
  live UniformTypeIdentifiers implementation.
- Uses injected `FileManager`, temporary-root factory, and media-type resolver so tests never write outside a validated unique temp root.
- Never passes the original URL to `LocalNotificationSystemRequest`.

- [ ] **Step 1: Write file-lifecycle RED**

```swift
@Test func stagingCopiesAndNeverMovesTheSource() throws {
    let fixture = try AttachmentFileFixture(extension: "png", bytes: [0x89, 0x50, 0x4E, 0x47])
    let stager = LocalNotificationAttachmentStager.temporary(root: fixture.stagingRoot)
    let attachment = try LocalNotificationAttachment(
        id: .init("hero"),
        fileURL: fixture.sourceURL,
        options: .init(typeHint: "public.png")
    )

    let staged = try stager.stage([attachment], requestID: .init("request"))
    #expect(staged.count == 1)
    let stagedAttachment = try #require(staged.first)

    #expect(FileManager.default.fileExists(atPath: fixture.sourceURL.path))
    #expect(try Data(contentsOf: fixture.sourceURL) == Data([0x89, 0x50, 0x4E, 0x47]))
    #expect(stagedAttachment.url != fixture.sourceURL)
}
```

Define `AttachmentFileFixture` privately in the test file. It creates validated
source/staging directories with `FileManager` temporary-directory APIs. Its real
format fixture decodes the fixed one-pixel PNG Base64 string
`iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nYQAAAAASUVORK5CYII=`.
Use an injected `LocalNotificationMediaTypeResolving` test double to exercise
audio/movie conformance without pretending arbitrary bytes form valid media;
real audio/video system acceptance remains in the signed-build smoke gate. Add
non-file, missing, directory, symlink, unreadable, unsupported media, duplicate
ID, invalid clipping/time, security-scope balance, partial-copy failure cleanup,
cancellation cleanup, and explicit cleanup tests.

- [ ] **Step 2: Run focused RED**

Expected: compile failure because the stager is absent.

- [ ] **Step 3: Implement validated staging copies**

Resolve symlinks without traversing them, require a readable regular file, validate image/audio/movie conformance with UniformTypeIdentifiers, enter/exit security scope in `defer`, create one unique per-request directory, and copy each source to a generated non-user-derived filename with its safe extension. On any failure, clean only that validated staging directory and preserve all source files.

- [ ] **Step 4: Run focused GREEN**

Expected: all stager tests pass and every source file remains byte-for-byte present.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/Internal/LocalNotificationAttachmentStager.swift \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationAttachmentStagerTests.swift
git commit -m "feat: stage local notification attachments"
```

---

### Task 7: Implement the Live Service Actor

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/LocalNotificationService.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/LocalNotificationServiceTests.swift`.

**Interfaces:**

- Consumes namespace, validator, policy, envelope codec, stager, event hub, system mapper DTOs, and `LocalNotificationCenterClient`.
- Produces the live actor conforming to `ILocalNotificationService`.
- Produces internal idempotent `bootstrapCategoriesIfNeeded()` used by composition and by `schedule(_:)`.

- [ ] **Step 1: Write service orchestration RED**

Cover: settings without auth call, authorization mapping/error/cancellation, atomic category validation, idempotent bootstrap, schedule ordering, no add on validation/stage/encode failure, same-ID add without pre-removal, unknown category, pending/delivered filtering and unreadable records, deterministic sort, owned-only removals, badge validation, and system-error redaction.

Define private test factories in `LocalNotificationServiceTests.swift` for
`LocalNotificationService.fixture(client:)` and in
`ScriptedLocalNotificationCenterClient.swift` for
`LocalNotificationSystemRequest.fixture(logicalID:body:)`. Both factories use
the fixed test namespace `AppTemplate.LocalNotification`, an empty startup
catalog, an app-scheme deep-link policy, a fresh event hub, and a test staging
root; neither resolves the shared center.

```swift
@Test func failedReplacementPreparationLeavesOldRequestUntouched() async throws {
    let client = ScriptedLocalNotificationCenterClient(
        pending: [.fixture(logicalID: "same", body: "old")]
    )
    let service = LocalNotificationService.fixture(client: client)
    let invalid = try LocalNotificationFixtures.request(
        id: "same",
        attachmentURL: URL(string: "https://example.invalid/a.png")!
    )

    await #expect(throws: LocalNotificationServiceError.self) {
        try await service.schedule(invalid)
    }
    #expect(await client.addedRequests().isEmpty)
    #expect(await client.removedPendingIDs().isEmpty)
}
```

- [ ] **Step 2: Run focused RED**

Expected: compile failure because `LocalNotificationService` is absent.

- [ ] **Step 3: Implement the actor state machine**

Implement schedule order exactly as: cancellation → pure validation → category bootstrap → category/action-route snapshot → envelope → attachment staging → system DTO → cancellation → one add → cleanup. Do not pre-remove the physical ID. Translate strict envelope decode failures into unreadable snapshots in list methods. For remove-all, fetch, filter valid owned physical IDs, then invoke only scoped remove methods.

- [ ] **Step 4: Run focused GREEN plus all LocalNotification service tests**

Use a fresh root and run `LocalNotificationServiceTests`, `InMemoryLocalNotificationServiceTests`, envelope, stager, mapper, validation, and model suites. Expected: all pass without a real permission prompt or shared-center mutation.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/LocalNotificationService.swift \
  AppTemplateTests/App/Services/LocalNotifications/LocalNotificationServiceTests.swift
git commit -m "feat: implement local notification service"
```

---

### Task 8: Install the Delegate Bridge and Decode Interaction Events

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/Internal/NotificationCenterDelegateBridge.swift`.
- Create `AppTemplateTests/App/Services/LocalNotifications/NotificationCenterDelegateBridgeTests.swift`.
- Modify `AppTemplate/App/Services/LocalNotifications/Internal/UserNotificationCenterClient.swift` only to expose delegate installation through the runtime factory.

**Interfaces:**

- Produces one strongly held `NSObject & UNUserNotificationCenterDelegate` bridge.
- Internal testable methods accept `LocalNotificationSystemDelivery` and `LocalNotificationSystemResponse` DTOs, then publish an event and invoke a once-only completion token.
- Produces an injected unmanaged handler that returns a foreground decision or awaits response work but never receives the raw completion closure.

- [ ] **Step 1: Write delegate behavior RED**

Test foreground options, default open, dismiss, custom action, text action, action-specific URL without request fallback, unreadable envelope diagnostic, invalid URL, category mismatch, unknown action, unmanaged fallback, typed text, and every success/failure branch completing exactly once.

```swift
@Test func textActionPublishesTextButDoesNotPersistOrLogIt() async throws {
    let hub = LocalNotificationEventHub()
    let stream = await hub.events()
    let bridge = NotificationCenterDelegateBridge.fixture(eventHub: hub)
    let completion = CompletionCounter()

    await bridge.processResponse(
        .textFixture(actionID: "reply", text: "PRIVATE-REPLY"),
        completion: { completion.call() }
    )

    let event = try await firstEvent(from: stream)
    guard case let .textAction(_, _, text, _) = event else {
        Issue.record("Expected text-action event")
        return
    }
    #expect(text == "PRIVATE-REPLY")
    #expect(completion.count == 1)
}
```

Define the synchronized `CompletionCounter`, `firstEvent(from:)`, and response
DTO factories privately in `NotificationCenterDelegateBridgeTests.swift`.

- [ ] **Step 2: Run focused RED**

Expected: compile failure because the delegate bridge is absent.

- [ ] **Step 3: Implement delegate adaptation and once-only completion**

The real `willPresent` and `didReceive` methods immediately reduce framework objects to immutable system DTOs. An owned callback enters a Task that awaits only `eventHub.publish`, then completes. Foreground unreadable state returns no presentation options. Unmanaged callbacks delegate policy but retain completion ownership in the bridge.

- [ ] **Step 4: Run focused GREEN and completion mutation probe**

Temporarily remove the once-only guard and verify at least one duplicate-completion test fails; restore it and rerun GREEN. Keep only the restored production code.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/Internal/NotificationCenterDelegateBridge.swift \
  AppTemplate/App/Services/LocalNotifications/Internal/UserNotificationCenterClient.swift \
  AppTemplateTests/App/Services/LocalNotifications/NotificationCenterDelegateBridgeTests.swift
git commit -m "feat: handle local notification events"
```

---

### Task 9: Route Notification URLs to One Eligible Scene

**Files:**

- Create `AppTemplate/App/Navigation/Notifications/LocalNotificationSceneReceiving.swift`.
- Create `AppTemplate/App/Navigation/Notifications/LocalNotificationNavigationCoordinator.swift`.
- Modify `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`.
- Create `AppTemplateTests/App/Navigation/Notifications/LocalNotificationNavigationCoordinatorTests.swift`.
- Modify `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`.

**Interfaces:**

- Produces `@MainActor protocol LocalNotificationSceneReceiving: AnyObject` with `receiveLocalNotificationURL(_:)`.
- `AppSceneNavigationLifecycle` forwards that call to existing `receive(_:)`; parsing, restoration queue, app-flow deferral, and router behavior remain unchanged.
- Produces coordinator methods `register(id:receiver:)`, `unregister(id:)`, `setEligible(_:id:)`, and `start()`.

- [ ] **Step 1: Write scene-selection/FIFO RED**

```swift
@MainActor
@Test func lastEligibleSceneAloneReceivesTheRoute() async throws {
    let hub = LocalNotificationEventHub()
    let coordinator = LocalNotificationNavigationCoordinator(
        eventHub: hub,
        parser: DeepLinkParser(scheme: "apptemplate")
    )
    let first = SceneReceiverSpy()
    let second = SceneReceiverSpy()
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    coordinator.register(id: firstID, receiver: first)
    coordinator.register(id: secondID, receiver: second)
    coordinator.setEligible(true, id: firstID)
    coordinator.setEligible(true, id: secondID)
    coordinator.start()

    await hub.publish(try LocalNotificationFixtures.openedFixture(url: "apptemplate://settings"))
    await second.waitForCount(1)

    #expect(first.urls.isEmpty)
    #expect(second.urls.map(\.absoluteString) == ["apptemplate://settings"])
}
```

Add no-eligible FIFO, ordered drain, resign, unregister, weak receiver cleanup,
one-event/one-scene, invalid URL/no fallback plus one redacted diagnostic,
foreground/dismiss no navigation, pre-restoration lifecycle queue, and
authentication/maintenance deferral tests.

Define `@MainActor final class SceneReceiverSpy` privately in the coordinator
test. It stores received URLs and resumes actor-isolated continuations when
`waitForCount(_:)` reaches its requested count; it does not poll or sleep.

- [ ] **Step 2: Run focused RED**

Expected: compile failure because the coordinator and receiver seam are absent.

- [ ] **Step 3: Implement MainActor registry and navigation consumer**

Use weak receiver boxes and a monotonically increasing eligibility sequence.
`start()` owns one Task consuming the hub's already-created dedicated
`navigationEvents` stream.
Validate URLs with `DeepLinkParser.parse`; publish one redacted
`.invalidDeepLink` diagnostic for a rejected candidate and perform no fallback
navigation. Append valid URLs to a process FIFO when no receiver is eligible;
drain the full FIFO into the newly latest eligible scene in insertion order.

- [ ] **Step 4: Run focused GREEN plus existing navigation lifecycle suite**

Expected: new coordinator tests and all `AppSceneNavigationLifecycleTests` pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/App/Navigation/Notifications \
  AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift \
  AppTemplateTests/App/Navigation/Notifications/LocalNotificationNavigationCoordinatorTests.swift \
  AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
git commit -m "feat: route notifications per scene"
```

---

### Task 10: Compose Runtime and Track iOS/macOS Scene Eligibility

**Files:**

- Create `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift`.
- Create `AppTemplate/App/Navigation/Notifications/Platforms/macOS/LocalNotificationWindowActivityProbe.swift`.
- Modify `AppTemplate/App/AppDependencies/AppDependencies.swift`.
- Modify `AppTemplate/App/Entry/AppTemplateApp.swift`.
- Modify `AppTemplate/App/Navigation/Containers/AppSceneView.swift`.
- Modify `AppTemplateTests/App/Composition/AppDependenciesTests.swift`.
- Create `AppTemplateTests/App/Navigation/Notifications/LocalNotificationWindowActivityProbeTests.swift`.

**Interfaces:**

- `AppDependencies` gains `let localNotifications: LocalNotificationDependencies` and injectable live/preview/UI-test/test factories.
- Produces this composition shape; the optional bridge is retained strongly but
  remains inaccessible to Features:

```swift
nonisolated
struct LocalNotificationDependencies: Sendable {
    let service: any ILocalNotificationService
    let eventHub: LocalNotificationEventHub
    let navigationCoordinator: LocalNotificationNavigationCoordinator

    private let delegateBridge: NotificationCenterDelegateBridge?
    private let bootstrap: @Sendable () async throws -> Void

    func bootstrapCategoriesIfNeeded() async throws {
        try await bootstrap()
    }
}
```

- The bridge's checked mutable state is actor/lock protected; because
  `NSObject` itself is not Sendable, the final bridge may use one narrowly
  reviewed `@unchecked Sendable` conformance. No public model, service actor,
  coordinator, or other production type may use unchecked Sendable.
- Live dependencies synchronously create the hub and its navigation stream,
  create/start the coordinator, create and strongly retain the bridge, install
  that bridge as the unique delegate, then create the service with an initially
  empty catalog. No Notification Center operation begins before delegate
  installation. The coordinator's MainActor consumer is the only earlier task;
  it has no system interaction and its stream already buffers before iteration.
- Preview/UI-test dependencies create fresh in-memory service/hub/coordinator and never resolve the shared center.
- Each `AppSceneView` owns a stable registration ID and registers its lifecycle for the view-task lifetime.

- [ ] **Step 1: Write composition and window-probe RED**

Test live type ownership with an injected center client/installer (not the shared center), exact delegate installation count/order, no eager authorization, fresh preview/UI services, bootstrap idempotence, scene unregister, iOS scenePhase eligibility, and macOS hosting-window key/resign-key events.

```swift
@Test func previewGraphsUseFreshInMemoryNotifications() async throws {
    let settings = SettingsDependencies(
        appInfo: AppInfoService(displayName: "Preview", version: "1")
    )
    let first = AppDependencies.preview(settings: settings)
    let second = AppDependencies.preview(settings: settings)
    try await first.localNotifications.service.schedule(.fixture(id: "one"))
    #expect(await second.localNotifications.service.pending().isEmpty)
}
```

- [ ] **Step 2: Run focused RED**

Expected: compile failures for the missing dependencies and probe.

- [ ] **Step 3: Implement runtime factories and scene hooks**

On iOS/iPadOS, observe `@Environment(\.scenePhase)` and call `setEligible(scenePhase == .active,id:)`. On macOS, embed only the narrow probe; its coordinator observes `NSWindow.didBecomeKeyNotification` and `didResignKeyNotification` for its current hosting window, removes old observers on window change/dismantle, and never stores a strong `NSWindow` or reads `NSApp.windows`.

The `AppSceneView` task order is: register lifecycle → await category bootstrap → publish current eligibility → await a locally retained, never-yielding `AsyncStream<Void>` until task cancellation → unregister in `defer`. Construct the stream with `AsyncStream.makeStream()`, retain its continuation in the task scope, finish it in `defer`, and rely on cancelled iteration returning from `next()`. No step requests authorization.

- [ ] **Step 4: Run focused GREEN and platform compile checks**

Run composition/probe tests on macOS, then warnings-as-errors builds for iPhone 17 and iPad (A16). Expected: tests and both builds pass.

- [ ] **Step 5: Run project-mutation guard**

```bash
git diff --exit-code bf1d16860a2dc336c0631be3a49ea5164db1ca32 -- \
  AppTemplate.xcodeproj/project.pbxproj
```

Expected: no project-file mutation.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift \
  AppTemplate/App/Navigation/Notifications/Platforms/macOS/LocalNotificationWindowActivityProbe.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplate/App/Entry/AppTemplateApp.swift \
  AppTemplate/App/Navigation/Containers/AppSceneView.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift \
  AppTemplateTests/App/Navigation/Notifications/LocalNotificationWindowActivityProbeTests.swift
git commit -m "feat: compose local notification runtime"
```

---

### Task 11: Document, Audit, and Run Full Verification

**Files:**

- Modify `README.md`.
- Modify `docs/ARCHITECTURE.md`.
- Modify `docs/CUSTOMIZATION.md`.
- Modify `docs/RELEASE_CHECKLIST.md`.
- Modify only Local Notification production/tests if a verification failure proves a defect.

**Interfaces:**

- Documents namespace adoption, explicit permission timing, category/action setup, deep-link policy, sound packaging, attachment staging/source lifetime, foreground events, multi-window behavior, preview/UI-test injection, and signed-build smoke checks.
- Produces final automated evidence for macOS, iPhone, iPad, Release builds, source guards, privacy redaction, and unchanged project settings.

- [ ] **Step 1: Write documentation assertions before prose**

```bash
for file in README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md; do
  rg -q 'Local Notification' "$file"
done
rg -q 'explicit user action' docs/CUSTOMIZATION.md
rg -q 'last.*active\|last.*key' docs/ARCHITECTURE.md
rg -q 'image.*audio.*video' docs/RELEASE_CHECKLIST.md
```

Expected before editing: at least one assertion fails.

- [ ] **Step 2: Update active documentation**

Describe only implemented behavior. State that successful scheduling is system acceptance, not delivery guarantee; local and remote presentation share app-global authorization/badge/category/delegate resources; source attachments survive because staging copies are used; navigation is process-local and targets only one eligible scene; no location/time-sensitive/critical capability is included.

- [ ] **Step 3: Run source and privacy guards**

```bash
set -euo pipefail
test -z "$(rg -n 'UNLocationNotificationTrigger|CoreLocation' \
  AppTemplate/App/Services/LocalNotifications AppTemplate/App/Navigation/Notifications || true)"
test -z "$(rg -n '\.timeSensitive|\.critical|criticalAlert' \
  AppTemplate/App/Services/LocalNotifications AppTemplate/App/Navigation/Notifications || true)"
test -z "$(rg -n 'removeAllPendingNotificationRequests|removeAllDeliveredNotifications' \
  AppTemplate/App/Services/LocalNotifications || true)"
test -z "$(rg -n 'requestAuthorization' AppTemplate/App/Entry \
  AppTemplate/App/Navigation/Containers || true)"
git diff --exit-code bf1d16860a2dc336c0631be3a49ea5164db1ca32 -- \
  AppTemplate.xcodeproj/project.pbxproj
```

Expected: every guard exits zero.

- [ ] **Step 4: Run complete macOS unit suite**

```bash
mac_root="$(mktemp -d /tmp/AppTemplate-LocalNotifications-final-mac.XXXXXX)"
test -d "$mac_root" && test ! -L "$mac_root"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$mac_root/DerivedData" \
  -resultBundlePath "$mac_root/tests.xcresult" \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 0, nonzero executed count, zero failed/skipped/expected-failure tests.

- [ ] **Step 5: Run complete iPhone and iPad unit suites**

Run the Step 4 command twice with fresh roots and destinations:

```text
platform=iOS Simulator,OS=26.5,name=iPhone 17
platform=iOS Simulator,OS=26.5,name=iPad (A16)
```

Expected: both exit 0 with nonzero executed counts and no failed/skipped/expected-failure tests.

- [ ] **Step 6: Run Release compile/link gates**

Before Release builds, run the complete existing UI suites with fresh roots on
macOS, iPhone 17, and iPad (A16):

```bash
ui_root="$(mktemp -d /tmp/AppTemplate-LocalNotifications-final-ui.XXXXXX)"
test -d "$ui_root" && test ! -L "$ui_root"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$ui_root/DerivedData" \
  -resultBundlePath "$ui_root/macos-ui.xcresult" \
  -only-testing:AppTemplateUITests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Repeat with separate validated roots for
`platform=iOS Simulator,OS=26.5,name=iPhone 17` and
`platform=iOS Simulator,OS=26.5,name=iPad (A16)`. Expected: all three existing
UI suites exit 0. These verify that scene composition changes preserve shipped
UI behavior; they do not claim real notification delivery.

Then run Release compile/link gates:

```bash
mac_release="$(mktemp -d /tmp/AppTemplate-LocalNotifications-release-mac.XXXXXX)"
ios_release="$(mktemp -d /tmp/AppTemplate-LocalNotifications-release-ios.XXXXXX)"
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$mac_release/DerivedData" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$ios_release/DerivedData" CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: both builds exit 0 with zero compiler/analyzer warnings.

- [ ] **Step 7: Record manual signed-build release blockers**

Keep the checklist items unchecked until performed on signed development builds: first permission allow/deny, settings refresh, immediate/interval/calendar delivery, foreground presentation, replacement/cancel, image/audio/video attachment, open/dismiss/button/text actions, cold/warm deep-link launch, inactive FIFO, and two-window macOS last-key routing. Do not report those manual checks as completed from unit tests or unsigned builds.

- [ ] **Step 8: Review final diff against every acceptance criterion**

```bash
git diff --check bf1d16860a2dc336c0631be3a49ea5164db1ca32
git status --short
git diff --stat bf1d16860a2dc336c0631be3a49ea5164db1ca32
```

Inspect every changed file, confirm `graphify-out/` is unstaged, and map each of the 15 specification acceptance criteria to a test, source guard, build, or explicitly unchecked manual release item.

- [ ] **Step 9: Commit documentation after verified corrections**

If Steps 3–8 reveal a production or test defect, return to the owning task's
RED/GREEN workflow, commit that correction separately, and rerun all affected
focused and final gates before this documentation commit.

```bash
git add README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md
git commit -m "docs: document local notifications"
```

- [ ] **Step 10: Request final code review**

Invoke `superpowers:requesting-code-review`, resolve only verified findings through the required review workflow, rerun every affected focused test, then rerun the complete gates before claiming completion.
