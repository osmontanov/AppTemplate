# Persisted App State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist authentication, onboarding, and maintenance facts and use them to select one shared root flow without coupling storage to navigation.

**Architecture:** A versioned `AppStateStore` owns three Boolean facts through an injected `UserDefaults` adapter. A pure `AppFlowPolicy` resolves those facts, while one app-scoped `AppFlowCoordinator` performs semantic mutations and delegates root transitions to the existing `AppFlowRouter`; scene paths and pending intents remain owned by each window.

**Tech Stack:** Swift, SwiftUI Observation, Foundation `UserDefaults`, OSLog, Swift Testing, Xcode 26, iOS 26, iPadOS 26, macOS 26.

## Global Constraints

- Follow `docs/superpowers/specs/2026-07-30-persisted-app-state-design.md`.
- Persist only `isAuthenticated`, `hasCompletedOnboarding`,
  `isMaintenanceEnabled`, and `schemaVersion`.
- Never persist credentials, tokens, passwords, `AppFlow`, pending intents, or
  scene navigation paths in app state.
- Resolve root flow in this exact order: Onboarding, Authentication,
  Maintenance, Main.
- Keep public `setFlow(_:)` non-persistent and preserve its current reset
  behavior: Main replays pending intent; non-Main discards it.
- Preserve pending deep links through semantic Onboarding, Authentication, and
  Maintenance gates; replay them only on semantic entry to Main.
- Effective sign-out discards pending intents, including when Authentication
  is already displayed by a temporary raw transition.
- Share `AppStateStore`, `AppFlowCoordinator`, and `AppFlowRouter` across all
  windows; keep every `AppRouter`, `NavigationPath`, snapshot, and pending
  intent scene-local.
- Keep LocalDatabase and Remote as empty, unrelated service examples.
- Do not add `InMemoryAppStateStorage`, a singleton, service locator,
  navigation closure, `AnyView`, `fatalError`, force cast, or ViewModel
  environment lookup.
- Keep `nonisolated` on its own line.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`; file-system-synchronized
  groups discover new files automatically.
- Preserve the user's unstaged trailing-space change in
  `AppTemplate/App/Entry/AppTemplateApp.swift`.
- At execution time, first use `superpowers:using-git-worktrees` and implement
  on a `codex/` branch in an isolated worktree.
- Write each behavior test first, observe the expected failure, implement the
  minimum production change, rerun the focused test, and commit only that
  task's files.

---

## File Map

### New production files

- `AppTemplate/App/Models/State/AppState.swift` — versioned,
  navigation-independent persisted value.
- `AppTemplate/App/State/Storage/AppStateStorageLoadResult.swift` — distinguishes
  missing, valid Data, and wrong-typed stored values.
- `AppTemplate/App/State/Storage/IAppStateStorage.swift` — synchronous,
  Sendable raw-data boundary.
- `AppTemplate/App/State/Storage/UserDefaultsAppStateStorage.swift` — stable-key
  UserDefaults adapter.
- `AppTemplate/App/State/Diagnostics/AppStateLogger.swift` — payload-free app
  state recovery logging.
- `AppTemplate/App/State/AppStateStore.swift` — hydration, validation, repair,
  mutation, and idempotent persistence.
- `AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift` — pure eight-case
  state-to-flow resolver.
- `AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift` — semantic
  screen-facing flow commands.
- `AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift` — coordinates
  persistent facts with pure navigation transitions.

### New test support and suites

- `AppTemplateTests/TestSupport/AppStateStorageSpy.swift` — lock-protected
  synchronous storage spy.
- `AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift` — records raw and
  semantic router commands and creates explicit local routers.
- `AppTemplateTests/App/Models/State/AppStateTests.swift`
- `AppTemplateTests/App/State/Storage/UserDefaultsAppStateStorageTests.swift`
- `AppTemplateTests/App/State/AppStateStoreTests.swift`
- `AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift`
- `AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift`

### Existing production integration files

- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Entry/AppTemplateApp.swift`
- `AppTemplate/App/Entry/ContentView.swift`
- `AppTemplate/App/Navigation/Routing/AppFlowRouter.swift`
- `AppTemplate/App/Navigation/Core/IRouter.swift`
- `AppTemplate/App/Navigation/Core/FlowRouter.swift`
- `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- `AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift`
- the Authentication, Onboarding, Home, Maintenance, and Settings root-action
  ViewModels and Views.

---

### Task 1: Add the versioned state value and UserDefaults storage boundary

**Files:**

- Create: `AppTemplate/App/Models/State/AppState.swift`
- Create:
  `AppTemplate/App/State/Storage/AppStateStorageLoadResult.swift`
- Create: `AppTemplate/App/State/Storage/IAppStateStorage.swift`
- Create:
  `AppTemplate/App/State/Storage/UserDefaultsAppStateStorage.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Create: `AppTemplateTests/App/Models/State/AppStateTests.swift`
- Create:
  `AppTemplateTests/App/State/Storage/UserDefaultsAppStateStorageTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Consumes: Foundation `Data`, `JSONEncoder`, `JSONDecoder`, and
  `UserDefaults`.
- Produces:
  `AppState.initial`,
  `AppStateStorageLoadResult`,
  `IAppStateStorage`,
  `UserDefaultsAppStateStorage`,
  and `AppDependencies.appStateStorage`.
- Exact storage methods:
  `load() -> AppStateStorageLoadResult`,
  `save(_ data: Data)`,
  and `remove()`.

- [ ] **Step 1: Write failing AppState tests**

Create:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct AppStateTests {
    @Test
    func initialStateUsesCurrentSchemaAndSafeFlags() {
        let state = AppState.initial

        #expect(state.schemaVersion == 1)
        #expect(!state.isAuthenticated)
        #expect(!state.hasCompletedOnboarding)
        #expect(!state.isMaintenanceEnabled)
    }

    @Test
    func codingRoundTripPreservesEveryFieldAndOnlyExpectedKeys() throws {
        let source = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let data = try JSONEncoder().encode(source)
        let restored = try JSONDecoder().decode(AppState.self, from: data)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(restored == source)
        #expect(
            Set(object.keys) == [
                "schemaVersion",
                "isAuthenticated",
                "hasCompletedOnboarding",
                "isMaintenanceEnabled"
            ]
        )
    }
}
```

- [ ] **Step 2: Write failing UserDefaults adapter tests**

Create:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct UserDefaultsAppStateStorageTests {
    @Test
    func dataRoundTripsUnderTheStableKeyAndCanBeRemoved() throws {
        let suiteName = "AppTemplateTests.AppState.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = UserDefaultsAppStateStorage(userDefaults: defaults)
        let data = Data([0x01, 0x02, 0x03])

        #expect(storage.load() == .missing)

        storage.save(data)

        #expect(storage.load() == .data(data))
        #expect(
            defaults.data(forKey: UserDefaultsAppStateStorage.key) == data
        )

        storage.remove()

        #expect(storage.load() == .missing)
    }

    @Test
    func existingNonDataValueIsReportedAsInvalid() throws {
        let suiteName = "AppTemplateTests.AppState.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            "not-data",
            forKey: UserDefaultsAppStateStorage.key
        )
        let storage = UserDefaultsAppStateStorage(userDefaults: defaults)

        #expect(storage.load() == .invalidValue)
    }
}
```

Extend `AppDependenciesTests` so `live()` exposes
`UserDefaultsAppStateStorage`, and so preview/test factories preserve one
injected reference. Add `import Foundation` to that test file:

```swift
let appStateStorage = InjectedAppStateStorage()
let dependencies = AppDependencies.preview(
    appStateStorage: appStateStorage,
    localDatabaseService: localDatabaseService,
    remoteService: remoteService
)
let resolved = try #require(
    dependencies.appStateStorage as? InjectedAppStateStorage
)
#expect(resolved === appStateStorage)
```

Use the same assertion in `testGraphKeepsInjectedServices()`, and add:

```swift
nonisolated
private final class InjectedAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    func load() -> AppStateStorageLoadResult { .missing }
    func save(_ data: Data) {}
    func remove() {}
}
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppStateTests \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/AppDependenciesTests
```

Expected: exit 65 because the AppState and storage declarations do not exist.

- [ ] **Step 4: Implement the state and storage value types**

`AppState.swift`:

```swift
import Foundation

