# AppTemplate Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement approved hardening roadmap items 2–13 without adding
product logic or weakening the template's screen and feature boundaries.

**Architecture:** Preserve one application-scoped dependency graph, state
store, flow coordinator, and root router, while every window keeps its own
scene router, paths, pending intent, transition checkpoint, and snapshot write
gate. Feature ViewModels receive only explicit, narrow capabilities and
feature dependencies; SwiftUI previews and UI tests use deterministic in-memory
composition.

**Tech Stack:** Swift 6, SwiftUI and Observation, Swift Testing, XCTest UI
testing, UserDefaults, SceneStorage, String Catalogs, Xcode 26.6, and GitHub
Actions `macos-26`.

## Global Constraints

- Keep `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and
  `MACOSX_DEPLOYMENT_TARGET = 26.0`; support iPhone, iPad, and macOS.
- Keep `SWIFT_APPROACHABLE_CONCURRENCY = YES`,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and zero compiler warnings.
- Write attributes/modifiers such as `nonisolated` on their own line before
  every affected declaration, matching the repository style.
- Do not add `PrivacyInfo.xcprivacy`; document that App Store distribution is
  blocked until the adopter supplies the correct manifest.
- Do not implement real authentication, HTTP networking, database access,
  project persistence, credentials, tokens, or product business logic.
- Do not add a service locator, global mutable dependency container,
  third-party DI framework, or package extraction.
- Keep every new user-facing screen's View, ViewModel, Model, State, and
  Navigation folders, even when a reserved type is empty.
- Preserve existing typed routes, independent per-tab stacks, enum-driven
  sheets/alerts, scene-local pending intents, and application-wide semantic
  root policy.
- Every behavioral Swift change follows strict red-green-refactor: write one
  behavior test, run it and observe the expected failure, add minimal code,
  then rerun the focused and affected suites.
- Generated image variants, String Catalog data, `project.pbxproj`, xcconfig,
  scheme XML, workflow YAML, `.gitignore`, and human documentation are
  configuration/artifact work; verify them with compilers, `plutil`, asset
  compilation, project inspection, and real workflow commands rather than
  source-text unit tests.
- Layout-only SwiftUI composition whose behavior is not exposed as a pure API
  is verified by rendered accessibility-size previews and the later real UI
  tests; do not add assertion-free constructor tests or source-shape tests.
- CI uses `macos-26`, `/Applications/Xcode_26.6.app`, iOS 26.5,
  `iPhone 17`, and `iPad (A16)`.

---

## File and Responsibility Map

### Application state

- `AppTemplate/App/ApplicationState/AppState.swift`: persisted application
  policy value and current schema.
- `AppTemplate/App/ApplicationState/AppStateStore.swift`: load, repair,
  mutation ordering, read-only status, and typed mutation result.
- `AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift`:
  synchronous throwing bootstrap-storage contract.
- `AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift`:
  missing/data/invalid-value load representation.
- `AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift`:
  deterministic preview/UI-test storage.
- `AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift`:
  live adapter.
- `AppTemplate/App/ApplicationState/Diagnostics/AppStateLogger.swift`:
  category-only persistence logging.

### Navigation and scene restoration

- `AppTemplate/App/Navigation/Core/IFlowRouter.swift`: stack-only capability.
- `AppTemplate/App/Navigation/Core/FlowRouter.swift`: scene path plus delegation
  to semantic app actions.
- `AppTemplate/App/Navigation/Routing/IAuthenticationActions.swift`,
  `IOnboardingActions.swift`, `IMaintenanceActions.swift`: application-policy
  capabilities.
- `AppTemplate/App/Navigation/Routing/IAuthenticationCancellation.swift`:
  scene-local Authentication cancellation.
- `AppTemplate/App/Navigation/Routing/AppFlowActionResult.swift`: typed outcome
  for semantic actions.
- `AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift`: composition of
  semantic capabilities only.
- `AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift`: durable state
  mutation followed by policy transition.
- `AppTemplate/App/Navigation/Routing/AppFlowRouter.swift`: concrete
  infrastructure router; its raw `setFlow` remains concrete-only.
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`: scene paths, intents,
  restoration, and Authentication cancellation.
- `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`: schema-4
  paths, selected tab, and transition checkpoint.
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`:
  restore ordering and future-snapshot write gate.
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`: SceneStorage
  persistence only when lifecycle permits it.

### Dependency injection and Settings

- `AppTemplate/App/Services/AppInfo/IAppInfoService.swift`: immutable app name
  and version contract.
- `AppTemplate/App/Services/AppInfo/AppInfoService.swift`: Bundle-capturing live
  value and fixed-value preview/test initializer.
- `AppTemplate/Features/Settings/Dependencies/SettingsDependencies.swift`:
  feature-scoped app-info dependency.
- `AppTemplate/App/AppDependencies/AppDependencies.swift`: immutable application
  graph and live/preview/test factories.
- `AppTemplate/Features/Settings/Screens/AppSettings/**`: complete macOS native
  Settings screen scaffold.

### Configuration, UI, testing, and documentation

- `Config/Template.xcconfig`: replaceable bundle identifier and URL scheme.
- `AppTemplate/Resources/Localizable.xcstrings`: English source catalog.
- `AppTemplate/Utilities/UIComponents/AdaptiveContentContainer.swift`:
  scrollable readable-width layout.
- `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`: deterministic preview
  graph and routers.
- `AppTemplate/App/Entry/AppLaunchConfiguration.swift`: pure UI-test launch
  parser and root-state mapping.
- `AppTemplateUITests/AppTemplateUITests.swift`: cross-platform end-to-end
  navigation, sheet, tab, and macOS Settings checks.
- `.github/workflows/ci.yml`: macOS/iPhone/iPad Xcode 26.6 matrix.
- `docs/{README,ARCHITECTURE,CUSTOMIZATION,RELEASE_CHECKLIST}.md`: current
  adopter documentation; `docs/superpowers/**` remains historical.

The work stays in one plan because every later subsystem consumes interfaces
created earlier: navigation actions require the hardened state result, Settings
and previews require the DI scope, UI-test launch requires in-memory state, and
CI requires the final shared scheme. Execute Tasks 1 through 12 in numerical
order; never dispatch two implementation tasks concurrently against the shared
Xcode project.

---

### Task 1: Safe Application-State Persistence Boundary

**Files:**

- Move: `AppTemplate/App/Services/AppStateStorageService/AppState.swift` →
  `AppTemplate/App/ApplicationState/AppState.swift`
- Move: `AppTemplate/App/Services/AppStateStorageService/AppStateStore.swift` →
  `AppTemplate/App/ApplicationState/AppStateStore.swift`
