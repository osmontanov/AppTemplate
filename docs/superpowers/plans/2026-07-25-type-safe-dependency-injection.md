# Type-Safe Dependency Injection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compile-time-safe application composition root that injects asynchronous Browse and session services while preserving independent navigation state for every window.

**Architecture:** An immutable `AppDependencies` value owns app-wide `Sendable` services, while `SessionStore` owns shared main-actor session presentation state. Each `AppSceneView` retains its own router and feature stores; Browse stores receive their repository explicitly, and only `SessionStore` crosses the SwiftUI tree through typed Environment.

**Tech Stack:** Swift 6.3 toolchain in approachable-concurrency mode, SwiftUI, Observation, Swift Testing, Xcode 26.6, iOS/iPadOS/macOS 26 SDKs; no third-party packages.

## Global Constraints

- Minimum deployment targets remain iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Supported device families remain iPhone, iPad, and Mac.
- `AppDependencies` is immutable and provides no registration, lookup, subscript, or `resolve` API.
- `BrowseRepository` and `SessionService` are app-wide, explicitly non-main-actor, and `Sendable`.
- `AppRouter`, `SessionStore`, and Browse presentation stores are `@MainActor`.
- Every window owns an independent `AppRouter`; no router or mutable dependency override is process-global.
- Routes and snapshots contain stable identifiers and never perform repository I/O.
- Feature dependencies are required initializer arguments.
- Typed SwiftUI Environment is limited to shared `SessionStore`, not raw services.
- `live`, `preview`, and `test` graphs are explicit and never fall back to one another.
- Production networking and persistence remain outside this milestone; the runnable template explicitly uses actor-backed in-memory services.
- Tests must be parallel-safe and must not require a global dependency reset.

---

## File Map

### App composition and session

- `AppTemplate/App/Dependencies/AppDependencies.swift`: immutable service graph and `live`, `preview`, and `test` factories.
- `AppTemplate/App/Session/SessionStore.swift`: shared observable session phase, safe failures, and async actions.
- `AppTemplate/AppTemplateApp.swift`: creates the live graph and one shared session store.
- `AppTemplate/ContentView.swift`: preview/test-friendly explicitly injected root.

### Session domain and data

- `AppTemplate/Core/Session/UserSession.swift`: stable, `Sendable` session value.
- `AppTemplate/Core/Session/SessionService.swift`: asynchronous `Sendable` session contract.
- `AppTemplate/Core/Session/InMemorySessionService.swift`: actor-backed template implementation.

### Browse domain, data, and presentation

- `AppTemplate/Features/Browse/BrowseItem.swift`: stable Browse entity; legacy resolver removed after navigation migration.
- `AppTemplate/Features/Browse/Domain/BrowseRepository.swift`: asynchronous `Sendable` repository contract.
- `AppTemplate/Features/Browse/Data/InMemoryBrowseRepository.swift`: actor-backed live/preview/test implementation.
- `AppTemplate/Features/Browse/Presentation/BrowseStoreState.swift`: equatable list/detail states and display-safe failure.
- `AppTemplate/Features/Browse/Presentation/BrowseListStore.swift`: async list loading and stale-result protection.
- `AppTemplate/Features/Browse/Presentation/BrowseDetailStore.swift`: async ID-based loading, missing-state handling, cancellation, and retry.
- `AppTemplate/Features/Browse/BrowseView.swift`: injected repository, stable store ownership, and state rendering.

### Existing navigation and application UI

- `AppTemplate/App/Navigation/AppFlow.swift`: outcomes without data-availability rejection.
- `AppTemplate/App/Navigation/AppRouter.swift`: route-only intent application and structural restoration.
- `AppTemplate/App/Navigation/NavigationSnapshot.swift`: restoration result without record pruning.
- `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`: scene-local routing plus session-phase synchronization.
- `AppTemplate/App/Navigation/AppSceneView.swift`: per-window lifecycle, shared session observation, and dependency forwarding.
- `AppTemplate/App/Navigation/AppRootView.swift`: root flow and session-driven authentication actions.
- `AppTemplate/App/Navigation/AppShellView.swift`: passes Browse repository into the feature root.
- `AppTemplate/Features/Settings/SettingsView.swift`: shared session display and sign-out action.

### Tests and documentation

- `AppTemplateTests/AppDependenciesTests.swift`: factory and service graph behavior.
- `AppTemplateTests/BrowseStoreTests.swift`: list/detail success, missing, failure, stale response, cancellation, and retry.
- `AppTemplateTests/SessionStoreTests.swift`: restore, sign-in, sign-out, failure, and idempotent startup.
- `AppTemplateTests/AppRouterTests.swift`: route application without data lookup.
- `AppTemplateTests/NavigationSnapshotTests.swift`: unknown IDs remain in restored paths.
- `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`: deep-link and shared-session/independent-router integration.
- `AppTemplateTests/ProjectConfigurationTests.swift`: construction smoke tests using explicit dependencies.
- `README.md`: DI rules, lifetimes, replacement guide, and design/plan links.

---

### Task 1: Add asynchronous service contracts and explicit dependency graphs