nonisolated
struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let initial = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: false,
        isMaintenanceEnabled: false
    )

    let schemaVersion: Int
    var isAuthenticated: Bool
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        isAuthenticated: Bool,
        hasCompletedOnboarding: Bool,
        isMaintenanceEnabled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.isAuthenticated = isAuthenticated
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isMaintenanceEnabled = isMaintenanceEnabled
    }
}
```

`AppStateStorageLoadResult.swift`:

```swift
import Foundation

nonisolated
enum AppStateStorageLoadResult: Equatable, Sendable {
    case missing
    case data(Data)
    case invalidValue
}
```

`IAppStateStorage.swift`:

```swift
import Foundation

nonisolated
protocol IAppStateStorage: Sendable {
    func load() -> AppStateStorageLoadResult
    func save(_ data: Data)
    func remove()
}
```

`UserDefaultsAppStateStorage.swift`:

```swift
import Foundation

nonisolated
struct UserDefaultsAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    static let key = "AppTemplate.AppState"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppStateStorageLoadResult {
        guard let value = userDefaults.object(forKey: Self.key) else {
            return .missing
        }
        guard let data = value as? Data else {
            return .invalidValue
        }
        return .data(data)
    }

    func save(_ data: Data) {
        userDefaults.set(data, forKey: Self.key)
    }

    func remove() {
        userDefaults.removeObject(forKey: Self.key)
    }
}
```

The contained `@unchecked Sendable` exception is limited to the immutable
reference to Foundation's thread-safe UserDefaults API; the adapter has no
mutable state of its own.

- [ ] **Step 5: Add storage to the explicit dependency graph**

Add:

```swift
let appStateStorage: any IAppStateStorage
```

Use these factory signatures:

```swift
static func live() -> AppDependencies

static func preview(
    appStateStorage: any IAppStateStorage,
    localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
    remoteService: any IRemoteService = RemoteService()
) -> AppDependencies

static func test(
    localDatabaseService: any ILocalDatabaseService,
    remoteService: any IRemoteService,
    appStateStorage: any IAppStateStorage
) -> AppDependencies
```

`live()` constructs `UserDefaultsAppStateStorage()`. Preview and test pass the
injected storage through unchanged. Do not put `AppStateStore`,
`AppFlowCoordinator`, or mutable navigation state in `AppDependencies`.

- [ ] **Step 6: Run focused and full macOS tests**

Run the Step 3 command, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/Models/State/AppState.swift \
  AppTemplate/App/State/Storage \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/App/Models/State/AppStateTests.swift \
  AppTemplateTests/App/State/Storage \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: add versioned app state storage"
```

---

### Task 2: Build state hydration, repair, mutation, and flow policy

**Files:**

- Create: `AppTemplate/App/State/Diagnostics/AppStateLogger.swift`
- Create: `AppTemplate/App/State/AppStateStore.swift`
- Create: `AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift`
- Create: `AppTemplateTests/TestSupport/AppStateStorageSpy.swift`
- Create: `AppTemplateTests/App/State/AppStateStoreTests.swift`
- Create:
  `AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift`

**Interfaces:**

- Consumes: `AppState`, `IAppStateStorage`, `AppFlow`, JSON coding, OSLog.
- Produces:
  `AppStateStore.state`,
  `AppStateStore.setState(_:) -> Bool`,
  and `AppFlowPolicy.resolve(_:) -> AppFlow`.
- `AppStateStore` never imports or references a navigation type.

- [ ] **Step 1: Add the lock-protected storage spy**

Create:

```swift
import Foundation
@testable import AppTemplate

nonisolated
final class AppStateStorageSpy:
    IAppStateStorage,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var value: AppStateStorageLoadResult
    private var loadCount = 0
    private var savedValues: [Data] = []
    private var removeCount = 0

    init(loadResult: AppStateStorageLoadResult = .missing) {
        value = loadResult
    }

    func load() -> AppStateStorageLoadResult {
        lock.withLock {
            loadCount += 1
            return value
        }
    }

    func save(_ data: Data) {
        lock.withLock {
            value = .data(data)
            savedValues.append(data)
        }
    }

    func remove() {
        lock.withLock {
            value = .missing
            removeCount += 1
        }
    }

    var loadCallCount: Int {
        lock.withLock { loadCount }
    }

    var savedData: [Data] {
        lock.withLock { savedValues }
    }

    var removeCallCount: Int {
        lock.withLock { removeCount }
    }
}
```

- [ ] **Step 2: Write failing store tests**

Create an `@MainActor` Swift Testing suite with these exact cases:

```swift
import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppStateStoreTests {
    @Test
    func missingValueLoadsInitialStateOnceWithoutWriting() {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage)

        #expect(store.state == .initial)
        #expect(storage.loadCallCount == 1)
        #expect(storage.savedData.isEmpty)
    }

    @Test
    func validCurrentRecordRestoresWithoutWriting() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(state))
        )
        let store = AppStateStore(storage: storage)

        #expect(store.state == state)
        #expect(storage.savedData.isEmpty)
    }

    @Test(arguments: [
        AppStateStorageLoadResult.invalidValue,
        .data(Data("not-json".utf8))
    ])
    func invalidRecordsRepairToOneCurrentInitialRecord(
        result: AppStateStorageLoadResult
    ) throws {
        let storage = AppStateStorageSpy(loadResult: result)

        let first = AppStateStore(storage: storage)
        let second = AppStateStore(storage: storage)

        #expect(first.state == .initial)
        #expect(second.state == .initial)
        #expect(storage.savedData.count == 1)
        #expect(
            try JSONDecoder().decode(
                AppState.self,
                from: #require(storage.savedData.first)
            ) == .initial
        )
    }

    @Test
    func unsupportedSchemaRepairsExactlyOnce() throws {
        let unsupported = AppState(
            schemaVersion: 2,
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(unsupported))
        )

        let first = AppStateStore(storage: storage)
        let second = AppStateStore(storage: storage)

        #expect(first.state == .initial)
        #expect(second.state == .initial)
        #expect(storage.savedData.count == 1)
    }

    @Test
    func changedStateWritesOnceAndIdenticalStateIsIdempotent() {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage)
        let changed = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )

        #expect(store.setState(changed))
        #expect(!store.setState(changed))
        #expect(store.state == changed)
        #expect(storage.savedData.count == 1)
    }
}
```

- [ ] **Step 3: Write the failing eight-row policy test**

Create:

```swift
import Testing
@testable import AppTemplate

struct AppFlowPolicyTests {
    @Test(arguments: [
        FlowCase(false, false, false, .onboarding),
        FlowCase(false, false, true, .onboarding),
        FlowCase(false, true, false, .onboarding),
        FlowCase(false, true, true, .onboarding),
        FlowCase(true, false, false, .authentication),
        FlowCase(true, false, true, .authentication),
        FlowCase(true, true, false, .main),
        FlowCase(true, true, true, .maintenance)
    ])
    func resolvesTheCompletePriorityTable(testCase: FlowCase) {
        let state = AppState(
            isAuthenticated: testCase.isAuthenticated,
            hasCompletedOnboarding: testCase.hasCompletedOnboarding,
            isMaintenanceEnabled: testCase.isMaintenanceEnabled
        )

        #expect(AppFlowPolicy.resolve(state) == testCase.expectedFlow)
    }
}

nonisolated
private struct FlowCase: Sendable {
    let hasCompletedOnboarding: Bool
    let isAuthenticated: Bool
    let isMaintenanceEnabled: Bool
    let expectedFlow: AppFlow

    init(
        _ hasCompletedOnboarding: Bool,
        _ isAuthenticated: Bool,
        _ isMaintenanceEnabled: Bool,
        _ expectedFlow: AppFlow
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isAuthenticated = isAuthenticated
        self.isMaintenanceEnabled = isMaintenanceEnabled
        self.expectedFlow = expectedFlow
    }
}
```

- [ ] **Step 4: Run the focused tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -only-testing:AppTemplateTests/AppFlowPolicyTests
```

Expected: exit 65 because `AppStateStore` and `AppFlowPolicy` do not exist.

- [ ] **Step 5: Implement payload-free logging and AppStateStore**

`AppStateLogger.swift`:

```swift
import Foundation
import OSLog

extension Logger {
    static let appState = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: "AppState"
    )
}
```

`AppStateStore.swift`:

```swift
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppStateStore {
    private(set) var state: AppState
    private let storage: any IAppStateStorage

    init(storage: any IAppStateStorage) {
        self.storage = storage

        switch Self.resolve(storage.load()) {
        case let .loaded(state):
            self.state = state
        case let .recovered(reason):
            state = .initial
            Self.logRecovery(reason)
            persist(state)
        }
    }

    @discardableResult
    func setState(_ state: AppState) -> Bool {
        guard state != self.state else {
            return false
        }
        self.state = state
        persist(state)
        return true
    }

    private func persist(_ state: AppState) {
        do {
            storage.save(try JSONEncoder().encode(state))
        } catch {
            Logger.appState.error("Failed to encode persisted app state")
        }
    }

    private static func resolve(
        _ result: AppStateStorageLoadResult
    ) -> AppStateLoadResolution {
        switch result {
        case .missing:
            return .loaded(.initial)
        case .invalidValue:
            return .recovered(.invalidValue)
        case let .data(data):
            return resolve(data)
        }
    }

    private static func resolve(_ data: Data) -> AppStateLoadResolution {
        let decoder = JSONDecoder()
        let envelope: AppStateSchemaEnvelope
        do {
            envelope = try decoder.decode(
                AppStateSchemaEnvelope.self,
                from: data
            )
        } catch {
            return .recovered(.corruptData)
        }

        guard envelope.schemaVersion == AppState.currentSchemaVersion else {
            return .recovered(
                .unsupportedSchema(envelope.schemaVersion)
            )
        }

        do {
            return .loaded(
                try decoder.decode(AppState.self, from: data)
            )
        } catch {
            return .recovered(.corruptData)
        }
    }

    private static func logRecovery(_ reason: AppStateRecoveryReason) {
        switch reason {
        case .invalidValue:
            Logger.appState.error(
                "Reset invalid persisted app state value"
            )
        case .corruptData:
            Logger.appState.error(
                "Reset corrupt persisted app state data"
            )
        case let .unsupportedSchema(version):
            Logger.appState.error(
                "Reset unsupported app state schema: \(version)"
            )
        }
    }
}

private enum AppStateLoadResolution {
    case loaded(AppState)
    case recovered(AppStateRecoveryReason)
}

private enum AppStateRecoveryReason {
    case invalidValue
    case corruptData
    case unsupportedSchema(Int)
}

nonisolated
private struct AppStateSchemaEnvelope: Decodable {
    let schemaVersion: Int
}
```

- [ ] **Step 6: Implement the pure policy**

```swift
nonisolated
enum AppFlowPolicy {
    static func resolve(_ state: AppState) -> AppFlow {
        if !state.hasCompletedOnboarding {
            return .onboarding
        }
        if !state.isAuthenticated {
            return .authentication
        }
        if state.isMaintenanceEnabled {
            return .maintenance
        }
        return .main
    }
}
```

- [ ] **Step 7: Run focused and full macOS tests**

Run the Step 4 command, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add AppTemplate/App/State \
  AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift \
  AppTemplateTests/TestSupport/AppStateStorageSpy.swift \
  AppTemplateTests/App/State/AppStateStoreTests.swift \
  AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift
git commit -m "feat: add app state store and flow policy"
```

---

### Task 3: Coordinate semantic state commands and initialize the persisted root

**Files:**

- Create:
  `AppTemplate/App/Navigation/Routing/IAppFlowCoordinator.swift`
- Create: `AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppFlowRouter.swift`
- Modify:
  `AppTemplateTests/App/Navigation/Routing/AppFlowRouterTests.swift`
- Create:
  `AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`

**Interfaces:**

- Consumes: `AppStateStore`, `AppFlowPolicy`, concrete `AppFlowRouter`.
- Produces:
  `IAppFlowCoordinator`,
  `AppFlowCoordinator.appFlowRouter`,
  semantic commands,
  and internal
  `AppFlowRouter.transitionForPolicy(to:pendingIntentAction:)`.
- Public `IAppFlowRouter.setFlow(_:)` remains unchanged.

- [ ] **Step 1: Add failing internal-transition tests**

Extend `AppFlowRouterTests`:

```swift
@Test(arguments: [
    PendingIntentAction.preserve,
    .replay,
    .discard
])
func policyTransitionResetsWithTheRequestedPendingAction(
    action: PendingIntentAction
) {
    let router = AppFlowRouter(flow: .onboarding)
    let previousID = router.transition.id

    router.transitionForPolicy(
        to: .authentication,
        pendingIntentAction: action
    )

    #expect(router.flow == .authentication)
    #expect(router.transition.id != previousID)
    #expect(router.transition.historyAction == .reset)
    #expect(router.transition.pendingIntentAction == action)
}
```

Retain every existing raw `setFlow(_:)` test unchanged.

- [ ] **Step 2: Write failing coordinator tests**

Create an `@MainActor` suite with `import Foundation`, `import Testing`, and
`@testable import AppTemplate`. Use this helper inside the test file:

```swift
@MainActor
private struct CoordinatorSUT {
    let storage: AppStateStorageSpy
    let store: AppStateStore
    let router: AppFlowRouter
    let coordinator: AppFlowCoordinator
}

@MainActor
private func makeSUT(
    state: AppState,
    visibleFlow: AppFlow? = nil
) throws -> CoordinatorSUT {
    let storage = AppStateStorageSpy(
        loadResult: .data(try JSONEncoder().encode(state))
    )
    let store = AppStateStore(storage: storage)
    let router = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(state)
    )
    return CoordinatorSUT(
        storage: storage,
        store: store,
        router: router,
        coordinator: AppFlowCoordinator(
            store: store,
            appFlowRouter: router
        )
    )
}
```

Add these behavioral tests:

```swift
@Test
func completingOnboardingPersistsAndPreservesPendingIntentAtAuthentication()
    throws {
    let sut = try makeSUT(state: .initial)

    sut.coordinator.completeOnboarding()

    #expect(sut.store.state.hasCompletedOnboarding)
    #expect(!sut.store.state.isAuthenticated)
    #expect(!sut.store.state.isMaintenanceEnabled)
    #expect(sut.storage.savedData.count == 1)
    #expect(sut.router.flow == .authentication)
    #expect(sut.router.transition.pendingIntentAction == .preserve)
}

@Test
func signInRoutesThroughMaintenanceAndPreservesPendingIntent() throws {
    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let sut = try makeSUT(state: state)

    sut.coordinator.signIn()

    #expect(sut.store.state.isAuthenticated)
    #expect(sut.router.flow == .maintenance)
    #expect(sut.router.transition.pendingIntentAction == .preserve)
}

@Test
func disablingMaintenanceEntersMainAndReplaysPendingIntent() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let sut = try makeSUT(state: state)

    sut.coordinator.setMaintenanceEnabled(false)

    #expect(!sut.store.state.isMaintenanceEnabled)
    #expect(sut.router.flow == .main)
    #expect(sut.router.transition.pendingIntentAction == .replay)
}

@Test
func changedLowerPriorityFlagWritesWithoutResettingVisibleFlow() throws {
    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state)
    let transition = sut.router.transition

    sut.coordinator.setMaintenanceEnabled(true)

    #expect(sut.store.state.isMaintenanceEnabled)
    #expect(sut.storage.savedData.count == 1)
    #expect(sut.router.transition == transition)
}

@Test
func unchangedFlagReconcilesAnInconsistentTemporaryFlowWithoutWriting()
    throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state, visibleFlow: .onboarding)

    sut.coordinator.completeOnboarding()

    #expect(sut.storage.savedData.isEmpty)
    #expect(sut.router.flow == .main)
    #expect(sut.router.transition.pendingIntentAction == .replay)
}

@Test
func repeatedConsistentCommandDoesNotWriteOrTransition() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state)
    let transition = sut.router.transition

    sut.coordinator.signIn()

    #expect(sut.storage.savedData.isEmpty)
    #expect(sut.router.transition == transition)
}

@Test
func rawSetFlowNeverWritesPersistentState() throws {
    let sut = try makeSUT(state: .initial)

    sut.coordinator.setFlow(.main)

    #expect(sut.store.state == .initial)
    #expect(sut.storage.savedData.isEmpty)
    #expect(sut.router.flow == .main)
}

@Test
func effectiveSignOutPreservesOtherFlagsAndForcesSameFlowDiscard() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let sut = try makeSUT(state: state, visibleFlow: .authentication)
    let previousID = sut.router.transition.id

    sut.coordinator.signOut()

    #expect(!sut.store.state.isAuthenticated)
    #expect(sut.store.state.hasCompletedOnboarding)
    #expect(sut.store.state.isMaintenanceEnabled)
    #expect(sut.router.flow == .authentication)
    #expect(sut.router.transition.id != previousID)
    #expect(sut.router.transition.pendingIntentAction == .discard)
}

@Test
func restartOnboardingChangesOnlyTheOnboardingFlag() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let sut = try makeSUT(state: state)

    sut.coordinator.restartOnboarding()

    #expect(sut.store.state.isAuthenticated)
    #expect(!sut.store.state.hasCompletedOnboarding)
    #expect(sut.store.state.isMaintenanceEnabled)
    #expect(sut.router.flow == .onboarding)
}

@Test
func enablingMaintenanceChangesOnlyTheMaintenanceFlag() throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let sut = try makeSUT(state: state)

    sut.coordinator.setMaintenanceEnabled(true)

    #expect(sut.store.state.isAuthenticated)
    #expect(sut.store.state.hasCompletedOnboarding)
    #expect(sut.store.state.isMaintenanceEnabled)
    #expect(sut.router.flow == .maintenance)
}
```

- [ ] **Step 3: Add failing sequential-gate tests at the AppRouter boundary**

Extend `AppRouterTests` using the existing
`AppRouter(appFlowRouter:)` constructor and add `import Foundation`:

```swift
@Test
func deferredIntentSurvivesOnboardingAndAuthenticationGates() throws {
    let storage = AppStateStorageSpy()
    let store = AppStateStore(storage: storage)
    let appFlowRouter = AppFlowRouter(flow: .onboarding)
    let coordinator = AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter
    )
    let router = AppRouter(appFlowRouter: appFlowRouter)
    #expect(router.handle(.browseItem(id: "swiftui")) == .deferred)

    coordinator.completeOnboarding()
    _ = router.apply(appFlowRouter.transition)
    #expect(router.pendingIntent == .browseItem(id: "swiftui"))

    coordinator.signIn()
    #expect(router.apply(appFlowRouter.transition) == .applied)
    #expect(router.pendingIntent == nil)
    #expect(router.selectedSection == .browse)
    #expect(router.browse.path.count == 1)
}

@Test
func deferredIntentSurvivesAuthenticationAndMaintenanceGates() throws {
    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let storage = AppStateStorageSpy(
        loadResult: .data(try JSONEncoder().encode(state))
    )
    let store = AppStateStore(storage: storage)
    let appFlowRouter = AppFlowRouter(flow: .authentication)
    let coordinator = AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter
    )
    let router = AppRouter(appFlowRouter: appFlowRouter)
    #expect(
        router.handle(
            .projectTask(projectID: "project-1", taskID: "task-1")
        ) == .deferred
    )

    coordinator.signIn()
    _ = router.apply(appFlowRouter.transition)

    #expect(appFlowRouter.flow == .maintenance)
    #expect(
        router.pendingIntent
            == .projectTask(projectID: "project-1", taskID: "task-1")
    )

    coordinator.setMaintenanceEnabled(false)
    #expect(router.apply(appFlowRouter.transition) == .applied)
    #expect(router.pendingIntent == nil)
    #expect(router.selectedSection == .projects)
    #expect(router.projects.path.count == 2)
}

@Test
func sharedCoordinatorReplaysEachScenesOwnPendingIntent() throws {
    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let storage = AppStateStorageSpy(
        loadResult: .data(try JSONEncoder().encode(state))
    )
    let store = AppStateStore(storage: storage)
    let appFlowRouter = AppFlowRouter(flow: .authentication)
    let coordinator = AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter
    )
    let first = AppRouter(appFlowRouter: appFlowRouter)
    let second = AppRouter(appFlowRouter: appFlowRouter)
    _ = first.handle(.browseItem(id: "swiftui"))
    _ = second.handle(
        .projectTask(projectID: "project-1", taskID: "task-1")
    )

    coordinator.signIn()
    _ = first.apply(appFlowRouter.transition)
    _ = second.apply(appFlowRouter.transition)

    #expect(first.selectedSection == .browse)
    #expect(first.browse.path.count == 1)
    #expect(first.projects.path.isEmpty)
    #expect(second.selectedSection == .projects)
    #expect(second.projects.path.count == 2)
    #expect(second.browse.path.isEmpty)
}
```

- [ ] **Step 4: Run focused tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppFlowRouterTests \
  -only-testing:AppTemplateTests/AppFlowCoordinatorTests \
  -only-testing:AppTemplateTests/AppRouterTests
```

Expected: exit 65 because the coordinator and policy-transition API do not
exist.

- [ ] **Step 5: Add the semantic protocol and internal router operation**

`IAppFlowCoordinator.swift`:

```swift
@MainActor
protocol IAppFlowCoordinator: IAppFlowRouter {
    func completeOnboarding()
    func restartOnboarding()
    func signIn()
    func signOut()
    func setMaintenanceEnabled(_ isEnabled: Bool)
}
```

Change `AppFlowRouter.transition(...)` from `private` to `private` plus this
internal wrapper:

```swift
func transitionForPolicy(
    to flow: AppFlow,
    pendingIntentAction: PendingIntentAction
) {
    transition(
        to: flow,
        historyAction: .reset,
        pendingIntentAction: pendingIntentAction
    )
}
```

Do not add the wrapper to `IAppFlowRouter`.

- [ ] **Step 6: Implement AppFlowCoordinator**

```swift
import Observation