- Move: `AppTemplate/App/Services/AppStateStorageService/Diagnostics/AppStateLogger.swift` →
  `AppTemplate/App/ApplicationState/Diagnostics/AppStateLogger.swift`
- Move storage files into: `AppTemplate/App/ApplicationState/Persistence/`
- Create: `AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift`
- Move tests into: `AppTemplateTests/App/ApplicationState/`
- Move: `AppTemplateTests/TestSupport/AppStateStorageSpy.swift` →
  `AppTemplateTests/App/ApplicationState/TestSupport/AppStateStorageSpy.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Test: `AppTemplateTests/App/ApplicationState/AppStateStoreTests.swift`
- Test: `AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift`
- Test: `AppTemplateTests/App/ApplicationState/Persistence/InMemoryAppStateStorageTests.swift`

**Interfaces:**

- Produces exactly:

```swift
nonisolated
protocol IAppStateStorage: Sendable {
    func load() throws -> AppStateStorageLoadResult
    func save(_ data: Data) throws
    func remove() throws
}

nonisolated
enum AppStatePersistenceFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
    case encodingFailed
    case unsupportedFutureSchema(Int)
}

nonisolated
enum AppStatePersistenceStatus: Equatable, Sendable {
    case writable
    case readOnly(AppStatePersistenceFailure)
}

nonisolated
enum AppStateMutationResult: Equatable, Sendable {
    case unchanged
    case persisted
    case rejected(AppStatePersistenceFailure)
}
```

- `AppStateStore` exposes `private(set) var state` and
  `private(set) var persistenceStatus`.
- `setState(_:) -> AppStateMutationResult` writes before mutating memory.
- `InMemoryAppStateStorage` is a lock-protected `final class`, accepts initial
  `Data?` plus a convenience `AppState` initializer for deterministic fixtures,
  and never touches UserDefaults.
- `AppStateStore` accepts an internal encoder dependency with the exact shape
  `@Sendable (AppState) throws -> Data`, defaulting to `JSONEncoder().encode`.

```swift
init(
    storage: any IAppStateStorage,
    encode: @escaping @Sendable (AppState) throws -> Data = {
        try JSONEncoder().encode($0)
    }
)
```

`InMemoryAppStateStorage.init(initialState:)` encodes the simple AppState with a
guarded `try?`; an impossible encoding failure calls `preconditionFailure`
rather than silently substituting another state.

- [ ] **Step 1: Move the existing state files and mirrored tests without
  changing behavior**

Use filesystem moves so synchronized Xcode groups discover the new hierarchy.
Update no type names during this step. Run `git status --short` and confirm the
old `AppStateStorageService`, `AppTemplateTests/App/State`, and AppState test
paths are gone.

- [ ] **Step 2: Write failing future-schema and failure-ordering tests**

Add focused tests with literal outcomes:

```swift
@Test
func futureSchemaLoadsInitialReadOnlyWithoutChangingStoredBytes() throws {
    let future = Data(#"{"schemaVersion":2,"future":"preserve-me"}"#.utf8)
    let storage = AppStateStorageSpy(loadResult: .data(future))

    let store = AppStateStore(storage: storage)

    #expect(store.state == .initial)
    #expect(store.persistenceStatus == .readOnly(.unsupportedFutureSchema(2)))
    #expect(storage.currentData == future)
    #expect(storage.savedData.isEmpty)
    #expect(storage.removeCallCount == 0)
}

@Test
func failedSaveRejectsMutationAndMakesStoreReadOnly() {
    let storage = AppStateStorageSpy(saveError: StorageError.failed)
    let store = AppStateStore(storage: storage)
    let proposed = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )

    #expect(store.setState(proposed) == .rejected(.saveFailed))
    #expect(store.state == .initial)
    #expect(store.persistenceStatus == .readOnly(.saveFailed))
}

@Test
func failedLoadUsesInitialReadOnlyWithoutRepairing() {
    let storage = AppStateStorageSpy(loadError: StorageError.failed)
    let store = AppStateStore(storage: storage)

    #expect(store.state == .initial)
    #expect(store.persistenceStatus == .readOnly(.loadFailed))
    #expect(storage.savedData.isEmpty)
}
```

Extend the spy with independent `loadError`/`saveError`, `currentData`, and
thread-safe call counters. Initialize the store with
`encode: { _ in throw EncodingErrorStub.failed }` and assert
`.rejected(.encodingFailed)` leaves memory unchanged.

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppStateStoreTests
```

Expected: compilation/test failures because the throwing contract, status,
typed result, and future-schema preservation do not exist.

- [ ] **Step 4: Implement throwing storage and load/repair semantics**

Implement the store in this exact order:

```swift
@discardableResult
func setState(_ proposedState: AppState) -> AppStateMutationResult {
    guard proposedState != state else { return .unchanged }
    if case let .readOnly(failure) = persistenceStatus {
        return .rejected(failure)
    }
    let data: Data
    do { data = try encode(proposedState) }
    catch { return reject(.encodingFailed) }
    do { try storage.save(data) }
    catch { return reject(.saveFailed) }
    state = proposedState
    return .persisted
}

private func reject(
    _ failure: AppStatePersistenceFailure
) -> AppStateMutationResult {
    persistenceStatus = .readOnly(failure)
    return .rejected(failure)
}
```

At initialization: missing → writable initial/no write; valid schema 1 →
writable decoded state; invalid/corrupt/schema below 1 → initial plus exactly
one repair write; schema above 1 → read-only initial/no write; thrown load →
read-only initial/no write. A failed repair becomes read-only with the encode or
save category. Logging must not interpolate payloads or underlying errors.

- [ ] **Step 5: Implement and test deterministic in-memory storage**

Its `load`, `save`, and `remove` operate on one lock-protected optional `Data`.
Tests must prove missing load, save-then-load, remove-then-missing, and isolation
from a separate instance.

- [ ] **Step 6: Run state tests and affected coordinator tests GREEN**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/InMemoryAppStateStorageTests \
  -only-testing:AppTemplateTests/AppFlowCoordinatorTests
```

Expected: all selected tests pass with no warnings.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/ApplicationState AppTemplate/App/AppDependencies \
  AppTemplateTests/App/ApplicationState AppTemplateTests/App/Navigation \
  AppTemplateTests/TestSupport
git commit -m "refactor: harden application state persistence"
```

---

### Task 2: Semantic Flow Results and Narrow Router Capabilities

**Files:**