**Files:**
- Modify: `AppTemplate/Features/Browse/BrowseItem.swift`
- Create: `AppTemplate/Features/Browse/Domain/BrowseRepository.swift`
- Create: `AppTemplate/Features/Browse/Data/InMemoryBrowseRepository.swift`
- Create: `AppTemplate/Core/Session/UserSession.swift`
- Create: `AppTemplate/Core/Session/SessionService.swift`
- Create: `AppTemplate/Core/Session/InMemorySessionService.swift`
- Create: `AppTemplate/App/Dependencies/AppDependencies.swift`
- Create: `AppTemplateTests/AppDependenciesTests.swift`

**Interfaces:**
- Consumes: Existing `BrowseItem.ID == String`.
- Produces: `BrowseRepository.items()`, `BrowseRepository.item(id:)`, `SessionService.currentSession()`, `SessionService.signIn()`, `SessionService.signOut()`, and `AppDependencies.live/preview/test`.

- [ ] **Step 1: Write failing dependency-graph tests**

Create `AppTemplateTests/AppDependenciesTests.swift`:

```swift
import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredInMemoryServices() async throws {
        let dependencies = AppDependencies.live()
        let items = try await dependencies.browseRepository.items()
        let session = try await dependencies.sessionService.currentSession()

        #expect(dependencies.browseRepository is InMemoryBrowseRepository)
        #expect(dependencies.sessionService is InMemorySessionService)
        #expect(items.map(\.id) == ["swiftui", "observation", "routing"])
        #expect(session == nil)
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() async throws {
        let item = BrowseItem(id: "preview", title: "Preview", summary: "Fixture")
        let session = UserSession(id: "preview-user", displayName: "Preview User")
        let dependencies = AppDependencies.preview(
            browseItems: [item],
            session: session
        )
        let items = try await dependencies.browseRepository.items()
        let restoredSession = try await dependencies.sessionService.currentSession()

        #expect(items == [item])
        #expect(restoredSession == session)
    }

    @Test
    func testGraphKeepsInjectedServices() async throws {
        let repository = InMemoryBrowseRepository(items: [])
        let service = InMemorySessionService(initialSession: nil)
        let dependencies = AppDependencies.test(
            browseRepository: repository,
            sessionService: service
        )
        let items = try await dependencies.browseRepository.items()

        #expect(dependencies.browseRepository is InMemoryBrowseRepository)
        #expect(dependencies.sessionService is InMemorySessionService)
        #expect(items.isEmpty)
    }
}
```

- [ ] **Step 2: Run the focused tests and verify the contracts are absent**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `AppDependencies`, `BrowseRepository`, `UserSession`, and the in-memory services do not exist.

- [ ] **Step 3: Make the domain values and service protocols concurrency-safe**

Change the declaration in `BrowseItem.swift` to:

```swift
nonisolated struct BrowseItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
}
```

Keep `BrowseItemResolving` and `SampleBrowseCatalog` temporarily so the existing router continues to compile until Task 3.

Create `BrowseRepository.swift`:

```swift
nonisolated protocol BrowseRepository: Sendable {
    func items() async throws -> [BrowseItem]
    func item(id: BrowseItem.ID) async throws -> BrowseItem?
}
```

Create `UserSession.swift`:

```swift
nonisolated struct UserSession: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let displayName: String
}
```

Create `SessionService.swift`:

```swift
nonisolated protocol SessionService: Sendable {
    func currentSession() async throws -> UserSession?
    func signIn() async throws -> UserSession
    func signOut() async throws
}
```

- [ ] **Step 4: Add actor-backed in-memory implementations**

Create `InMemoryBrowseRepository.swift`:

```swift
actor InMemoryBrowseRepository: BrowseRepository {
    private var orderedIDs: [BrowseItem.ID]
    private var itemsByID: [BrowseItem.ID: BrowseItem]

    init(items: [BrowseItem]) {
        orderedIDs = items.map(\.id)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    func items() -> [BrowseItem] {
        orderedIDs.compactMap { itemsByID[$0] }
    }

    func item(id: BrowseItem.ID) -> BrowseItem? {
        itemsByID[id]
    }

    nonisolated static func live() -> InMemoryBrowseRepository {
        InMemoryBrowseRepository(items: [
            BrowseItem(id: "swiftui", title: "SwiftUI", summary: "Adaptive native interfaces."),
            BrowseItem(id: "observation", title: "Observation", summary: "Focused state tracking."),
            BrowseItem(id: "routing", title: "Typed Routing", summary: "Navigation represented as data.")
        ])
    }
}
```

Create `InMemorySessionService.swift`:

```swift
actor InMemorySessionService: SessionService {
    private var session: UserSession?

    init(initialSession: UserSession?) {
        session = initialSession
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        let session = UserSession(id: "template-user", displayName: "Template User")
        self.session = session
        return session
    }

    func signOut() {
        session = nil
    }
}
```

- [ ] **Step 5: Add the immutable composition value and factories**

Create `AppDependencies.swift`:

```swift
nonisolated struct AppDependencies: Sendable {
    let browseRepository: any BrowseRepository
    let sessionService: any SessionService

    init(
        browseRepository: any BrowseRepository,
        sessionService: any SessionService
    ) {
        self.browseRepository = browseRepository
        self.sessionService = sessionService
    }

    static func live() -> AppDependencies {
        AppDependencies(
            browseRepository: InMemoryBrowseRepository.live(),
            sessionService: InMemorySessionService(initialSession: nil)
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        session: UserSession?
    ) -> AppDependencies {
        AppDependencies(
            browseRepository: InMemoryBrowseRepository(items: browseItems),
            sessionService: InMemorySessionService(initialSession: session)
        )
    }

    static func test(
        browseRepository: any BrowseRepository,
        sessionService: any SessionService
    ) -> AppDependencies {
        AppDependencies(
            browseRepository: browseRepository,
            sessionService: sessionService
        )
    }
}
```