@MainActor
@Observable
final class AppFlowCoordinator: IAppFlowCoordinator {
    let appFlowRouter: AppFlowRouter
    private let store: AppStateStore

    init(
        store: AppStateStore,
        appFlowRouter: AppFlowRouter
    ) {
        self.store = store
        self.appFlowRouter = appFlowRouter
    }

    func setFlow(_ flow: AppFlow) {
        appFlowRouter.setFlow(flow)
    }

    func completeOnboarding() {
        var state = store.state
        state.hasCompletedOnboarding = true
        synchronize(with: state)
    }

    func restartOnboarding() {
        var state = store.state
        state.hasCompletedOnboarding = false
        synchronize(with: state)
    }

    func signIn() {
        var state = store.state
        state.isAuthenticated = true
        synchronize(with: state)
    }

    func signOut() {
        var state = store.state
        state.isAuthenticated = false
        synchronize(
            with: state,
            nonMainPendingIntentAction: .discard,
            forceTransitionWhenStateChanges: true
        )
    }

    func setMaintenanceEnabled(_ isEnabled: Bool) {
        var state = store.state
        state.isMaintenanceEnabled = isEnabled
        synchronize(with: state)
    }

    private func synchronize(
        with state: AppState,
        nonMainPendingIntentAction: PendingIntentAction = .preserve,
        forceTransitionWhenStateChanges: Bool = false
    ) {
        let didChangeState = store.setState(state)
        let targetFlow = AppFlowPolicy.resolve(store.state)
        let mustForceTransition =
            forceTransitionWhenStateChanges && didChangeState

        guard appFlowRouter.flow != targetFlow || mustForceTransition else {
            return
        }

        appFlowRouter.transitionForPolicy(
            to: targetFlow,
            pendingIntentAction: targetFlow == .main
                ? .replay
                : nonMainPendingIntentAction
        )
    }
}
```

- [ ] **Step 7: Initialize the app from persisted state exactly once**

Replace AppTemplateApp's default Authentication router construction with:

```swift
@main
struct AppTemplateApp: App {
    private let dependencies: AppDependencies
    @State private var appFlowCoordinator: AppFlowCoordinator

    init() {
        let dependencies = AppDependencies.live()
        let store = AppStateStore(
            storage: dependencies.appStateStorage
        )
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(store.state)
        )
        self.dependencies = dependencies
        _appFlowCoordinator = State(
            initialValue: AppFlowCoordinator(
                store: store,
                appFlowRouter: appFlowRouter
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppSceneView(
                appFlowRouter: appFlowCoordinator.appFlowRouter
            )
        }
    }
}
```

Do not hydrate in `body`, `WindowGroup`, `AppSceneView.task`, or a scene
lifecycle callback. Keep the initial router transition as `.preserve`.

- [ ] **Step 8: Run focused and full macOS tests**

Run the Step 4 command, then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass and existing raw-router behavior remains unchanged.

- [ ] **Step 9: Commit**

```bash
git add AppTemplate/App/Navigation/Routing \
  AppTemplate/App/Entry/AppTemplateApp.swift \
  AppTemplateTests/App/Navigation/Routing
git commit -m "feat: coordinate persisted root flows"
```

---

### Task 4: Thread the coordinator through every local router and scene

**Files:**

- Modify: `AppTemplate/App/Navigation/Core/IRouter.swift`
- Modify: `AppTemplate/App/Navigation/Core/FlowRouter.swift`
- Modify: `AppTemplate/App/Navigation/Routing/AppRouter.swift`
- Modify:
  `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationLifecycle.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Entry/ContentView.swift`
- Modify: `AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift`
- Modify:
  `AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift`
- Create: `AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift`
- Modify: `AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift`
- Modify: `AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift`
- Modify:
  `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`
- Modify:
  `AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`
- Modify every existing test file that directly constructs `FlowRouter()`.
- Modify the four Projects test files with private `IRouter` spies.

**Interfaces:**

- Consumes: shared concrete `AppFlowRouter` and
  `any IAppFlowCoordinator`.
- Produces:
  `IRouter: IFlowRouter, IAppFlowCoordinator`,
  explicit `FlowRouter(appFlowCoordinator:)`,
  `AppRouter(appFlowRouter:appFlowCoordinator:selectedSection:)`,
  and `AppSceneView(appFlowCoordinator:)`.
- No production router creates a fallback coordinator or storage.

- [ ] **Step 1: Create the shared coordinator spy and explicit router factory**

Create:

```swift
import SwiftUI
@testable import AppTemplate

nonisolated
enum AppFlowCoordinatorCommand: Equatable, Sendable {
    case setFlow(AppFlow)
    case completeOnboarding
    case restartOnboarding
    case signIn
    case signOut
    case setMaintenanceEnabled(Bool)
}

@MainActor
final class AppFlowCoordinatorSpy: IAppFlowCoordinator {
    private(set) var commands: [AppFlowCoordinatorCommand] = []

    func setFlow(_ flow: AppFlow) {
        commands.append(.setFlow(flow))
    }

    func completeOnboarding() {
        commands.append(.completeOnboarding)
    }

    func restartOnboarding() {
        commands.append(.restartOnboarding)
    }

    func signIn() {
        commands.append(.signIn)
    }

    func signOut() {
        commands.append(.signOut)
    }

    func setMaintenanceEnabled(_ isEnabled: Bool) {
        commands.append(.setMaintenanceEnabled(isEnabled))
    }
}

@MainActor
func makeTestFlowRouter() -> FlowRouter {
    FlowRouter(appFlowCoordinator: AppFlowCoordinatorSpy())
}

@MainActor
func makeTestAppFlowCoordinator(
    state: AppState = .initial,
    visibleFlow: AppFlow? = nil
) -> AppFlowCoordinator {
    let store = AppStateStore(storage: AppStateStorageSpy())
    _ = store.setState(state)
    let appFlowRouter = AppFlowRouter(
        flow: visibleFlow ?? AppFlowPolicy.resolve(state)
    )
    return AppFlowCoordinator(
        store: store,
        appFlowRouter: appFlowRouter
    )
}

@MainActor
protocol LocalOnlyRouterSpy: IRouter {}

extension LocalOnlyRouterSpy {
    func setFlow(_ flow: AppFlow) {}
    func completeOnboarding() {}
    func restartOnboarding() {}
    func signIn() {}
    func signOut() {}
    func setMaintenanceEnabled(_ isEnabled: Bool) {}
}
```

The no-op defaults exist only in the test target for spies whose tests exercise
local pushes exclusively.

- [ ] **Step 2: Rewrite FlowRouter delegation tests first**

Replace the private raw-router spy in `FlowRouterTests` with
`AppFlowCoordinatorSpy`. Add:

```swift
@Test
func flowRouterDelegatesEveryGlobalCommand() {
    let coordinator = AppFlowCoordinatorSpy()
    let router = FlowRouter(appFlowCoordinator: coordinator)

    router.setFlow(.authentication)
    router.completeOnboarding()
    router.restartOnboarding()
    router.signIn()
    router.signOut()
    router.setMaintenanceEnabled(true)
    router.setMaintenanceEnabled(false)

    #expect(coordinator.commands == [
        .setFlow(.authentication),
        .completeOnboarding,
        .restartOnboarding,
        .signIn,
        .signOut,
        .setMaintenanceEnabled(true),
        .setMaintenanceEnabled(false)
    ])
}
```

Change local-only construction in this file from `FlowRouter()` to
`makeTestFlowRouter()`.

- [ ] **Step 3: Run FlowRouter tests and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/FlowRouterTests
```