- Create: `AppTemplate/App/Navigation/Routing/AppFlowActionResult.swift`
- Create: `AppTemplate/App/Navigation/Routing/IAuthenticationActions.swift`
- Create: `AppTemplate/App/Navigation/Routing/IAuthenticationCancellation.swift`
- Create: `AppTemplate/App/Navigation/Routing/IOnboardingActions.swift`
- Create: `AppTemplate/App/Navigation/Routing/IMaintenanceActions.swift`
- Modify: `AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift`
- Modify: `AppTemplate/App/Navigation/Core/FlowRouter.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Delete: `AppTemplate/App/Navigation/Core/IRouter.swift`
- Delete: `AppTemplate/App/Navigation/Routing/IAppFlowRouter.swift`
- Modify: all ViewModels listed in the constructor table below and their Views
- Modify: `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Modify: `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- Modify: `AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift`
- Test: `AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift`
- Test: `AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift`
- Test: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Test: `AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift`
- Test: all affected ViewModel test files

**Interfaces:**

```swift
nonisolated
enum AppFlowActionResult: Equatable, Sendable {
    case unchanged
    case applied(flow: AppFlow, didTransition: Bool)
    case rejected(AppStatePersistenceFailure)
}

@MainActor
protocol IAppFlowCoordinator:
    IAuthenticationActions,
    IOnboardingActions,
    IMaintenanceActions {}

@MainActor
protocol IAuthenticationCancellation: AnyObject {
    func cancelAuthentication()
}
```

`AppFlowRouter.setFlow(_:)` stays a concrete method used only by
infrastructure tests. No protocol or feature ViewModel exposes it.

- [ ] **Step 1: Write failing coordinator-result tests**

Add these behavioral cases:

```swift
@Test
func rejectedSignInDoesNotChangeStateOrRootTransition() throws {
    let sut = try makeSUT(state: .initial, saveError: StorageError.failed)
    let transition = sut.router.transition

    let result = sut.coordinator.signIn()

    #expect(result == .rejected(.saveFailed))
    #expect(sut.store.state == .initial)
    #expect(sut.router.transition == transition)
}

@Test
func unchangedPolicyActionReturnsUnchanged() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state)

    #expect(sut.coordinator.signIn() == .unchanged)
}

@Test
func unchangedStateCanReconcileInfrastructureFlowDrift() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state, visibleFlow: .onboarding)

    #expect(
        sut.coordinator.signIn()
            == .applied(flow: .main, didTransition: true)
    )
}
```

Also construct two `AppRouter` values sharing one `AppFlowRouter`, give both an
Authentication path and pending intent, cancel the first scene, and assert only
its path/intent clears while the shared transition and second scene remain
unchanged. Update the Authentication ViewModel test to inject separate stack,
authentication-action, and cancellation capabilities; cancellation records
only the scene collaborator call.

- [ ] **Step 2: Run coordinator, AppRouter, and Authentication tests and verify RED**

Run the macOS `AppFlowCoordinatorTests`, `AppRouterTests`, and
`AuthenticationViewModelTests`. Expected: current `Void` methods cannot satisfy
the typed assertions, failed storage is not propagated, and cancellation still
uses application-wide raw replacement.

- [ ] **Step 3: Add semantic protocols and implement result propagation**

Each semantic protocol has only its relevant methods and every method is
`@discardableResult`. `AppFlowCoordinator.synchronize` must return
`.rejected` immediately for rejected storage, `.unchanged` when neither state
nor transition changes, and `.applied(flow:didTransition:)` otherwise. Keep the
existing sign-out force-transition and pending-intent policy.

Add `AppRouter: IAuthenticationCancellation` with exactly:

```swift
func cancelAuthentication() {
    authentication.popToRoot()
    pendingIntent = nil
}
```

Thread this separate scene capability through `AppRootView` →
`AuthenticationFlowView` → `AuthenticationView` →
`AuthenticationViewModel`. Keep its Authentication `FlowRouter` separately for
stack and sign-in actions.

- [ ] **Step 4: Refactor `FlowRouter` and test support**

Declare:

```swift
@MainActor
@Observable
final class FlowRouter:
    IFlowRouter,
    IAppFlowCoordinator {
    var path: NavigationPath
    private let appFlowCoordinator: any IAppFlowCoordinator

    init(
        path: NavigationPath = NavigationPath(),
        appFlowCoordinator: any IAppFlowCoordinator
    ) {
        self.path = path
        self.appFlowCoordinator = appFlowCoordinator
    }

    func push<Route: NavigationRoute>(_ route: Route) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = NavigationPath() }
    func replacePath(with path: NavigationPath) { self.path = path }

    @discardableResult
    func signIn() -> AppFlowActionResult { appFlowCoordinator.signIn() }

    @discardableResult
    func signOut() -> AppFlowActionResult { appFlowCoordinator.signOut() }

    @discardableResult
    func completeOnboarding() -> AppFlowActionResult {
        appFlowCoordinator.completeOnboarding()
    }

    @discardableResult
    func restartOnboarding() -> AppFlowActionResult {
        appFlowCoordinator.restartOnboarding()
    }

    @discardableResult
    func setMaintenanceEnabled(_ value: Bool) -> AppFlowActionResult {
        appFlowCoordinator.setMaintenanceEnabled(value)
    }
}
```

Remove `.setFlow` from `AppFlowCoordinatorSpy` and its command enum. Make every
spy semantic method return a configurable `AppFlowActionResult`, defaulting to
`.unchanged`; use real `AppStateStore`/`AppFlowCoordinator` instances whenever
a ViewModel test can assert state or flow instead of asserting a spy call.

- [ ] **Step 5: Refactor each ViewModel to its narrow constructor**

Use this exact mapping; pass the same concrete `FlowRouter` into multiple
parameters when it supplies multiple capabilities:

| ViewModel | Constructor capabilities |
| --- | --- |
| Authentication | `IFlowRouter`, `IAuthenticationActions`, `IAuthenticationCancellation` |
| BrowseList, BrowseDetail, RelatedItems | `IFlowRouter` |
| Home | `IFlowRouter`, `IOnboardingActions`, `IMaintenanceActions` |
| HomeDetails, NavigationGuide | `IFlowRouter` |
| Maintenance | `IMaintenanceActions` |
| Onboarding | `IOnboardingActions` |
| ProjectBasics, ProjectDetails, ProjectOptions, Projects | `IFlowRouter` |
| About | `IFlowRouter` |
| Settings | `IFlowRouter`, `IAuthenticationActions` |

`CreateProjectFlowView` may receive `any IAppFlowCoordinator` only to construct
its independent local `FlowRouter`; this coordinator now contains semantic
capabilities only and cannot replace the root directly.

Replace the two ProjectConfiguration tests that asserted raw forwarding with
one real path-isolation test: pushing the modal flow changes only
`flow.localRouter.path` and leaves the presenting router path unchanged.

- [ ] **Step 6: Run all routing and ViewModel tests GREEN**

Run the entire `AppTemplateTests` target on macOS. Expected: all tests pass;
`rg -n 'IRouter|IAppFlowRouter|\.setFlow' AppTemplate/Features` returns no
matches. Cancellation must not change `AppFlowRouter.transition.id`. The `rg`
check is an API-boundary audit, not a unit test.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/Navigation AppTemplate/Features AppTemplateTests
git commit -m "refactor: narrow app and scene navigation capabilities"
```