- [ ] **Step 6: Run the focused and full tests**

Run the Task 1 focused command again.

Expected: all three `AppDependenciesTests` pass and the live item order is exactly `swiftui`, `observation`, `routing`.

Then run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the entire existing test suite passes.

- [ ] **Step 7: Commit the service graph**

```bash
git add AppTemplate/App/Dependencies \
  AppTemplate/Core/Session \
  AppTemplate/Features/Browse \
  AppTemplateTests/AppDependenciesTests.swift
git commit -m "feat: add type-safe dependency graph"
```

---

### Task 2: Add isolated asynchronous Browse stores

**Files:**
- Create: `AppTemplate/Features/Browse/Presentation/BrowseStoreState.swift`
- Create: `AppTemplate/Features/Browse/Presentation/BrowseListStore.swift`
- Create: `AppTemplate/Features/Browse/Presentation/BrowseDetailStore.swift`
- Create: `AppTemplateTests/BrowseStoreTests.swift`

**Interfaces:**
- Consumes: `BrowseRepository`, `BrowseItem`, and stable `BrowseItem.ID`.
- Produces: `BrowseListStore.load()`, `BrowseDetailStore.load()`, `BrowseDetailStore.cancel()`, `BrowseListState`, and `BrowseDetailState`.

- [ ] **Step 1: Write failing success, missing, and failure tests**

Create `AppTemplateTests/BrowseStoreTests.swift` with:

```swift
import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct BrowseStoreTests {
    @Test
    func listLoadsRepositoryItems() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let store = BrowseListStore(
            repository: InMemoryBrowseRepository(items: [item])
        )

        await store.load()

        #expect(store.state == .content([item]))
    }

    @Test
    func detailLoadsByStableIdentifier() async {
        let item = BrowseItem(id: "one", title: "One", summary: "First")
        let store = BrowseDetailStore(
            id: item.id,
            repository: InMemoryBrowseRepository(items: [item])
        )

        await store.load()

        #expect(store.state == .content(item))
    }

    @Test
    func missingDetailProducesNotFound() async {
        let store = BrowseDetailStore(
            id: "missing",
            repository: InMemoryBrowseRepository(items: [])
        )

        await store.load()

        #expect(store.state == .notFound)
    }

    @Test
    func repositoryFailureProducesDisplaySafeFailure() async {
        let store = BrowseDetailStore(
            id: "one",
            repository: FailingBrowseRepository()
        )

        await store.load()

        #expect(store.state == .failed(.load))
    }
}

private nonisolated enum BrowseRepositoryTestError: Error {
    case failed
}

private actor FailingBrowseRepository: BrowseRepository {
    func items() throws -> [BrowseItem] {
        throw BrowseRepositoryTestError.failed
    }

    func item(id: BrowseItem.ID) throws -> BrowseItem? {
        throw BrowseRepositoryTestError.failed
    }
}
```

- [ ] **Step 2: Run the focused tests and verify the stores are absent**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:AppTemplateTests/BrowseStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because the Browse store and state types do not exist.

- [ ] **Step 3: Implement explicit, equatable Browse states**

Create `BrowseStoreState.swift`:

```swift
nonisolated enum BrowseFailure: Equatable, Sendable {
    case load

    var message: String {
        "Browse content could not be loaded."
    }
}

nonisolated enum BrowseListState: Equatable, Sendable {
    case idle
    case loading
    case content([BrowseItem])
    case failed(BrowseFailure)
}

nonisolated enum BrowseDetailState: Equatable, Sendable {
    case idle
    case loading
    case content(BrowseItem)
    case notFound
    case failed(BrowseFailure)
}
```

- [ ] **Step 4: Implement minimal list and detail stores**

Create `BrowseListStore.swift`:

```swift
import Observation

@MainActor
@Observable
final class BrowseListStore {
    private(set) var state: BrowseListState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0

    init(repository: any BrowseRepository) {
        self.repository = repository
    }

    func load() async {
        requestVersion += 1
        let version = requestVersion
        state = .loading

        do {
            let items = try await repository.items()
            guard version == requestVersion else {
                return
            }
            state = .content(items)
        } catch is CancellationError {
            guard version == requestVersion else {
                return
            }
            state = .idle
        } catch {
            guard version == requestVersion else {
                return
            }
            state = .failed(.load)
        }
    }
}
```

Create `BrowseDetailStore.swift`:

```swift
import Observation

@MainActor
@Observable
final class BrowseDetailStore {
    let id: BrowseItem.ID
    private(set) var state: BrowseDetailState = .idle
    private let repository: any BrowseRepository
    private var requestVersion = 0

    init(id: BrowseItem.ID, repository: any BrowseRepository) {
        self.id = id
        self.repository = repository
    }

    func load() async {
        requestVersion += 1
        let version = requestVersion
        state = .loading

        do {
            let item = try await repository.item(id: id)
            guard version == requestVersion else {
                return
            }
            state = item.map(BrowseDetailState.content) ?? .notFound
        } catch is CancellationError {
            guard version == requestVersion else {
                return
            }
            state = .idle
        } catch {
            guard version == requestVersion else {
                return
            }
            state = .failed(.load)
        }
    }

    func cancel() {
        requestVersion += 1
        if state == .loading {
            state = .idle
        }
    }
}
```