Expected: exit 65 because `IRouter` and `FlowRouter` do not yet expose the
semantic coordinator contract.

- [ ] **Step 4: Implement the composite protocol and explicit delegation**

`IRouter.swift`:

```swift
@MainActor
protocol IRouter: IFlowRouter, IAppFlowCoordinator {}
```

Change `FlowRouter` to store:

```swift
private let appFlowCoordinator: any IAppFlowCoordinator
```

Use this initializer with no fallback:

```swift
init(
    path: NavigationPath = NavigationPath(),
    appFlowCoordinator: any IAppFlowCoordinator
) {
    self.path = path
    self.appFlowCoordinator = appFlowCoordinator
}
```

Keep push/pop/path behavior unchanged and add direct forwarding methods for
all six global operations:

```swift
func setFlow(_ flow: AppFlow) {
    appFlowCoordinator.setFlow(flow)
}

func completeOnboarding() {
    appFlowCoordinator.completeOnboarding()
}

func restartOnboarding() {
    appFlowCoordinator.restartOnboarding()
}

func signIn() {
    appFlowCoordinator.signIn()
}

func signOut() {
    appFlowCoordinator.signOut()
}

func setMaintenanceEnabled(_ isEnabled: Bool) {
    appFlowCoordinator.setMaintenanceEnabled(isEnabled)
}
```

- [ ] **Step 5: Thread both root capabilities through AppRouter and lifecycle**

Change `AppRouter` to:

```swift
init(
    appFlowRouter: AppFlowRouter,
    appFlowCoordinator: any IAppFlowCoordinator,
    selectedSection: AppSection = .home
) {
    self.appFlowRouter = appFlowRouter
    self.selectedSection = selectedSection
    authentication = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    onboarding = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    home = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    browse = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    projects = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    settings = FlowRouter(appFlowCoordinator: appFlowCoordinator)
    maintenance = FlowRouter(appFlowCoordinator: appFlowCoordinator)
}
```

Change the production lifecycle initializer to:

```swift
init(
    appFlowRouter: AppFlowRouter,
    appFlowCoordinator: any IAppFlowCoordinator
) {
    router = AppRouter(
        appFlowRouter: appFlowRouter,
        appFlowCoordinator: appFlowCoordinator
    )
    parser = DeepLinkParser()
}
```

Keep `init(router:)` and `init(router:parser:)` for direct unit testing.

- [ ] **Step 6: Make each scene receive the one concrete coordinator**

Change `AppSceneView` to retain:

```swift
let appFlowCoordinator: AppFlowCoordinator

private var appFlowRouter: AppFlowRouter {
    appFlowCoordinator.appFlowRouter
}
```

Its initializer becomes:

```swift
init(appFlowCoordinator: AppFlowCoordinator) {
    self.appFlowCoordinator = appFlowCoordinator
    _lifecycle = State(
        initialValue: AppSceneNavigationLifecycle(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            appFlowCoordinator: appFlowCoordinator
        )
    )
}
```

Keep snapshot restoration, transition observation, and URL handling unchanged.
Update `AppTemplateApp` to:

```swift
WindowGroup {
    AppSceneView(appFlowCoordinator: appFlowCoordinator)
}
```

- [ ] **Step 7: Update ContentView and the nested Create Project flow**

`ContentView` receives an explicit concrete coordinator:

```swift
import Foundation

@State private var appFlowCoordinator: AppFlowCoordinator
@State private var router: AppRouter

init(appFlowCoordinator: AppFlowCoordinator) {
    _appFlowCoordinator = State(initialValue: appFlowCoordinator)
    _router = State(
        initialValue: AppRouter(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            appFlowCoordinator: appFlowCoordinator
        )
    )
}
```

Its root uses `appFlowCoordinator.appFlowRouter`. For `#Preview`, build an
explicit coordinator from a dedicated suite/key:

```swift
@MainActor
private func makePreviewAppFlowCoordinator() -> AppFlowCoordinator {
    let defaults = UserDefaults(suiteName: "AppTemplate.Preview")
        ?? UserDefaults()
    let storage = UserDefaultsAppStateStorage(userDefaults: defaults)
    let store = AppStateStore(storage: storage)
    let router = AppFlowRouter(flow: AppFlowPolicy.resolve(store.state))
    return AppFlowCoordinator(store: store, appFlowRouter: router)
}

#Preview {
    ContentView(
        appFlowCoordinator: makePreviewAppFlowCoordinator()
    )
}
```

Rename both Create Project initializer labels and stored parameters from
`appFlowRouter` to `appFlowCoordinator`, type them as
`any IAppFlowCoordinator`, and construct:

```swift
FlowRouter(appFlowCoordinator: appFlowCoordinator)
```

Update `ProjectsView` to call:

```swift
CreateProjectFlowView(appFlowCoordinator: router)
```

- [ ] **Step 8: Migrate construction tests without adding production fallbacks**

Apply these exact mechanical rules:

- Replace local-only `FlowRouter()` with `makeTestFlowRouter()`.
- Replace `FlowRouter(appFlowRouter: spy)` with
  `FlowRouter(appFlowCoordinator: coordinatorSpy)`.
- Construct `AppRouter` with one concrete root router and one coordinator spy
  or real coordinator.
- Add the coordinator argument to production-style lifecycle initializers.
- Keep snapshot payload assertions unchanged.
- Change the four private Projects router spies to conform to
  `LocalOnlyRouterSpy` and remove their redundant `setFlow` implementation.
- Change the ProjectConfiguration Create Project harness property from
  `any IAppFlowRouter` to `any IAppFlowCoordinator`.
- Remove its private `CreateProjectAppFlowRouterSpy` and use the shared
  `AppFlowCoordinatorSpy`.

Update every direct construction in these files:

```text
AppTemplateTests/App/Navigation/Core/FlowRouterTests.swift
AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift
AppTemplateTests/App/Navigation/Snapshots/NavigationSnapshotTests.swift
AppTemplateTests/Features/Authentication/Screens/Authentication/AuthenticationViewModelTests.swift
AppTemplateTests/Features/Browse/Screens/Browse/BrowseListViewModelTests.swift
AppTemplateTests/Features/Browse/Screens/BrowseDetail/BrowseDetailViewModelTests.swift
AppTemplateTests/Features/Browse/Screens/RelatedItems/RelatedItemsViewModelTests.swift
AppTemplateTests/Features/Home/Screens/Home/HomeViewModelTests.swift
AppTemplateTests/Features/Home/Screens/HomeDetails/HomeDetailsViewModelTests.swift
AppTemplateTests/Features/Home/Screens/NavigationGuide/NavigationGuideViewModelTests.swift
AppTemplateTests/Features/Maintenance/Screens/Maintenance/MaintenanceViewModelTests.swift
AppTemplateTests/Features/Onboarding/Screens/Onboarding/OnboardingViewModelTests.swift
AppTemplateTests/Features/Projects/Screens/ProjectBasics/ProjectBasicsViewModelTests.swift
AppTemplateTests/Features/Projects/Screens/ProjectDetails/ProjectDetailsViewModelTests.swift
AppTemplateTests/Features/Projects/Screens/ProjectOptions/ProjectOptionsViewModelTests.swift
AppTemplateTests/Features/Projects/Screens/Projects/ProjectsViewModelTests.swift
AppTemplateTests/Features/Settings/Screens/About/AboutViewModelTests.swift
AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift
AppTemplateTests/Project/ProjectConfigurationTests.swift
```

In `AppRouterTests`, retain the concrete root identity assertion and change
the first test to verify that raw and semantic calls from all seven local
routers arrive at the one injected coordinator.