---

### Task 3: Schema-4 Navigation Snapshot and Future-Write Gate

**Files:**

- Modify: `AppTemplate/App/Navigation/Snapshots/NavigationSnapshot.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify: `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Test: `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`
- Test: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Test: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`

**Interfaces:**

- `NavigationSnapshot.currentSchemaVersion == 4`.
- Schema 4 adds `let lastAppliedTransitionID: UUID?`.
- `AppRouter.restore(from:)` returns exactly:

```swift
nonisolated
struct NavigationRestoration: Equatable, Sendable {
    let result: NavigationRestorationResult
    let lastAppliedTransitionID: UUID?
}
```

- `NavigationRestorationResult` gains
  `case preservedFutureSchema(Int)`.
- `AppRouter.makeSnapshot(lastAppliedTransitionID:)` creates schema 4 while its
  existing `snapshot` convenience passes nil for router-only tests.
- `AppSceneNavigationLifecycle` exposes `private(set) var restorationResult`,
  `var snapshot` containing the current checkpoint, and
  `var snapshotForPersistence: NavigationSnapshot?` that is nil after a
  future-schema restore.

- [ ] **Step 1: Write failing schema migration and future-preservation tests**

Use hand-written schema-3 and schema-2 JSON fixtures. Assert schema 3 restores
four paths, schema 2 restores Home/Browse/Settings with empty Projects, and
both next encode as schema 4 with a nil checkpoint.

Add:

```swift
@Test
func futureSnapshotDisablesWritesWithoutChangingOriginalBytes() throws {
    let future = Data(#"{"schemaVersion":99,"future":"keep"}"#.utf8)
    var persistedData = future
    let lifecycle = AppSceneNavigationLifecycle(router: makeRouter())

    let replacement = lifecycle.restore(from: future)
    lifecycle.router.home.push(HomeRoute.details)
    if let snapshot = lifecycle.snapshotForPersistence {
        persistedData = try NavigationSnapshotCodec.encode(snapshot)
    }

    #expect(replacement == nil)
    #expect(lifecycle.snapshotForPersistence == nil)
    #expect(lifecycle.restorationResult == .preservedFutureSchema(99))
    #expect(persistedData == future)
}
```

Add a recreation regression: encode a snapshot with checkpoint `T`, recreate a
lifecycle while the app router still exposes transition `T`, restore, push a
route, and prove `T` was skipped rather than resetting the restored history.

- [ ] **Step 2: Run snapshot/lifecycle tests and verify RED**

Expected: schema 4/checkpoint/write gate are absent and future schema currently
returns a reset replacement.

- [ ] **Step 3: Implement schema decoders and restoration result**

Decode schema 4 with the normal codec. Define private schema-3 and schema-2
Decodable values in `AppRouter.swift`. Current/known-old corrupt data resets in
memory and returns a schema-4 replacement. A version above 4 resets only memory,
returns `.preservedFutureSchema(version)`, and never returns replacement data.

- [ ] **Step 4: Restore checkpoint before applying current transition**

In `AppSceneNavigationLifecycle.restore`, assign the decoded checkpoint first,
set the persistence gate from the restoration result, then call
`apply(transition)`. `AppSceneView.persist` must `guard let snapshot =
lifecycle.snapshotForPersistence else { return }` for router changes, root
transitions, queued URLs, and restoration.

- [ ] **Step 5: Run focused and full tests GREEN**

Run `NavigationSnapshotTests`, `AppRouterTests`, and
`AppSceneNavigationLifecycleTests`, then the full macOS unit target. Expected:
all pass with future bytes never supplied to any save path.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Navigation AppTemplateTests/App/Navigation
git commit -m "fix: preserve future scene snapshots"
```

---

### Task 4: Consumer-Visible App-Info Dependency Injection

**Files:**

- Create: `AppTemplate/App/Services/AppInfo/IAppInfoService.swift`
- Create: `AppTemplate/App/Services/AppInfo/AppInfoService.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplate/Features/Settings/Dependencies/SettingsDependencies.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/Features/Settings/Flow/SettingsFlowView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/Model/SettingsModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- Test: `AppTemplateTests/App/Services/AppInfo/AppInfoServiceTests.swift`
- Test: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Test: `AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift`

**Interfaces:**

```swift
nonisolated
protocol IAppInfoService: Sendable {
    var displayName: String { get }
    var version: String { get }
}

nonisolated
struct AppInfoService: IAppInfoService {
    let displayName: String
    let version: String

    init(bundle: Bundle = .main)
    init(displayName: String, version: String)
}

nonisolated
struct SettingsDependencies: Sendable {
    let appInfo: any IAppInfoService
}
```

The Bundle initializer resolves `CFBundleDisplayName`, then `CFBundleName`, then
`"AppTemplate"`; version resolves `CFBundleShortVersionString`, then
`"1.0"`. It stores only Strings and never retains Bundle.

- [ ] **Step 1: Write failing service and composition tests**

Prefer fixed initializer tests for exact values. Assert `AppDependencies.test`
preserves the exact feature scope and `SettingsViewModel` exposes this real
consumer model:

```swift
@Test
func settingsModelUsesInjectedAppMetadata() {
    let info = AppInfoService(displayName: "Preview App", version: "9.8.7")
    let viewModel = SettingsViewModel(
        router: makeTestFlowRouter(),
        authenticationActions: AppFlowCoordinatorSpy(),
        appInfo: info
    )

    #expect(
        viewModel.model
            == SettingsModel(displayName: "Preview App", version: "9.8.7")
    )
}
```

- [ ] **Step 2: Run AppInfo/composition/Settings tests and verify RED**

Expected: service, dependency property, Settings model initializer, and
ViewModel injection do not exist.

- [ ] **Step 3: Implement service and feature dependency scope**

`AppDependencies.live()` constructs `SettingsDependencies(appInfo:
AppInfoService())`. Preview and test factories require explicit storage and
allow fixed `SettingsDependencies`; they must not silently read the live
Bundle when a fixed dependency is supplied.

- [ ] **Step 4: Thread only `SettingsDependencies` through composition**

Pass `dependencies.settings` from `AppTemplateApp` into `AppSceneView`, then
through root and shell into the Settings flow. Do not pass `AppDependencies`
to any ViewModel. `SettingsViewModel` receives `IFlowRouter`,
`IAuthenticationActions`, and `IAppInfoService`; its `SettingsModel` contains
the immutable display name/version rendered by `SettingsView`.

- [ ] **Step 5: Run focused and full tests GREEN**

Run the three focused suites followed by all macOS unit tests. Manually audit:

```bash
rg -n 'AppDependencies' AppTemplate/Features
```

Expected: feature code mentions only its own dependency scope; no ViewModel
stores the app graph.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App AppTemplate/Features/Settings AppTemplateTests
git commit -m "feat: add settings app info dependency"
```