- [ ] **Step 5: Add stale-response and cancellation tests**

Add to `BrowseStoreTests`:

```swift
@Test
func staleDetailResponseCannotReplaceNewerResult() async throws {
    let old = BrowseItem(id: "one", title: "Old", summary: "Slow")
    let new = BrowseItem(id: "one", title: "New", summary: "Fast")
    let repository = SequencedBrowseRepository(responses: [
        (.milliseconds(80), old),
        (.zero, new)
    ])
    let store = BrowseDetailStore(id: "one", repository: repository)

    let first = Task { await store.load() }
    try await ContinuousClock().sleep(for: .milliseconds(10))
    await store.load()
    await first.value

    #expect(store.state == .content(new))
}

@Test
func cancelledDetailLoadDoesNotBecomeFailure() async throws {
    let item = BrowseItem(id: "one", title: "One", summary: "Slow")
    let repository = SequencedBrowseRepository(responses: [
        (.seconds(1), item)
    ])
    let store = BrowseDetailStore(id: "one", repository: repository)

    let load = Task { await store.load() }
    try await ContinuousClock().sleep(for: .milliseconds(10))
    load.cancel()
    await load.value

    #expect(store.state == .idle)
}
```

Add the test actor:

```swift
private actor SequencedBrowseRepository: BrowseRepository {
    private var responses: [(Duration, BrowseItem?)]

    init(responses: [(Duration, BrowseItem?)]) {
        self.responses = responses
    }

    func items() -> [BrowseItem] {
        []
    }

    func item(id: BrowseItem.ID) async throws -> BrowseItem? {
        let response = responses.removeFirst()
        try await ContinuousClock().sleep(for: response.0)
        return response.1
    }
}
```

- [ ] **Step 6: Run focused and full tests**

Run the focused Task 2 command again.

Expected: all Browse store tests pass, including stale and cancelled requests.

Run the full iOS test command from Task 1.

Expected: all tests pass.

- [ ] **Step 7: Commit Browse presentation state**

```bash
git add AppTemplate/Features/Browse/Presentation \
  AppTemplateTests/BrowseStoreTests.swift
git commit -m "feat: add async browse stores"
```

---

### Task 3: Remove data resolution from navigation and restoration

**Files:**
- Modify: `AppTemplate/App/Navigation/AppFlow.swift`
- Modify: `AppTemplate/App/Navigation/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/NavigationSnapshot.swift`
- Modify: `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplate/Features/Browse/BrowseItem.swift`
- Modify: `AppTemplateTests/AppRouterTests.swift`
- Modify: `AppTemplateTests/NavigationSnapshotTests.swift`
- Modify: `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`

**Interfaces:**
- Consumes: Existing typed `NavigationIntent.browseItem(id:)` and `BrowseRoute.item(id:)`.
- Produces: Route-only `AppRouter.handle`, structural `AppRouter.restore`, and no `BrowseItemResolving` dependency.

- [ ] **Step 1: Replace resolver-based expectations with route-first tests**

In `AppRouterTests`, replace `missingBrowseRecordFallsBackToBrowseRootAndPreservesOtherHistories` with:

```swift
@Test
func unknownBrowseIdentifierStillBuildsTypedRoute() {
    let router = AppRouter(selectedSection: .settings)
    router.home.push(.details)
    router.settings.push(.about)

    let outcome = router.handle(.browseItem(id: "missing"))

    #expect(outcome == .applied)
    #expect(router.selectedSection == .browse)
    #expect(router.browse.path == [.item(id: "missing")])
    #expect(router.home.path == [.details])
    #expect(router.settings.path == [.about])
}
```

In `NavigationSnapshotTests`, replace the pruning test with:

```swift
@Test
func restorePreservesStructurallyValidUnknownBrowseIdentifiers() throws {
    let snapshot = NavigationSnapshot(
        selectedSection: .browse,
        homePath: [.details],
        browsePath: [.item(id: "swiftui"), .item(id: "deleted")],
        settingsPath: [.about]
    )
    let router = AppRouter()

    let result = router.restore(from: try NavigationSnapshotCodec.encode(snapshot))

    #expect(result == .restored)
    #expect(router.snapshot == snapshot)
}
```

In `AppSceneNavigationLifecycleTests`, replace the unavailable-record test with:

```swift
@Test
func unknownBrowseRecordColdLaunchKeepsRouteAndOtherHistories() throws {
    let router = AppRouter()
    let lifecycle = AppSceneNavigationLifecycle(router: router)
    let storedSnapshot = NavigationSnapshot(
        selectedSection: .settings,
        homePath: [.details],
        browsePath: [.item(id: "swiftui")],
        settingsPath: [.about]
    )

    lifecycle.receive(try #require(URL(string: "apptemplate://browse/item/deleted")))
    let snapshotToPersist = lifecycle.restore(
        from: try NavigationSnapshotCodec.encode(storedSnapshot)
    )

    #expect(router.selectedSection == .browse)
    #expect(router.home.path == [.details])
    #expect(router.browse.path == [.item(id: "deleted")])
    #expect(router.settings.path == [.about])
    #expect(snapshotToPersist == router.snapshot)
}
```