- [ ] **Step 9: Run focused integration and full macOS tests**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/FlowRouterTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests \
  -only-testing:AppTemplateTests/NavigationSnapshotTests \
  -only-testing:AppTemplateTests/ProjectConfigurationTests
```

Then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass; no `FlowRouter()` or
`FlowRouter(appFlowRouter:)` construction remains.

- [ ] **Step 10: Commit**

```bash
git add AppTemplate/App/Entry \
  AppTemplate/App/Navigation \
  AppTemplate/Features/Projects/Flow/CreateProjectFlowView.swift \
  AppTemplate/Features/Projects/Screens/Projects/View/ProjectsView.swift \
  AppTemplateTests
git commit -m "refactor: inject flow coordinator through scenes"
```

---

### Task 5: Replace durable root actions with semantic ViewModel commands

**Files:**

- Modify:
  `AppTemplate/Features/Authentication/Screens/Authentication/ViewModel/AuthenticationViewModel.swift`
- Modify:
  `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify:
  `AppTemplate/Features/Onboarding/Screens/Onboarding/ViewModel/OnboardingViewModel.swift`
- Modify:
  `AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift`
- Modify:
  `AppTemplate/Features/Home/Screens/Home/ViewModel/HomeViewModel.swift`
- Modify: `AppTemplate/Features/Home/Screens/Home/View/HomeView.swift`
- Modify:
  `AppTemplate/Features/Maintenance/Screens/Maintenance/ViewModel/MaintenanceViewModel.swift`
- Modify:
  `AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift`
- Modify:
  `AppTemplate/Features/Settings/Screens/Settings/ViewModel/SettingsViewModel.swift`
- Modify:
  `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- Modify the five matching ViewModel test files.
- Modify:
  `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift`

**Interfaces:**

- Consumes: `any IRouter` semantic commands.
- Produces durable intent mappings:
  Continue → `signIn`,
  Finish → `completeOnboarding`,
  Sign Out → `signOut`,
  restart onboarding,
  enable maintenance,
  disable maintenance.
- Authentication Cancel remains raw
  `setFlow(.authentication)`.

- [ ] **Step 1: Rewrite root-action ViewModel tests to assert commands**

Use `AppFlowCoordinatorSpy` and
`FlowRouter(appFlowCoordinator:)`. Required expectations:

```swift
@Test
func continueRequestsSemanticSignIn() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = AuthenticationViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.continueToApp()

    #expect(coordinator.commands == [.signIn])
}

@Test
func cancellationRemainsARawAuthenticationReset() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = AuthenticationViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.cancelAuthentication()

    #expect(coordinator.commands == [.setFlow(.authentication)])
}
```

Add equivalent one-command assertions:

```swift
@Test
func finishRequestsOnboardingCompletion() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = OnboardingViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.finish()

    #expect(coordinator.commands == [.completeOnboarding])
}

@Test
func signOutRequestsSemanticSignOut() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = SettingsViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.returnToAuthentication()

    #expect(coordinator.commands == [.signOut])
}

@Test
func homeRootActionsRequestPersistentPolicyChanges() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = HomeViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.openOnboarding()
    viewModel.openMaintenance()

    #expect(coordinator.commands == [
        .restartOnboarding,
        .setMaintenanceEnabled(true)
    ])
}

@Test
func returnToAppDisablesMaintenance() {
    let coordinator = AppFlowCoordinatorSpy()
    let viewModel = MaintenanceViewModel(
        router: FlowRouter(appFlowCoordinator: coordinator)
    )

    viewModel.returnToApp()

    #expect(
        coordinator.commands == [.setMaintenanceEnabled(false)]
    )
}
```

Keep every local path, sheet, and alert test unchanged.

- [ ] **Step 2: Run the five suites and verify RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AuthenticationViewModelTests \
  -only-testing:AppTemplateTests/OnboardingViewModelTests \
  -only-testing:AppTemplateTests/HomeViewModelTests \
  -only-testing:AppTemplateTests/MaintenanceViewModelTests \
  -only-testing:AppTemplateTests/SettingsViewModelTests
```

Expected: assertions fail because the ViewModels still call raw
`setFlow(_:)`.

- [ ] **Step 3: Replace only the durable root calls**

Use:

```swift
func continueToApp() {
    router.signIn()
}

func finish() {
    router.completeOnboarding()
}

func openOnboarding() {
    router.restartOnboarding()
}

func openMaintenance() {
    router.setMaintenanceEnabled(true)
}

func returnToApp() {
    router.setMaintenanceEnabled(false)
}

func returnToAuthentication() {
    router.signOut()
}
```

Keep:

```swift
func cancelAuthentication() {
    router.setFlow(.authentication)
}
```

- [ ] **Step 4: Make the static copy describe durable demo policy**

Use concise wording:

```text
Authentication:
"Continue saves a demo authenticated flag. No credentials are stored."

Onboarding:
"Completion is saved and the next required app flow opens automatically."

Home buttons:
"Restart onboarding"
"Enable maintenance"

Maintenance:
"Disable the saved maintenance flag to return to the required app flow."

Settings:
"The demo authenticated flag is persisted without credentials or tokens."
```

Do not add service, loading, async, credential, or domain behavior to a
screen.

- [ ] **Step 5: Add lifecycle-level gate and sign-out tests**

In `AppSceneNavigationLifecycleTests`, add:

```swift
@Test
func onboardingAndAuthenticationGatesPreserveThenReplayURL() throws {
    let coordinator = makeTestAppFlowCoordinator()
    let appFlowRouter = coordinator.appFlowRouter
    let lifecycle = AppSceneNavigationLifecycle(
        appFlowRouter: appFlowRouter,
        appFlowCoordinator: coordinator
    )
    _ = lifecycle.receive(
        try #require(
            URL(string: "apptemplate://browse/item/swiftui")
        )
    )
    _ = lifecycle.restore(from: nil)

    coordinator.completeOnboarding()
    _ = lifecycle.apply(appFlowRouter.transition)

    #expect(appFlowRouter.flow == .authentication)
    #expect(
        lifecycle.router.pendingIntent == .browseItem(id: "swiftui")
    )

    coordinator.signIn()
    #expect(lifecycle.apply(appFlowRouter.transition) == .applied)
    #expect(lifecycle.router.pendingIntent == nil)
    #expect(lifecycle.router.selectedSection == .browse)
    #expect(lifecycle.router.browse.path.count == 1)
}

@Test
func authenticationAndMaintenanceGatesPreserveThenReplayURL() throws {
    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: true
    )
    let coordinator = makeTestAppFlowCoordinator(state: state)
    let appFlowRouter = coordinator.appFlowRouter
    let lifecycle = AppSceneNavigationLifecycle(
        appFlowRouter: appFlowRouter,
        appFlowCoordinator: coordinator
    )
    _ = lifecycle.receive(
        try #require(
            URL(
                string: "apptemplate://projects/project/project-1/task/task-1"
            )
        )
    )
    _ = lifecycle.restore(from: nil)

    coordinator.signIn()
    _ = lifecycle.apply(appFlowRouter.transition)

    #expect(appFlowRouter.flow == .maintenance)
    #expect(
        lifecycle.router.pendingIntent
            == .projectTask(projectID: "project-1", taskID: "task-1")
    )

    coordinator.setMaintenanceEnabled(false)
    #expect(lifecycle.apply(appFlowRouter.transition) == .applied)
    #expect(lifecycle.router.pendingIntent == nil)
    #expect(lifecycle.router.selectedSection == .projects)
    #expect(lifecycle.router.projects.path.count == 2)
}

@Test
func effectiveSignOutDiscardsURLWhenAuthenticationIsAlreadyVisible()
    throws {
    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let coordinator = makeTestAppFlowCoordinator(
        state: state,
        visibleFlow: .authentication
    )
    let appFlowRouter = coordinator.appFlowRouter
    let lifecycle = AppSceneNavigationLifecycle(
        appFlowRouter: appFlowRouter,
        appFlowCoordinator: coordinator
    )
    _ = lifecycle.receive(
        try #require(
            URL(string: "apptemplate://browse/item/swiftui")
        )
    )
    _ = lifecycle.restore(from: nil)
    let previousID = appFlowRouter.transition.id

    coordinator.signOut()
    _ = lifecycle.apply(appFlowRouter.transition)

    #expect(appFlowRouter.flow == .authentication)
    #expect(appFlowRouter.transition.id != previousID)
    #expect(
        appFlowRouter.transition.pendingIntentAction == .discard
    )
    #expect(lifecycle.router.pendingIntent == nil)
    #expect(lifecycle.router.browse.path.isEmpty)
}
```