---

### Task 5: Portable Identity, Configured Deep Links, and Swift 6

**Files:**

- Create: `Config/Template.xcconfig`
- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Modify: `AppTemplate/Resources/Info.plist`
- Modify: `AppTemplate/App/Navigation/DeepLinks/DeepLinkParser.swift`
- Test: `AppTemplateTests/App/Navigation/DeepLinks/DeepLinkParserTests.swift`
- Test: `AppTemplateTests/Project/ProjectConfigurationTests.swift`
- Modify: Swift sources that expose genuine Swift 6 compiler errors only

**Interfaces:**

```text
APP_BUNDLE_IDENTIFIER = com.example.AppTemplate
APP_URL_SCHEME = apptemplate
```

App target identifier is `$(APP_BUNDLE_IDENTIFIER)`; unit tests are
`$(APP_BUNDLE_IDENTIFIER).tests`. UI tests will add `.uitests` in Task 11.

- [ ] **Step 1: Write a failing configured-scheme behavior test**

Add:

```swift
@Test
func injectedSchemeAcceptsOnlyThatScheme() throws {
    let parser = DeepLinkParser(scheme: "renamed-template")

    #expect(
        parser.parse(
            try #require(URL(string: "renamed-template://settings"))
        ) == .success(.selectSection(.settings))
    )
    #expect(
        parser.parse(
            try #require(URL(string: "apptemplate://settings"))
        ) == .failure(.unsupportedScheme)
    )
}
```

The live default reads the first registered scheme from the main bundle's
`CFBundleURLTypes`; tests inject a literal scheme.

- [ ] **Step 2: Run DeepLinkParser tests and verify RED**

Expected: the parser has no scheme initializer and still hardcodes
`apptemplate`.

- [ ] **Step 3: Implement configured parser behavior and run GREEN**

Keep URL path tokens and fallback behavior unchanged. Add a pure Bundle helper
that safely validates the nested plist shape and falls back to `apptemplate`
only when the bundle contains no registered scheme.

- [ ] **Step 4: Add xcconfig and attach it to project Debug/Release configs**

Add one PBX file reference/group for `Config/Template.xcconfig`, set it as the
base configuration for project Debug and Release, update app/test product
identifiers to the variables above, and change Info.plist URL name/scheme to
`$(PRODUCT_BUNDLE_IDENTIFIER)` / `$(APP_URL_SCHEME)`. Remove every
`DEVELOPMENT_TEAM` assignment while retaining automatic signing.

Remove the unit test that hardcodes the original developer's bundle identifier.
Keep the functional test that reads the built app's URL registration and proves
the configured scheme is actually present.

- [ ] **Step 5: Enable Swift 6 in app and unit-test configurations**

Set `SWIFT_VERSION = 6.0` in Debug and Release for both current targets. Do not
change deployment targets, actor-isolation settings, or service behavior. Fix
only compiler-diagnosed isolation/Sendable issues, preserving the explicit
`nonisolated` value-type style.

- [ ] **Step 6: Verify project configuration and builds**

Run:

```bash
plutil -lint AppTemplate/Resources/Info.plist
xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate \
  -showBuildSettings -configuration Debug | \
  rg 'PRODUCT_BUNDLE_IDENTIFIER|SWIFT_VERSION|DEVELOPMENT_TEAM|APP_URL_SCHEME'
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: app/test identifiers derive from `com.example.AppTemplate`, Swift is
6.0, no team is set, and all unit tests pass without warnings.

- [ ] **Step 7: Commit**

```bash
git add Config AppTemplate.xcodeproj/project.pbxproj \
  AppTemplate/Resources/Info.plist AppTemplate/App/Navigation/DeepLinks \
  AppTemplateTests
git commit -m "build: make template identity portable"
```

---

### Task 6: Replaceable Assets and Repository Hygiene

**Files:**

- Modify: `AppTemplate/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: PNG files referenced by that AppIcon catalog
- Modify: `AppTemplate/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `.gitignore`
- Delete: `AppTemplate.xcodeproj/xcuserdata/aurora.xcuserdatad/xcschemes/xcschememanagement.plist`

**Interfaces:**

- The base icon is a neutral 1024×1024 navigation/architecture motif with no
  text, personal mark, or product-specific branding.
- Populate iOS default/dark/tinted 1024 slots and macOS 16, 32, 128, 256, 512
  point slots at 1×/2×.
- Use exact filenames `AppIcon-iOS.png`, `AppIcon-iOS-Dark.png`,
  `AppIcon-iOS-Tinted.png`, and `AppIcon-mac-{16,32,128,256,512}.png` with
  matching `@2x` filenames.
- Accent light sRGB is `(0.20, 0.45, 0.95, 1.0)` and dark sRGB is
  `(0.35, 0.60, 1.00, 1.0)`.

- [ ] **Step 1: Generate and inspect the 1024 icon source**

Use the session's `imagegen` skill for one text-free geometric source image.
Inspect it visually before deriving variants. Reject any output containing
letters, words, logos, faces, or photographic detail.

- [ ] **Step 2: Create deterministic variants and catalog filenames**

Use the accepted 1024 image for the default icon, create a dark-background
variant and a high-contrast monochrome tinted variant, and use `sips -z` from
the default image for the ten macOS pixel sizes. Every `Contents.json` image
entry must have an existing filename and the expected pixel dimensions.

- [ ] **Step 3: Define adaptive accent and expand ignore rules**

Add light/dark accent components. Ignore `.DS_Store`, `xcuserdata/`,
`*.xcuserstate`, `DerivedData/`, `.build/`, `build/`, `*.local.xcconfig`,
SwiftPM scratch, and common editor state while keeping
`Config/Template.xcconfig` tracked. Remove only the tracked personal
`xcuserdata` file; preserve the shared scheme.

- [ ] **Step 4: Verify assets and repository shape**

Run:

```bash
find AppTemplate/Resources/Assets.xcassets/AppIcon.appiconset -name '*.png' \
  -exec sips -g pixelWidth -g pixelHeight {} \;
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
if git ls-files | rg 'xcuserdata|\.DS_Store'; then exit 1; fi
if git check-ignore Config/Template.xcconfig; then exit 1; fi
```

Expected: asset compilation/build succeeds, dimensions match slots, no personal
state is tracked, and the shared config is not ignored.

- [ ] **Step 5: Commit**

```bash
git add .gitignore AppTemplate/Resources/Assets.xcassets \
  AppTemplate.xcodeproj/xcuserdata