Delete `defaultStateProducedByPruningRequestsSanitizedPersistence`; pruning no longer exists.

- [ ] **Step 2: Run navigation tests and verify old resolver behavior fails**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the new unknown-ID tests fail because the router rejects or prunes `"deleted"`.

- [ ] **Step 3: Simplify navigation outcomes and intent application**

Replace the outcome declarations in `AppFlow.swift` with:

```swift
enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
}
```

In `AppRouter.swift`:

- remove every overload accepting `any BrowseItemResolving`;
- remove every construction of `SampleBrowseCatalog`;
- make `handle`, `finishLaunching`, and `completeAuthentication` call their route-only helpers;
- implement `.browseItem(id:)` as:

```swift
case let .browseItem(id):
    selectedSection = .browse
    browse.replacePath(with: [.item(id: id)])
    return .applied
```

The private replay helper becomes:

```swift
private func replayPendingIntent() -> NavigationOutcome? {
    guard let intent = pendingIntent else {
        return nil
    }
    pendingIntent = nil
    return apply(intent)
}
```

- [ ] **Step 4: Make restoration structural only**

In `AppRouter.restore(from:)`, keep nil-data, decode, schema, and reset handling. Replace resolver filtering and conditional result selection with:

```swift
selectedSection = decoded.selectedSection
home.replacePath(with: decoded.homePath)
browse.replacePath(with: decoded.browsePath)
settings.replacePath(with: decoded.settingsPath)
return .restored
```

Change `NavigationRestorationResult` to:

```swift
enum NavigationRestorationResult: Equatable, Sendable {
    case noState
    case restored
    case reset(NavigationRestorationFailure)
}
```

Remove the `.restoredAfterPruning` branch from `AppSceneNavigationLifecycle.restore(from:)`.

Delete `BrowseItemResolving` and `SampleBrowseCatalog` from `BrowseItem.swift`; the in-memory repository from Task 1 is now the only sample-data owner.

- [ ] **Step 5: Run navigation and full tests**

Run the focused Task 3 command.

Expected: route-first deep-link and restoration tests pass.

Run the full iOS test command.

Expected: all tests pass and `rg -n 'BrowseItemResolving|SampleBrowseCatalog' AppTemplate AppTemplateTests` returns no matches.

- [ ] **Step 6: Commit the navigation boundary**

```bash
git add AppTemplate/App/Navigation \
  AppTemplate/Features/Browse/BrowseItem.swift \
  AppTemplateTests/AppRouterTests.swift \
  AppTemplateTests/NavigationSnapshotTests.swift \
  AppTemplateTests/AppSceneNavigationLifecycleTests.swift
git commit -m "refactor: decouple navigation from browse data"
```

---

### Task 4: Add shared observable session state

**Files:**
- Create: `AppTemplate/App/Session/SessionStore.swift`
- Create: `AppTemplateTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `SessionService` and `UserSession`.
- Produces: `SessionPhase`, `SessionFailure`, `SessionStore.start`, `retryStart`, `signIn`, and `signOut`.

- [ ] **Step 1: Write failing session-store tests**

Create `AppTemplateTests/SessionStoreTests.swift`:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct SessionStoreTests {
    @Test
    func startupRestoresExistingSessionOnlyOnce() async {
        let session = UserSession(id: "one", displayName: "One")
        let service = CountingSessionService(session: session)
        let store = SessionStore(service: service)

        await store.start()
        await store.start()

        let restoreCount = await service.restoreCount
        #expect(store.phase == .authenticated(session))
        #expect(restoreCount == 1)
    }

    @Test
    func startupWithoutSessionBecomesUnauthenticated() async {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        await store.start()

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func signInAndSignOutUpdatePhase() async {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        await store.signIn()
        #expect(store.phase == .authenticated(
            UserSession(id: "template-user", displayName: "Template User")
        ))

        await store.signOut()
        #expect(store.phase == .unauthenticated)
    }

    @Test
    func signInFailureUsesSafePresentationError() async {
        let store = SessionStore(service: FailingSessionService())

        await store.signIn()

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == .signIn)
        #expect(store.failure?.message == "Sign in could not be completed.")
    }
}

private actor CountingSessionService: SessionService {
    private(set) var restoreCount = 0
    private var session: UserSession?

    init(session: UserSession?) {
        self.session = session
    }

    func currentSession() -> UserSession? {
        restoreCount += 1
        return session
    }

    func signIn() -> UserSession {
        let session = UserSession(id: "one", displayName: "One")
        self.session = session
        return session
    }

    func signOut() {
        session = nil
    }
}

private actor FailingSessionService: SessionService {
    func currentSession() throws -> UserSession? {
        throw SessionServiceTestError.failed
    }

    func signIn() throws -> UserSession {
        throw SessionServiceTestError.failed
    }

    func signOut() throws {
        throw SessionServiceTestError.failed
    }
}

private nonisolated enum SessionServiceTestError: Error {
    case failed
}
```