Each transition is applied exactly once, mirroring
`AppSceneView.onChange`.

- [ ] **Step 6: Run focused, navigation, and full macOS tests**

Run the Step 2 command, then:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AppTemplateTests/AppFlowCoordinatorTests \
  -only-testing:AppTemplateTests/AppRouterTests \
  -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests
```

Then:

```bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64'
```

Expected: all tests pass; sheets, alerts, snapshots, and deep links remain
green.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/Features/Authentication \
  AppTemplate/Features/Onboarding \
  AppTemplate/Features/Home \
  AppTemplate/Features/Maintenance \
  AppTemplate/Features/Settings \
  AppTemplateTests/Features/Authentication \
  AppTemplateTests/Features/Onboarding \
  AppTemplateTests/Features/Home \
  AppTemplateTests/Features/Maintenance \
  AppTemplateTests/Features/Settings \
  AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
git commit -m "feat: use semantic persisted flow actions"
```

---

### Task 6: Update architecture documentation and verify every platform

**Files:**

- Modify: `README.md`
- Modify:
  `docs/superpowers/specs/2026-07-30-navigation-only-app-shell-design.md`
- Modify:
  `docs/superpowers/specs/2026-07-30-persisted-app-state-design.md`
- Verify:
  `docs/superpowers/plans/2026-07-30-persisted-app-state.md`

**Interfaces:**

- Consumes: the completed implementation and passing macOS suite.
- Produces: current documentation, structural proof, and macOS/iPhone/iPad
  verification evidence.

- [ ] **Step 1: Update README ownership and behavior**

Make these exact conceptual changes:

- describe the app as a navigation-first shell with persisted demo app policy;
- document first-launch Onboarding and the four state-derived roots;
- describe `AppStateStore`, `AppFlowPolicy`, and `AppFlowCoordinator`;
- show semantic router examples instead of raw durable transitions:

```swift
router.signIn()
router.signOut()
router.completeOnboarding()
router.restartOnboarding()
router.setMaintenanceEnabled(true)
```

- state that raw `setFlow(_:)` is temporary and non-persistent;
- explain shared app state versus per-window paths and snapshots;
- explain deep-link preservation through intermediate semantic gates and
  discard on sign-out/raw non-Main transitions;
- describe AppDependencies as two empty service examples plus
  `IAppStateStorage`;
- state that UserDefaults stores Boolean demo flags only and real credentials
  belong in a future Keychain abstraction;
- link the persisted-state design and this plan.

Add a forward supersession note to the navigation-only design. Do not rewrite
or delete its historical body.

- [ ] **Step 2: Run structural guards**

Run:

```bash
! rg -n '\b(AppState|AppStateStore|IAppStateStorage|UserDefaults|AppDependencies|URLSession|Keychain)\b' \
  AppTemplate/Features --glob '*.swift'

! rg -n 'setFlow\(\.(main|onboarding|maintenance)\)' \
  AppTemplate/Features --glob '*ViewModel.swift'

test "$(rg -n \
  'router\.(signIn|signOut|completeOnboarding|restartOnboarding|setMaintenanceEnabled)' \
  AppTemplate/Features --glob '*ViewModel.swift' | wc -l | tr -d ' ')" -eq 6

! rg -n '\bAppFlow\b' \
  AppTemplate/App/Models/State/AppState.swift

! rg -n 'InMemoryAppStateStorage' AppTemplate

test "$(find AppTemplate/App/Services -type f -name '*.swift' | wc -l | tr -d ' ')" -eq 4

! rg -n 'FlowRouter\(\)|FlowRouter\(appFlowRouter:' \
  AppTemplate AppTemplateTests --glob '*.swift'

git diff --exit-code cf61b08...HEAD -- \
  AppTemplate.xcodeproj/project.pbxproj

git diff --check
```

Expected: every command exits zero and prints no forbidden production match.
The six semantic call sites are Authentication, Settings, Onboarding, two Home
actions, and Maintenance.

- [ ] **Step 3: Run the complete macOS suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/AppTemplate-persisted-app-state-macos
```

Expected: zero failures and zero unexpected skips.

- [ ] **Step 4: Run the complete iPhone suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,id=A2DCC39D-84E2-4E96-B1EF-C6D841FD3B8A' \
  -derivedDataPath /tmp/AppTemplate-persisted-app-state-iphone
```

Expected: zero failures and zero unexpected skips on iPhone 17 Pro,
iOS 26.5.

- [ ] **Step 5: Run the complete iPad suite**

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,id=1B12574D-F163-4952-8E39-4DD541C39F56' \
  -derivedDataPath /tmp/AppTemplate-persisted-app-state-ipad
```

Expected: zero failures and zero unexpected skips on iPad Pro 13-inch (M5),
iPadOS 26.5.

- [ ] **Step 6: Perform state and multi-window smoke checks**

Use XcodeBuildMCP simulator UI automation after calling
`session_show_defaults` and selecting the AppTemplate project, scheme, and
device.

On iPhone:

1. Remove only the AppTemplate app to clear its defaults, then launch.
2. Verify first root is Onboarding.
3. Finish Onboarding and verify Authentication.
4. Continue and verify Main.
5. Relaunch and verify Main is restored.
6. Enable Maintenance from Home, relaunch, and verify Maintenance.
7. Disable Maintenance and verify Main.
8. Sign Out from Settings, relaunch, and verify Authentication.

On iPad or macOS:

1. Reach Main and open two windows.
2. Put each window on a different tab and push a different local destination.
3. Enable Maintenance in one window and verify both roots change.
4. Disable Maintenance and verify both roots return to Main with reset local
   histories.
5. Verify subsequent navigation remains independent between windows.

The automated lifecycle tests are the source of truth for deferred URL
sequences; smoke checks must not replace them.

- [ ] **Step 7: Mark the design implemented and rerun diff hygiene**

After every platform and smoke check passes, change the persisted-state design
status to:

```text
Status: Implemented and verified
```

Then run:

```bash
git diff --check
git status --short
```

Expected: only the documentation files for this task are uncommitted; no
project file or user-owned main-worktree change appears in the implementation
worktree.

- [ ] **Step 8: Commit**

```bash
git add README.md \
  docs/superpowers/specs/2026-07-30-navigation-only-app-shell-design.md \
  docs/superpowers/specs/2026-07-30-persisted-app-state-design.md
git commit -m "docs: document persisted app state"
```

- [ ] **Step 9: Run final branch review**

Use `superpowers:requesting-code-review`, address all validated findings, then
use `superpowers:verification-before-completion` before offering merge or
handoff options.