git commit -m "chore: add replaceable template assets"
```

---

### Task 7: String Catalog and Stable Localizable Route Data

**Files:**

- Create: `AppTemplate/Resources/Localizable.xcstrings`
- Modify: all feature `View/*.swift` files containing user-visible static copy
- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/Utilities/UIComponents/{EmptyStateView,ErrorStateView,LoadingStateView}.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/Model/AboutModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/Navigation/AboutRoute.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/ViewModel/AboutViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/About/View/AboutView.swift`
- Modify: `AppTemplate/Features/Settings/Screens/PlatformDetails/ViewModel/PlatformDetailsViewModel.swift`
- Modify: `AppTemplate/Features/Settings/Screens/PlatformDetails/View/PlatformDetailsView.swift`
- Modify: `AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift`
- Test: corresponding About/PlatformDetails ViewModel tests

**Interfaces:**

```swift
nonisolated
enum AppPlatform: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case iOS
    case iPadOS
    case macOS
}

nonisolated
enum AboutRoute: NavigationRoute {
    case platform(AppPlatform)
}
```

Static reusable component parameters use `LocalizedStringResource`. Injected
app metadata, stable IDs, deep-link segments, project/task IDs, and service
errors stay `String` and render with `Text(verbatim:)`.

- [ ] **Step 1: Write failing stable-platform route tests**

Change About tests to call `openPlatform(.iPadOS)`, restore the route through a
`NavigationPath` snapshot, and assert the destination ViewModel stores exactly
`.iPadOS`, not display text.

- [ ] **Step 2: Run About/PlatformDetails/snapshot tests and verify RED**

Expected: route and ViewModels currently accept arbitrary Strings.

- [ ] **Step 3: Implement stable platform data and local rendering**

Switch the route and ViewModels to `AppPlatform`. Add a view-only computed
`LocalizedStringResource` mapping: `iOS → "iOS 26"`, `iPadOS → "iPadOS 26"`,
`macOS → "macOS 26"`. Never encode localized text into a route.

- [ ] **Step 4: Convert reusable UI component inputs**

Use:

```swift
struct LoadingStateView: View {
    let title: LocalizedStringResource
    var body: some View { ProgressView(title) }
}
```

Apply the same static-resource rule to Empty/Error titles and template
messages. Keep a distinct explicit initializer/property for truly dynamic
error text if a call site needs one; do not reinterpret server text as a key.

- [ ] **Step 5: Add complete source-language catalog entries**

Add English source entries for tab labels, navigation titles, section headers,
buttons, sheet/alert copy, explanatory copy, reusable component previews, and
the three platform titles across all feature View files. Replace every `+`
concatenation used for user-visible prose with one complete resource string.
NavigationGuide row titles become `LocalizedStringResource`; their IDs and SF
Symbol names remain stable Strings.

- [ ] **Step 6: Verify localization compilation and behavior GREEN**

Run the affected tests plus app builds for macOS and iPhone. Inspect the build
log for String Catalog warnings. Audit remaining concatenation with:

```bash
rg -n 'Text\(|Button\(|Section\(|navigationTitle\(|alert\(' \
  AppTemplate/Features AppTemplate/App AppTemplate/Utilities
rg -n '"[^"\n]+"\s*\+' AppTemplate -g '*.swift'
```

Expected: dynamic identifiers are the only nonlocalized values and no visible
sentence is assembled from fragments.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/Resources/Localizable.xcstrings AppTemplate/App \
  AppTemplate/Features AppTemplate/Utilities AppTemplateTests
git commit -m "feat: localize template interface"
```

---

### Task 8: Dynamic-Type-Safe Adaptive Screen Layouts

**Files:**

- Create: `AppTemplate/Utilities/UIComponents/AdaptiveContentContainer.swift`
- Create: `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`
- Modify Views for Onboarding, Authentication, AuthenticationHelp,
  Maintenance, QuickStart, BrowseOptions, GuideTopic, and PlatformDetails

**Interfaces:**

```swift
struct AdaptiveContentContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
```

It provides vertical scrolling, centered content, horizontal/vertical padding,
`.frame(maxWidth: 640)`, a full-width outer frame, and
`.scrollBounceBehavior(.basedOnSize)`.

- [ ] **Step 1: Implement the focused adaptive container**

Use the exact interface/body above. Keep it stateless, screen-independent, and
free of routing or dependencies.

- [ ] **Step 2: Adopt it on all eight screens**

Replace their root unscrollable VStacks with the container. Authentication
uses `ViewThatFits(in: .horizontal)` with an HStack candidate and a VStack
candidate for Cancel, Help, and Continue. Preserve button actions and route
ownership exactly.

- [ ] **Step 3: Improve accessibility semantics**

Mark adjacent decorative SF Symbols hidden in Authentication,
AuthenticationHelp, QuickStart, GuideTopic, and PlatformDetails. Do not hide
symbols that are the sole label of an interactive control.

- [ ] **Step 4: Add a minimal deterministic preview fixture and render previews**

Create `PreviewFixtures` with fresh `InMemoryAppStateStorage` and fixed
Settings app-info values, then render Authentication, Onboarding, and
Maintenance previews with
`.environment(\.dynamicTypeSize, .accessibility5)` and confirm content remains
reachable by scrolling and actions stack vertically when needed.

- [ ] **Step 5: Verify cross-platform builds**

Build macOS and iPhone with warnings as errors. The later UI-test task exercises
the same controls in launched applications.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/PreviewSupport AppTemplate/Utilities \
  AppTemplate/Features AppTemplateTests
git commit -m "feat: adapt screens for accessibility sizes"
```

---

### Task 9: Deterministic Previews and Native macOS Settings Scene

**Files:**

- Modify: `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: independent flow View files for Authentication, Onboarding, Home,
  Browse, Projects, Settings, Maintenance, and CreateProject
- Create: `AppTemplate/Features/Settings/Screens/AppSettings/Model/AppSettingsModel.swift`
- Create: `AppTemplate/Features/Settings/Screens/AppSettings/State/AppSettingsState.swift`
- Create: `AppTemplate/Features/Settings/Screens/AppSettings/Navigation/AppSettingsRoute.swift`
- Create: `AppTemplate/Features/Settings/Screens/AppSettings/ViewModel/AppSettingsViewModel.swift`
- Create: `AppTemplate/Features/Settings/Screens/AppSettings/View/AppSettingsView.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- Test: `AppTemplateTests/Features/Settings/Screens/AppSettings/AppSettingsViewModelTests.swift`

**Interfaces:**

- `PreviewFixtures` is an internal, deterministic helper used only by preview
  declarations. It uses `InMemoryAppStateStorage`, fixed app name
  `"AppTemplate Preview"`, fixed version `"1.0"`, and never reads/writes
  UserDefaults.
- `AppSettingsViewModel` receives only `IAppInfoService` and exposes an
  `AppSettingsModel(displayName:version:)`.
- `AppSettingsRoute` is an empty, nonconforming reserved enum because the
  leaf Settings screen owns no outgoing route.
- The macOS Settings scene receives `dependencies.settings`; it receives no
  `AppRouter`, coordinator, flow router, or SceneStorage.

- [ ] **Step 1: Write a failing AppSettings ViewModel behavior test**

Assert fixed service metadata becomes the screen model and that changing the
injected fixed values changes the model's rendered inputs. Expected RED: the
scaffold and AppSettings ViewModel do not exist. View construction is covered
by the subsequent cross-platform compiler and UI-test gates.

- [ ] **Step 2: Implement the complete AppSettings screen scaffold**

The View uses a native macOS `Form`/`Section`, renders display name and version
verbatim, applies a compact Settings-appropriate frame/scene padding, and has
no navigation container. Model and State follow the existing multiline
`nonisolated` formatting convention; the reserved Route has no fake case.

- [ ] **Step 3: Add the native scene and SettingsLink**

In `AppTemplateApp.body`:

```swift
#if os(macOS)
Settings {
    AppSettingsView(dependencies: dependencies.settings)
}
#endif
```

Add a macOS-only `SettingsLink` to the existing Settings tab. The iOS/iPadOS
Settings content and purpose stay unchanged.

- [ ] **Step 4: Replace the UserDefaults preview with fixed fixtures**

Delete `makePreviewAppFlowCoordinator()` from `ContentView`. Provide helper
factories that encode explicit AppState into a fresh in-memory store and return
the coordinator, scene composition, per-flow router, and fixed Settings scope.
No helper may use `.standard`, `suiteName`, `Bundle.main`, network, or database.

- [ ] **Step 5: Add independent deterministic flow previews**

Add one `#Preview` for each of Authentication, Onboarding, Home, Browse,
Projects, Settings, Maintenance, and CreateProject. Add accessibility-size
previews from Task 8 for Authentication, Onboarding, and Maintenance. Each
preview constructs a fresh fixture so navigation state is not shared.

- [ ] **Step 6: Run focused tests and cross-platform builds GREEN**

Run AppSettings/Settings tests, then build macOS and iPhone with warnings as
errors. Open the macOS Settings preview or scene and verify the screen renders
without creating a second coordinator.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App AppTemplate/Features/Settings \
  AppTemplate/Features/*/Flow AppTemplateTests