- [ ] **Step 2: Run the focused tests and verify SessionStore is absent**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:AppTemplateTests/SessionStoreTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `SessionStore`, `SessionPhase`, and `SessionFailure` do not exist.

- [ ] **Step 3: Implement idempotent session state and safe failures**

Create `SessionStore.swift`:

```swift
import Observation

nonisolated enum SessionPhase: Equatable, Sendable {
    case idle
    case loading
    case unauthenticated
    case authenticated(UserSession)
}

nonisolated enum SessionFailure: Equatable, Sendable {
    case restoration
    case signIn
    case signOut

    var message: String {
        switch self {
        case .restoration:
            "The previous session could not be restored."
        case .signIn:
            "Sign in could not be completed."
        case .signOut:
            "Sign out could not be completed."
        }
    }
}

@MainActor
@Observable
final class SessionStore {
    private(set) var phase: SessionPhase = .idle
    private(set) var failure: SessionFailure?

    private let service: any SessionService
    private var hasStarted = false

    init(service: any SessionService) {
        self.service = service
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        phase = .loading
        failure = nil

        do {
            if let session = try await service.currentSession() {
                phase = .authenticated(session)
            } else {
                phase = .unauthenticated
            }
        } catch is CancellationError {
            hasStarted = false
            phase = .idle
        } catch {
            phase = .unauthenticated
            failure = .restoration
        }
    }

    func retryStart() async {
        hasStarted = false
        await start()
    }

    func signIn() async {
        hasStarted = true
        phase = .loading
        failure = nil
        do {
            phase = .authenticated(try await service.signIn())
        } catch is CancellationError {
            phase = .unauthenticated
        } catch {
            phase = .unauthenticated
            failure = .signIn
        }
    }

    func signOut() async {
        hasStarted = true
        let previousPhase = phase
        phase = .loading
        failure = nil
        do {
            try await service.signOut()
            phase = .unauthenticated
        } catch is CancellationError {
            phase = previousPhase
        } catch {
            phase = previousPhase
            failure = .signOut
        }
    }
}
```

- [ ] **Step 4: Add retry and failed-sign-out coverage**

Add these tests:

```swift
@Test
func retryStartRunsRestorationAgainAfterFailure() async {
    let service = RecoveringSessionService()
    let store = SessionStore(service: service)

    await store.start()
    #expect(store.failure == .restoration)

    await store.retryStart()
    let restoreCount = await service.restoreCount

    #expect(store.phase == .unauthenticated)
    #expect(store.failure == nil)
    #expect(restoreCount == 2)
}

@Test
func failedSignOutRetainsAuthenticatedSession() async {
    let session = UserSession(id: "one", displayName: "One")
    let store = SessionStore(
        service: SignOutFailingSessionService(session: session)
    )

    await store.start()
    await store.signOut()

    #expect(store.phase == .authenticated(session))
    #expect(store.failure == .signOut)
}
```

Add these test actors to the same file:

```swift
private actor RecoveringSessionService: SessionService {
    private(set) var restoreCount = 0

    func currentSession() throws -> UserSession? {
        restoreCount += 1
        if restoreCount == 1 {
            throw SessionServiceTestError.failed
        }
        return nil
    }

    func signIn() -> UserSession {
        UserSession(id: "recovered", displayName: "Recovered")
    }

    func signOut() {
    }
}

private actor SignOutFailingSessionService: SessionService {
    private let session: UserSession

    init(session: UserSession) {
        self.session = session
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        session
    }

    func signOut() throws {
        throw SessionServiceTestError.failed
    }
}
```

- [ ] **Step 5: Run focused and full tests**

Run the focused Task 4 command and then the full iOS test command.

Expected: all session tests and all existing tests pass.

- [ ] **Step 6: Commit shared session state**

```bash
git add AppTemplate/App/Session AppTemplateTests/SessionStoreTests.swift
git commit -m "feat: add observable session store"
```

---

### Task 5: Wire app-wide services, scene lifetimes, and SwiftUI features

**Files:**
- Modify: `AppTemplate/AppTemplateApp.swift`
- Modify: `AppTemplate/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplate/App/Navigation/AppSceneView.swift`
- Modify: `AppTemplate/App/Navigation/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/AppShellView.swift`
- Modify: `AppTemplate/Features/Browse/BrowseView.swift`
- Modify: `AppTemplate/Features/Settings/SettingsView.swift`
- Modify: `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`
- Modify: `AppTemplateTests/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: `AppDependencies`, `SessionStore`, Browse stores, and route-only navigation from Tasks 1–4.
- Produces: one app-wide service graph and session store, one router per scene, explicit Browse injection, and typed session Environment.

- [ ] **Step 1: Add failing session-to-scene lifetime tests**

Add to `AppSceneNavigationLifecycleTests`:

```swift
@Test
func sharedAuthenticatedPhaseReplaysEachScenesOwnPendingIntent() {
    let firstRouter = AppRouter(flow: .authentication)
    let secondRouter = AppRouter(flow: .authentication)
    let first = AppSceneNavigationLifecycle(router: firstRouter)
    let second = AppSceneNavigationLifecycle(router: secondRouter)

    _ = firstRouter.handle(.browseItem(id: "swiftui"))
    _ = secondRouter.handle(.selectSection(.settings))
    let session = UserSession(id: "one", displayName: "One")

    first.synchronizeSession(.authenticated(session))
    second.synchronizeSession(.authenticated(session))

    #expect(firstRouter.browse.path == [.item(id: "swiftui")])
    #expect(firstRouter.selectedSection == .browse)
    #expect(secondRouter.browse.path.isEmpty)
    #expect(secondRouter.selectedSection == .settings)
}