git commit -m "feat: add deterministic previews and mac settings"
```

---

### Task 10: Explicit UI-Test Launch Configuration

**Files:**

- Create: `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Test: `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`

**Interfaces:**

```swift
nonisolated
enum UITestRoot: String, Equatable, Sendable {
    case onboarding
    case authentication
    case main
    case maintenance
}

nonisolated
enum AppLaunchConfiguration: Equatable, Sendable {
    case live
    case uiTesting(initialState: AppState)

    init(arguments: [String])
}
```

Recognized arguments are exactly `--ui-testing --ui-test-root <root>`. The
parser requires one marker and one valid root value; missing marker, missing
value, unknown value, or duplicate root options resolve to `.live`.

- [ ] **Step 1: Write table-driven failing parser tests**

Use literal expected AppState values:

```swift
@Test(arguments: [
    ("onboarding", AppState.initial),
    ("authentication", AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )),
    ("main", AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )),
    ("maintenance", AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    ))
])
func explicitUITestRootMapsToState(root: String, expected: AppState) {
    #expect(
        AppLaunchConfiguration(
            arguments: ["AppTemplate", "--ui-testing", "--ui-test-root", root]
        ) == .uiTesting(initialState: expected)
    )
}
```

Add invalid-input rows proving root-only, marker-only, unknown, and duplicate
options are `.live`.

- [ ] **Step 2: Run parser tests and verify RED**

Expected: missing types.

- [ ] **Step 3: Implement the pure parser and UI-test dependency factory**

The parser must not read ProcessInfo itself. Add
`AppDependencies.uiTesting(initialState:)` using a fresh
`InMemoryAppStateStorage` and fixed app info `"AppTemplate UI Tests"` / `"1.0"`.

- [ ] **Step 4: Select composition once in `AppTemplateApp.init`**

Parse `ProcessInfo.processInfo.arguments` once. `.live` calls only
`AppDependencies.live()`. `.uiTesting` calls only the in-memory factory. Both
then use the same store/router/coordinator construction path.

- [ ] **Step 5: Run parser, composition, and full unit tests GREEN**

Expected: all pass; launching without the exact marker retains UserDefaults
live composition.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Entry AppTemplate/App/AppDependencies AppTemplateTests
git commit -m "test: add deterministic app launch roots"
```

---

### Task 11: Cross-Platform UI-Test Target and Stable Accessibility Boundaries

**Files:**

- Create: `AppTemplateUITests/AppTemplateUITests.swift`
- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Modify: `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`
- Modify: root and interaction Views receiving identifiers listed below

**Interfaces:**

Stable identifiers:

```text
screen.onboarding
screen.authentication
screen.home
screen.browse
screen.settings
screen.navigationGuide
screen.browseOptions
screen.appSettings
tab.home
tab.browse
tab.projects
tab.settings
action.openNavigationGuide
action.openBrowseOptions
action.dismissBrowseOptions
action.openSettingsWindow
```

The UI-test target supports `iphoneos`, `iphonesimulator`, and `macosx`, uses
Swift 6/default MainActor/approachable concurrency, has bundle identifier
`$(APP_BUNDLE_IDENTIFIER).uitests`, and targets `AppTemplate`.

- [ ] **Step 1: Add the filesystem-synchronized UI-test target**

Add PBX product reference, synchronized root group, sources/frameworks/resources
phases, app target dependency/proxy, native target, Debug/Release configs,
configuration list, project target attributes, and product-group entry. Update
the shared scheme BuildAction and TestAction with one parallelizable UI-test
TestableReference.

- [ ] **Step 2: Write UI tests against the wished-for identifiers**

Use XCTest and this launch helper:

```swift
private func launch(root: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-test-root", root]
    app.launch()
    return app
}
```

Tests:

1. Launch `onboarding`; assert `screen.onboarding` exists.
2. Launch `main`; select `tab.browse`; assert `screen.browse` exists.
3. Launch `main`; activate `action.openNavigationGuide`; assert
   `screen.navigationGuide` exists.
4. Launch `main`; select Browse; activate `action.openBrowseOptions`; assert
   `screen.browseOptions`, activate `action.dismissBrowseOptions`, and assert it
   disappears.
5. Under `#if os(macOS)`, launch `main`; select Settings; activate
   `action.openSettingsWindow`; assert `screen.appSettings` exists.

Use `waitForExistence(timeout: 5)` and identifiers, never localized labels.

- [ ] **Step 3: Run macOS UI tests and verify RED**

Run the new UI tests on macOS. Expected: the app launches at deterministic
roots, but assertions fail because semantic accessibility identifiers are not
installed yet. Fix target wiring errors until the tests execute and fail for
this expected reason.

- [ ] **Step 4: Add stable identifiers at semantic boundaries**

Use the identifiers above only on root screens, tab labels, and tested actions.
Change concise `Tab("…")` declarations to label closures when necessary so the
identifier belongs to the selectable tab, not the tab content. Do not identify
every Text/row. Any failed selector gets a behavioral View fix and a rerun, not
a sleep increase.

- [ ] **Step 5: Run all three platform suites GREEN**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: unit and UI tests pass on all destinations without warnings.

- [ ] **Step 6: Commit**

```bash
git add AppTemplateUITests AppTemplate.xcodeproj AppTemplate
git commit -m "test: add cross-platform ui coverage"
```

---

### Task 12: CI Matrix and Current Adopter Documentation

**Files:**

- Create: `.github/workflows/ci.yml`
- Create: `docs/README.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/CUSTOMIZATION.md`
- Create: `docs/RELEASE_CHECKLIST.md`
- Rewrite: `README.md`
- Modify: project/docs only if final verification finds a documented mismatch

**Interfaces:**

- Workflow uses `actions/checkout@v6`, `actions/upload-artifact@v7`,
  `runs-on: macos-26`, and selects `/Applications/Xcode_26.6.app`.
- Matrix destinations are exactly macOS, iPhone 17 / iOS 26.5, and iPad (A16)
  / iOS 26.5.
- Every matrix entry has unique DerivedData and xcresult paths; xcresults upload
  only on failure.

- [ ] **Step 1: Add the exact CI matrix**

The job must run checkout, select/print Xcode, print available destinations,
then execute:

```bash
set -o pipefail
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$RUNNER_TEMP/DerivedData-$MATRIX_NAME" \
  -resultBundlePath "$RUNNER_TEMP/AppTemplate-$MATRIX_NAME.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Use matrix `include` entries with shell-safe names `macos`, `iphone`, `ipad`
and the exact destinations above. Upload the matching xcresult directory with
`if: failure()` and `if-no-files-found: error`.

- [ ] **Step 2: Write current architecture and customization documentation**

`ARCHITECTURE.md` documents app/scene ownership, schema-1 AppState, schema-4
scene snapshots/checkpoints, narrow router protocols, semantic flow results,
scene-local cancellation, feature-scoped DI, and local/remote empty service
examples. `CUSTOMIZATION.md` gives exact rename steps for
`APP_BUNDLE_IDENTIFIER`, `APP_URL_SCHEME`, display name, assets, app-info
service, features, and signing.

- [ ] **Step 3: Write release checklist and docs index**

The checklist covers bundle/signing, icons/accent, localization, unit/UI tests,
three CI destinations, permissions/entitlements, app-state migration review,
and store metadata. It must prominently state: App Store distribution remains
blocked until the adopter adds and validates the correct
`PrivacyInfo.xcprivacy`; this task intentionally does not add one.

`docs/README.md` labels `docs/superpowers/specs` and `docs/superpowers/plans` as
historical engineering records. Root README links only to current docs for live
instructions and no longer describes `IRouter`, raw ViewModel `setFlow`,
schema 3, the old state folder, or empty Settings dependencies.

- [ ] **Step 4: Validate workflow syntax and documentation claims**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml", aliases: true)'
git diff --check
rg -n 'IRouter|IAppFlowRouter|schema-3|AppStateStorageService' \
  README.md docs/README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md
```

The YAML command and diff check must exit 0; the `rg` audit must return no stale
live-architecture claims. Source code—not historical docs—is the authority for
every documented signature and folder path.

- [ ] **Step 5: Run fresh full verification on every supported destination**

Use separate paths and warnings as errors:

```bash
verification_root=$(mktemp -d /tmp/apptemplate-verification.XXXXXX)

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$verification_root/DerivedData-macos" \
  -resultBundlePath "$verification_root/AppTemplate-macos.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -derivedDataPath "$verification_root/DerivedData-iphone" \
  -resultBundlePath "$verification_root/AppTemplate-iphone.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -derivedDataPath "$verification_root/DerivedData-ipad" \
  -resultBundlePath "$verification_root/AppTemplate-ipad.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$verification_root/Build-macos" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$verification_root/Build-ios" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

plutil -lint AppTemplate/Resources/Info.plist
find AppTemplate/Resources/Assets.xcassets -name Contents.json -print0 | \
  xargs -0 -n1 plutil -lint
git diff --check
if git ls-files | rg 'xcuserdata|\.xcuserstate|DerivedData|^build/|^\.build/'; \
  then exit 1; fi
```

Expected: all tests/builds exit 0 with no warnings; every plist/catalog JSON
validates; no tracked user state or build product is reported.

- [ ] **Step 6: Commit**

```bash
git add .github README.md docs
git commit -m "ci: verify template across apple platforms"
```

---

## Final Review Gate

After Task 12, generate one review package from the branch merge-base through
HEAD. Dispatch an independent whole-branch reviewer with the approved design,
this plan, the SDD ledger's deferred findings, and the complete diff. Fix all
Critical/Important findings in one reviewed fix wave, rerun the three full
suites, and only then use `superpowers:finishing-a-development-branch`.