@Test
func unauthenticatedPhaseMovesEverySceneToAuthentication() {
    let first = AppSceneNavigationLifecycle(router: AppRouter())
    let second = AppSceneNavigationLifecycle(router: AppRouter())

    first.synchronizeSession(.unauthenticated)
    second.synchronizeSession(.unauthenticated)

    #expect(first.router.flow == .authentication)
    #expect(second.router.flow == .authentication)
    #expect(first.router !== second.router)
}
```

- [ ] **Step 2: Run lifecycle tests and verify synchronization is absent**

Run the focused Task 3 navigation command with only `AppSceneNavigationLifecycleTests`.

Expected: compilation fails because `synchronizeSession(_:)` does not exist.

- [ ] **Step 3: Add session coordination to the scene lifecycle**

Add:

```swift
func synchronizeSession(_ phase: SessionPhase) {
    switch phase {
    case .idle, .loading:
        router.flow = .launching
    case .unauthenticated:
        if router.flow == .launching {
            _ = router.finishLaunching(isAuthenticated: false)
        } else {
            router.flow = .authentication
        }
    case .authenticated:
        _ = router.completeAuthentication(succeeded: true)
    }
}
```

Change the no-argument lifecycle initializer to create `AppRouter(flow: .launching)`. Keep injected-router initializers unchanged for deterministic tests.

- [ ] **Step 4: Replace the Browse view with explicitly injected store ownership**

`BrowseNavigationView` must have this initializer boundary:

```swift
struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    @State private var store: BrowseListStore
    private let repository: any BrowseRepository

    init(router: BrowseRouter, repository: any BrowseRepository) {
        self.router = router
        self.repository = repository
        _store = State(initialValue: BrowseListStore(repository: repository))
    }
}
```

Render `BrowseListState` as follows:

```swift
switch store.state {
case .idle, .loading:
    ProgressView("Loading Browse…")
case let .content(items):
    List(items) { item in
        NavigationLink(value: BrowseRoute.item(id: item.id)) {
            VStack(alignment: .leading) {
                Text(item.title)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
case let .failed(failure):
    ContentUnavailableView {
        Label("Browse Unavailable", systemImage: "exclamationmark.triangle")
    } description: {
        Text(failure.message)
    } actions: {
        Button("Retry") {
            Task { await store.load() }
        }
    }
}
```

Attach `.task { await store.load() }` to the stable list root. Keep `.navigationDestination(for:)` outside the lazy list and construct:

```swift
BrowseDetailView(id: id, repository: repository)
```

The detail view owns:

```swift
@State private var store: BrowseDetailStore

init(id: BrowseItem.ID, repository: any BrowseRepository) {
    _store = State(
        initialValue: BrowseDetailStore(id: id, repository: repository)
    )
}
```

It maps detail states to `ProgressView`, the existing detail `Form`, a `ContentUnavailableView` for `notFound`, and a retryable failure view. Attach `.task(id: store.id) { await store.load() }`.

- [ ] **Step 5: Thread dependencies through the application roots**

Change the relevant initializer signatures to:

```swift
AppSceneView(dependencies: AppDependencies)
AppRootView(router: AppRouter, dependencies: AppDependencies)
AppShellView(router: AppRouter, dependencies: AppDependencies)
BrowseNavigationView(
    router: router.browse,
    repository: dependencies.browseRepository
)
```

`AppSceneView` reads the shared store:

```swift
@Environment(SessionStore.self) private var sessionStore
```

It keeps `AppSceneNavigationLifecycle` in `@State`, forwards dependencies to `AppRootView`, starts session restoration, and observes phase changes:

```swift
.task {
    await sessionStore.start()
    lifecycle.synchronizeSession(sessionStore.phase)
}
.onChange(of: sessionStore.phase) { _, phase in
    lifecycle.synchronizeSession(phase)
}
```

Keep the existing restoration-first URL queue and snapshot persistence modifiers intact.

- [ ] **Step 6: Make session actions flow through SessionStore**

In `AppRootView`, read `SessionStore` from typed Environment. The authentication screen must:

- show `sessionStore.failure?.message` when present;
- run `Task { await sessionStore.signIn() }` for Continue;
- call `router.completeAuthentication(succeeded: false)` only for scene-local Cancel;
- offer `Task { await sessionStore.retryStart() }` when `failure == .restoration`.

Do not mark authentication successful directly from the Continue button. The resulting `.authenticated` phase is observed by `AppSceneView`, which replays that scene's pending intent.

In `SettingsNavigationView`, read `SessionStore` from typed Environment and add:

```swift
Section("Session") {
    switch sessionStore.phase {
    case let .authenticated(session):
        LabeledContent("Signed in", value: session.displayName)
        Button("Sign Out") {
            Task { await sessionStore.signOut() }
        }
    case .idle, .loading:
        ProgressView()
    case .unauthenticated:
        Text("Not signed in")
    }

    if let failure = sessionStore.failure {
        Text(failure.message)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 7: Build the app composition root and explicit preview graph**

`AppTemplateApp` owns the graph:

```swift
@main
struct AppTemplateApp: App {
    private let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init() {
        let dependencies = AppDependencies.live()
        self.dependencies = dependencies
        _sessionStore = State(
            initialValue: SessionStore(service: dependencies.sessionService)
        )
    }

    var body: some Scene {
        WindowGroup {
            AppSceneView(dependencies: dependencies)
                .environment(sessionStore)
        }
    }
}
```

Replace `ContentView` and its preview with:

```swift
import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var router = AppRouter()

    var body: some View {
        AppRootView(router: router, dependencies: dependencies)
    }
}

@MainActor
private struct PreviewRoot: View {
    let dependencies: AppDependencies
    @State private var sessionStore: SessionStore

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _sessionStore = State(
            initialValue: SessionStore(service: dependencies.sessionService)
        )
    }

    var body: some View {
        ContentView(dependencies: dependencies)
            .environment(sessionStore)
    }
}

#Preview {
    let dependencies = AppDependencies.preview(
        browseItems: [
            BrowseItem(id: "swiftui", title: "SwiftUI", summary: "Adaptive native interfaces."),
            BrowseItem(id: "observation", title: "Observation", summary: "Focused state tracking."),
            BrowseItem(id: "routing", title: "Typed Routing", summary: "Navigation represented as data.")
        ],
        session: UserSession(id: "preview-user", displayName: "Preview User")
    )
    PreviewRoot(dependencies: dependencies)
}
```

In `ProjectConfigurationTests`, construct the views with:

```swift
let dependencies = AppDependencies.preview(browseItems: [], session: nil)
let router = AppRouter()

_ = AppRootView(router: router, dependencies: dependencies)
_ = AppShellView(router: router, dependencies: dependencies)
_ = BrowseNavigationView(
    router: router.browse,
    repository: dependencies.browseRepository
)
```

- [ ] **Step 8: Run focused tests, full tests, and both platform builds**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests pass; iOS Simulator and macOS builds report `BUILD SUCCEEDED`.

- [ ] **Step 9: Commit the composed application**

```bash
git add AppTemplate/AppTemplateApp.swift \
  AppTemplate/ContentView.swift \
  AppTemplate/App/Navigation \
  AppTemplate/Features/Browse/BrowseView.swift \
  AppTemplate/Features/Settings/SettingsView.swift \
  AppTemplateTests/AppSceneNavigationLifecycleTests.swift \
  AppTemplateTests/ProjectConfigurationTests.swift
git commit -m "feat: compose app dependencies across scenes"
```

---

### Task 6: Document replacement rules and perform final verification

**Files:**
- Modify: `README.md`
- Test: all files in `AppTemplateTests`

**Interfaces:**
- Consumes: Completed dependency graph and application wiring.
- Produces: User-facing DI replacement guide and final cross-platform evidence.

- [ ] **Step 1: Add a README acceptance check**

Run:

```bash
rg -n 'AppDependencies|BrowseRepository|SessionService|app-wide|scene-scoped|preview|test' README.md
```

Expected: failure because README currently documents navigation only.

- [ ] **Step 2: Document the DI contract and replacement procedure**

Add this section:

```markdown
## Dependency Injection

`AppDependencies` is the composition root. `BrowseRepository` and
`SessionService` are app-wide `Sendable` services. `SessionStore` is shared
app-wide through typed SwiftUI Environment. `AppRouter` and Browse presentation
stores are scene- or feature-scoped. Feature dependencies are required
initializer arguments.

To replace a template service:

1. Add a `Sendable` implementation of the existing protocol.
2. Replace only its construction expression in `AppDependencies.live()`.
3. Keep preview and test factories explicit.
4. Do not add global registration, `resolve()`, mutable overrides, or production
   fallback to fixtures.

Structurally valid restored and deep-linked Browse IDs remain routed.
`BrowseDetailStore` displays `notFound` when the repository returns `nil`.

See the
[DI design](docs/superpowers/specs/2026-07-25-type-safe-dependency-injection-design.md)
and
[implementation plan](docs/superpowers/plans/2026-07-25-type-safe-dependency-injection.md).
```

- [ ] **Step 3: Run static architecture checks**

Run:

```bash
rg -n 'BrowseItemResolving|SampleBrowseCatalog|func resolve|register\\(|resetDependencies|fatalError|as!' \
  AppTemplate AppTemplateTests
```

Expected: no matches.

Run:

```bash
rg -n 'AppDependencies\\.live\\(\\)' AppTemplate
```

Expected: exactly one production call, in `AppTemplateApp.swift`.

- [ ] **Step 4: Run the complete iOS and macOS verification matrix**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both test actions report zero failures.

Run:

```bash
xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both Release builds report `BUILD SUCCEEDED`.

- [ ] **Step 5: Inspect the final diff and repository state**

Run:

```bash
git diff --check
git status --short
git log --oneline -8
```

Expected: no whitespace errors, only the README change remains uncommitted, and the preceding five implementation commits are present.

- [ ] **Step 6: Commit documentation**

```bash
git add README.md
git commit -m "docs: explain dependency injection architecture"
```

- [ ] **Step 7: Confirm final cleanliness**

Run:

```bash
git status --short --branch
```

Expected: the working tree is clean and the branch is ahead only by the intended local commits.
