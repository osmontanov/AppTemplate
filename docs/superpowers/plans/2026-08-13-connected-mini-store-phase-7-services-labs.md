# Connected Mini Store Phase 7: Services Learning Labs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a guided Services section that explains why Store uses each service and safely demonstrates every public operation of AppInfo, UserDefaults, Keychain, Local Database, Remote, and Local Notifications.

**Architecture:** Every destination uses one shared Why/Preset/Try It/Expected/Actual/Reset/Advanced presentation. Storage labs use physically isolated services, database and remote screens use narrow phase handoffs, and notification UI receives scoped lab/read/app-wide facades rather than unrestricted `ILocalNotificationService`. All app-scoped actors remain composed once in `AppDependencies`.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, AudioToolbox, SwiftData, Security, UserNotifications, Swift Testing, XCUITest, Xcode 26

**Normative design base:** commit `e372913`, `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md`

## Global Constraints

- Execute after phases 1–6 and their roadmap compatibility gates pass.
- Use RED → expected failure → minimal GREEN → focused commit in every task.
- Main retains exactly Store and Services; `ServicesRoute` is the stable service identifier and no parallel identifier type is introduced.
- Every screen presents Why, Preset, Try It, Expected, Actual, Reset Demo Data, then Advanced; Advanced exposes the complete contract through the same ViewModel.
- Live UserDefaults namespace and Keychain service are both exactly `AppTemplate.ServicesLab`; keys are closed catalogs and never user-entered physical names.
- Local Database operates only on `ExampleRecord`. Remote and session actions use injected semantic interfaces and never build URLs or bearer headers.
- Notification ViewModels never receive raw `ILocalNotificationService`; app-wide removal/badge effects are labelled and confirmed.
- Phase-6 `LocalNotificationEventHistory` is the sole safe history: newest 100 records, atomic replay/live handoff, and no text-input text, arbitrary metadata, response bodies, query values, tokens, passwords, or raw errors.
- Automated tests/previews are offline and fail closed on an unscripted request.
- Do not edit or stage dirty `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, or `graphify-out/`.
- Filesystem-synchronized groups discover new files; do not edit project membership.

---

### Task 1: Guided Shell, App State, and AppInfo

**Files:**

- Create: `AppTemplate/Features/Services/Shared/Model/ServiceLabGuide.swift`; `AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift`; `AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift`
- Create: `AppTemplate/Features/Services/Infrastructure/AppState/IAppStateInspecting.swift`; `AppTemplate/Features/Services/Infrastructure/AppState/AppStateInspector.swift`; `AppTemplate/Features/Services/Infrastructure/AppState/ServicesAppStateStatus.swift`
- Create: `AppTemplate/Features/Services/Screens/ServicesCatalog/ViewModel/ServicesCatalogViewModel.swift`; `AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift`
- Create: `AppTemplate/Features/Services/Screens/AppState/ServicesAppStateViewModel.swift`; `AppTemplate/Features/Services/Screens/AppState/ServicesAppStateView.swift`
- Create: `AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoViewModel.swift`; `AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoView.swift`
- Modify: `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`; `AppTemplate/Features/Services/Navigation/ServicesRoute.swift`; `AppTemplate/App/AppDependencies/AppDependencies.swift`; `AppTemplate/App/Entry/AppTemplateApp.swift`; `AppTemplate/App/Entry/ContentView.swift`; `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`; `AppTemplate/App/Navigation/Containers/AppRootView.swift`; `AppTemplate/App/Navigation/Containers/AppShellView.swift`; `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`; `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`; `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- Test: `AppTemplateTests/Features/Services/ServicesGuideTests.swift`; `AppTemplateTests/Features/Services/ServicesApplicationLabsTests.swift`; `AppTemplateTests/App/Composition/AppDependenciesTests.swift`; `AppTemplateTests/Project/ProjectConfigurationTests.swift`

**Interfaces:**

- Consumes: `ServicesRoute: NavigationRoute`; `ISceneNavigationActions.presentation()/handleSampleIntent(_:)/resetNavigationInCurrentScene()`; `IAppFlowCoordinator.restartOnboarding() -> AppFlowActionResult`; `IAppFlowCoordinator.setMaintenanceEnabled(_:) -> AppFlowActionResult`; `ISessionActions.status: SessionStatusPresentation` (state/revision plus UI-safe expiry dates only); `ISessionActions.signOut() async -> SessionSignOutResult`; `IAppInfoService.displayName/version`.
- Produces:

```swift
nonisolated struct AppStateInspection: Equatable, Sendable {
    let schemaVersion: Int; let hasCompletedOnboarding: Bool; let isMaintenanceEnabled: Bool
    let persistenceStatus: AppStatePersistenceStatus; let root: AppFlow
}
@MainActor protocol IAppStateInspecting: AnyObject { var inspection: AppStateInspection { get } }
@MainActor @Observable final class AppStateInspector: IAppStateInspecting {
    init(store: AppStateStore, router: AppFlowRouter)
    var inspection: AppStateInspection { get }
}
nonisolated struct ServiceLabGuide: Equatable, Sendable {
    let why: String; let preset: String; let expected: String
}
nonisolated enum ServiceLabResult: Equatable, Sendable {
    case idle, running; case success(String); case failure(String)
    var isSuccess: Bool { get }
}
nonisolated struct ServicesCatalogItem: Identifiable, Equatable, Sendable { let route: ServicesRoute; let guide: ServiceLabGuide; var id: ServicesRoute { route } }
@MainActor enum ServicesCatalogViewModel { static let items: [ServicesCatalogItem] }
@MainActor @Observable final class ServicesAppStateStatus { private(set) var lastResult: ServiceLabResult; func record(_ result: ServiceLabResult) }
@MainActor struct ServicesDependencies {
    let appState: any IAppStateInspecting; let appFlowCoordinator: any IAppFlowCoordinator
    let appStateStatus: ServicesAppStateStatus; let sessionActions: any ISessionActions; let appInfo: any IAppInfoService
}
@MainActor final class ServicesAppInfoViewModel {
    init(appInfo: any IAppInfoService, platformName: String)
    var displayName: String { get }; var version: String { get }; var platformName: String { get }
}
@MainActor @Observable final class ServicesAppStateViewModel {
    init(appState: any IAppStateInspecting, appFlowCoordinator: any IAppFlowCoordinator, sessionActions: any ISessionActions,
         status: ServicesAppStateStatus, sceneNavigation: any ISceneNavigationActions)
    var application: AppStateInspection { get }; var session: SessionStatusPresentation { get }
    var scene: SceneNavigationPresentation { get }; var lastResult: ServiceLabResult { get }
    func resetNavigationInCurrentScene(); func restartOnboarding()
    func handleSampleIntent(_ intent: NavigationIntent); func setMaintenanceEnabled(_ enabled: Bool); func signOut() async
}
```

Freeze `@MainActor func AppDependencies.makeServicesDependencies(appState:any IAppStateInspecting, appFlowCoordinator:any IAppFlowCoordinator, sessionActions:any ISessionActions, appStateStatus:ServicesAppStateStatus) -> ServicesDependencies` as the single composition factory. `AppTemplateApp` creates one `AppStateInspector` from the exact phase-2 `AppStateStore` and phase-3 `AppFlowRouter`, owns one `ServicesAppStateStatus` so the last result survives temporary root replacement, calls that factory once, and passes the resulting slice down the full scene/root/shell/platform/content initializer chain. Direct `ContentView` and ProjectConfiguration constructors must pass the same slice; `PreviewFixtures` builds a fresh fail-closed slice with in-memory state/session/services and no live defaults. `AppSceneView` passes its own `AppSceneNavigationLifecycle` separately to `ServicesFlowView`; no scene object enters `AppDependencies`. Two-scene tests route through one shared services slice but distinct scene-action spies; use call routing, not existential identity against value services.

- [ ] **Step 1: Write the failing contracts**

```swift
@MainActor @Test func catalogHasNormativeOrderAndGuides() {
    #expect(ServicesCatalogViewModel.items.map(\.route) == [
        .appState, .appInfo, .userDefaults, .keychain,
        .localDatabase, .remoteAPI, .localNotifications
    ])
    #expect(ServicesCatalogViewModel.items.allSatisfy {
        !$0.guide.why.isEmpty && !$0.guide.preset.isEmpty
            && !$0.guide.expected.isEmpty
    })
}

@MainActor @Test func appInfoReadsInjectedValues() {
    let model = ServicesAppInfoViewModel(
        appInfo: AppInfoService(displayName: "Fixture", version: "7.2"),
        platformName: "Test Platform"
    )
    #expect((model.displayName, model.version, model.platformName)
        == ("Fixture", "7.2", "Test Platform"))
}

@MainActor @Test func appStateInspectionUsesRealPolicyAndRootSources() {
    let graph = AppStateInspectionFixture(schema: 2, persistence: .writable, root: .main)
    #expect(graph.inspector.inspection == .init(
        schemaVersion: 2, hasCompletedOnboarding: true, isMaintenanceEnabled: false,
        persistenceStatus: .writable, root: .main
    ))
}
```

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/ServicesGuideTests \
  -only-testing:AppTemplateTests/ServicesApplicationLabsTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL with `cannot find 'ServicesCatalogViewModel' in scope`.

- [ ] **Step 3: Implement the minimal shared guide and application labs**

```swift
@MainActor @Observable
final class ServicesAppInfoViewModel {
    let displayName: String
    let version: String
    let platformName: String
    init(appInfo: any IAppInfoService, platformName: String) {
        displayName = appInfo.displayName
        version = appInfo.version
        self.platformName = platformName
    }
}
```

`ServiceLabGuideView` renders the seven required sections in order. `AppStateInspector` is a read-only projection over the existing observable store/router; it introduces no second state. App State shows live schema/persistence/root/session, app-scoped last semantic result, current scene section/typed paths/restoration checkpoint, sample deep links through exact `handleSampleIntent(_:)`, and app-wide Replay Onboarding/Maintenance/Sign Out separated from current-window Reset. The ViewModel records each typed action result into `ServicesAppStateStatus` as a bounded safe `ServiceLabResult`; no raw persistence/session error is rendered. AppInfo Try It reads the exact shared display name/version service and View-derived platform. Wire `ServicesDependencies` through every initializer named in Files and prove Store and Services route AppInfo calls to the same app-owned service spy while each window supplies only its own scene action object.

- [ ] **Step 4: Run GREEN**

Run Step 2 unchanged. Expected: PASS; spies prove Reset calls only the scene action and app-wide controls call only their semantic owners.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Services AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Entry/ContentView.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplate/App/Navigation/Containers \
  AppTemplateTests/Features/Services/ServicesGuideTests.swift \
  AppTemplateTests/Features/Services/ServicesApplicationLabsTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Project/ProjectConfigurationTests.swift
git commit -m "feat: add guided services application labs"
```

### Task 2: Isolated UserDefaults and Keychain Labs

**Files:**

- Create: `AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLab.swift`; `AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabViewModel.swift`; `AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabView.swift`
- Create: `AppTemplate/Features/Services/Screens/Keychain/KeychainLab.swift`; `AppTemplate/Features/Services/Screens/Keychain/KeychainLabViewModel.swift`; `AppTemplate/Features/Services/Screens/Keychain/KeychainLabView.swift`
- Create: `AppTemplate/App/Services/UserDefaults/InMemoryUserDefaultsService.swift`; `AppTemplateTests/App/Services/UserDefaults/InMemoryUserDefaultsServiceTests.swift`
- Modify: `AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift`; `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`; `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Test: `AppTemplateTests/Features/Services/ServicesStorageLabsTests.swift`; `AppTemplateTests/App/Composition/ServicesLabIsolationTests.swift`

**Interfaces:**

- Consumes `IUserDefaultsService.value/set/remove`, all eight `UserDefaultsKey` codecs, and Keychain Data/String/Codable conveniences.
- Produces:

```swift
nonisolated enum UserDefaultsLabKind: String, CaseIterable, Sendable {
    case bool, int, float, double, string, data, date, codable
}
nonisolated enum KeychainLabKind: String, CaseIterable, Sendable {
    case data, string, codable
}
nonisolated enum UserDefaultsLabKeys {
    static let bool: UserDefaultsKey<Bool>; static let int: UserDefaultsKey<Int>
    static let float: UserDefaultsKey<Float>; static let double: UserDefaultsKey<Double>
    static let string: UserDefaultsKey<String>; static let data: UserDefaultsKey<Data>
    static let date: UserDefaultsKey<Date>; static let codable: UserDefaultsKey<UserDefaultsLabCodable>
}
nonisolated enum KeychainLabKeys {
    static let data: KeychainKey
    static let string: KeychainKey
    static let codable: KeychainCodableKey<KeychainLabCodable>
    static var allPhysicalAccounts: Set<String> { get }
}
nonisolated final class InMemoryUserDefaultsService: IUserDefaultsService, Sendable {
    init(namespace: String)
    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value?
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>)
}
@MainActor @Observable final class UserDefaultsLabViewModel {
    init(service: any IUserDefaultsService)
    private(set) var actualResult: ServiceLabResult
    func save(_ kind: UserDefaultsLabKind) throws; func read(_ kind: UserDefaultsLabKind) throws
    func remove(_ kind: UserDefaultsLabKind); func resetDemoData()
}
@MainActor @Observable final class KeychainLabViewModel {
    init(service: any IKeychainService, session: any ISessionActions)
    private(set) var actualResult: ServiceLabResult; private(set) var isValueRevealed: Bool
    var sessionStatus: SessionStatusPresentation { get }; func revealValue(); func hideValue()
    func save(_ kind: KeychainLabKind) async; func read(_ kind: KeychainLabKind) async
    func remove(_ kind: KeychainLabKind) async; func resetDemoData() async
    func validateSession() async; func refreshSession() async
}
```

- `AppDependencies` owns `let servicesLabUserDefaults: any IUserDefaultsService` and `let servicesLabKeychain: any IKeychainService`. Only the live graph constructs `UserDefaultsService(namespace:"AppTemplate.ServicesLab", userDefaults:.standard)` and `KeychainService(service:"AppTemplate.ServicesLab")`. Every preview, unit-test, and UI-test graph explicitly injects a fresh `InMemoryUserDefaultsService(namespace:"AppTemplate.ServicesLab")` and fresh `InMemoryKeychainService`; no default initializer may reach `.standard` or Security in those graphs. `ServicesDependencies` exposes those same instances as `let userDefaultsLab: any IUserDefaultsService` and `let keychainLab: any IKeychainService`; extend only the existing factory, so `AppTemplateApp` and the scene propagation chain do not acquire low-level storage parameters and repeated factory calls never create stores. `AppDependenciesTests` proves fresh graph identity and cross-graph nonvisibility for both lab stores.

- [ ] **Step 1: Write codec-matrix and isolation RED**

```swift
@MainActor @Test func everyDefaultsCodecSupportsSaveReadRemove() throws {
    let model = UserDefaultsLabViewModel(service: isolatedDefaultsService())
    for kind in UserDefaultsLabKind.allCases {
        try model.save(kind); try model.read(kind)
        #expect(model.actualResult.isSuccess)
        model.remove(kind)
    }
}

@MainActor @Test func isolatedCompositionRoutesToClosedPhysicalStores() async throws {
    let backing = ServicesLabPhysicalStoreSpy()
    let graph = AppDependencies.fixture(servicesLabBacking: backing)
    let services = graph.makeServicesDependenciesFixture()
    try services.userDefaultsLab.set("x", for: UserDefaultsLabKeys.string)
    try await services.keychainLab.set("y", for: KeychainLabKeys.string)
    #expect(backing.defaultsKeys == ["AppTemplate.ServicesLab.String"])
    #expect(backing.keychainServices == ["AppTemplate.ServicesLab"])
}
```

Also iterate all three Keychain kinds, assert values remain masked until explicit reveal, and Reset removes only the exact `KeychainLabKeys.allPhysicalAccounts`. A Foundation `UserDefaults` test double passed through the existing `UserDefaultsService(namespace:userDefaults:)` initializer records physical calls and proves the `AppTemplate.ServicesLab.` prefix; a scripted `KeychainSecItemExecuting` proves service `AppTemplate.ServicesLab`. A composition spy preloads sentinel AppState, Store preference, `Store.AuthSession`, and unrelated service records; every lab operation including Reset must leave all sentinels byte-for-byte unchanged. Exercise every codec against the new in-memory service and prove two instances never share values.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/ServicesStorageLabsTests \
  -only-testing:AppTemplateTests/ServicesLabIsolationTests \
  -only-testing:AppTemplateTests/InMemoryUserDefaultsServiceTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL because both lab ViewModels and isolated composition are missing.

- [ ] **Step 3: Add closed catalogs and Basic/Advanced operations**

```swift
nonisolated enum UserDefaultsLabKeys {
    static let bool = UserDefaultsKey<Bool>.bool("Bool")
    static let int = UserDefaultsKey<Int>.int("Int")
    static let float = UserDefaultsKey<Float>.float("Float")
    static let double = UserDefaultsKey<Double>.double("Double")
    static let string = UserDefaultsKey<String>.string("String")
    static let data = UserDefaultsKey<Data>.data("Data")
    static let date = UserDefaultsKey<Date>.date("Date")
    static let codable = UserDefaultsKey<UserDefaultsLabCodable>.codable("Codable")
}
```

Compose the two app-owned services once, then inject them into the labs. Basic uses Bool/String; Advanced exposes every kind and Save/Read/Remove. Bound decoded Data to 4,096 bytes and hex output to 8,192 characters. Real session UI reads only `ISessionActions.status` for redacted presence/profile/availability and the two optional UI-safe expiry timestamps, formats those dates without claiming JWT verification or guaranteed lifetime, and invokes semantic Validate/Refresh. It never reads the live session Keychain envelope or token strings.

Use closed logical names `Bool`, `Int`, `Float`, `Double`, `String`, `Data`, `Date`, and `Codable`. `InMemoryUserDefaultsService` stores its namespaced encoded dictionary inside `Synchronization.Mutex`; every complete read/write/remove critical section is locked, so the class earns ordinary `Sendable` conformance rather than `@unchecked Sendable`. A concurrent task-group test races typed reads/writes/removes and proves no data race, torn encoded value, or cross-namespace visibility. Keychain uses accounts `Data`, `String`, and `Codable.schema-1`; Reset iterates only those declared values (UserDefaults through typed `remove`, Keychain through typed/raw `remove`), hides any revealed value, and never enumerates or clears a namespace/service wholesale. `KeychainLabKeys.codable` is created with `.codable("Codable", schemaVersion: 1)` so the schema suffix is produced by the service API rather than hand-built. Both observable ViewModels publish `actualResult`; Keychain values remain masked until `revealValue()` and are hidden after route/reset.

- [ ] **Step 4: Run GREEN**

Run Step 2 plus `-only-testing:AppTemplateTests/UserDefaultsServiceTests -only-testing:AppTemplateTests/InMemoryUserDefaultsServiceTests -only-testing:AppTemplateTests/KeychainConvenienceTests`. Expected: PASS with no AppState or `Store.AuthSession` access and no real persistent store in preview/test/UI graphs.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Services/Screens/UserDefaults \
  AppTemplate/Features/Services/Screens/Keychain \
  AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift \
  AppTemplate/Features/Services/Flow/ServicesFlowView.swift \
  AppTemplate/App/Services/UserDefaults/InMemoryUserDefaultsService.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/Features/Services/ServicesStorageLabsTests.swift \
  AppTemplateTests/App/Services/UserDefaults/InMemoryUserDefaultsServiceTests.swift \
  AppTemplateTests/App/Composition/ServicesLabIsolationTests.swift
git commit -m "feat: add isolated storage learning labs"
```

### Task 3: Local Database and Remote Labs

**Files:**

- Create: `AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabState.swift`; `AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabViewModel.swift`; `AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabView.swift`
- Create: `AppTemplate/Features/Services/Infrastructure/Remote/IRemoteAPILabService.swift`; `AppTemplate/Features/Services/Infrastructure/Remote/RemoteAPILabService.swift`
- Create: `AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabState.swift`; `AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabViewModel.swift`; `AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabView.swift`
- Modify: `AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift`; `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`; `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Test: `AppTemplateTests/Features/Services/ServicesDatabaseRemoteLabsTests.swift`; `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Consumes:

```swift
nonisolated protocol ILocalDatabaseExampleRepository: Sendable {
    func fetch(id: String) async throws -> ExampleRecord?
    func page(searchText: String?, afterID: String?, pageSize: Int) async throws
        -> LocalDatabasePage<ExampleRecord, String>
    func create(id: String, payload: String) async throws; func update(id: String, payload: String) async throws
    func upsert(_ value: ExampleRecord) async throws
    func upsertBatch(_ values: [ExampleRecord]) async throws
    func delete(id: String) async throws -> Bool; func deleteAll() async throws -> Int
}
```

- The concrete `RemoteAPILabService` adapter alone consumes phase-1 `IRemoteService.products(_:)`, `categories()`, `product(id:)`, and `diagnostic(_:)`. The Services slice and ViewModel see only this token-free facade, the phase-1 `NetworkDiagnosticRecorder`, and phase-3 `ISessionActions` semantic actions:

```swift
nonisolated protocol IRemoteAPILabService: Sendable {
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO
    func categories() async throws -> [ProductCategoryDTO]
    func product(id: Int) async throws -> ProductDTO
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO
}
nonisolated struct RemoteAPILabService: IRemoteAPILabService {
    init(remote: any IRemoteService)
}
func login(username: String, password: String) async -> SessionLoginResult
func validateSession() async -> SessionValidationResult; func refreshSession() async -> SessionValidationResult
func retryPersistence(_ token: SessionPersistenceRetryToken) async
    -> SessionPersistenceRetryResult
func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async; func signOut() async -> SessionSignOutResult

nonisolated enum SessionValidationResult: Equatable, Sendable {
    case committed(SessionPresentation), unchanged, cancelled
    case persistenceFailed(SessionPersistenceRetryToken, retained: SessionPresentation)
    case failed(SessionPresentationError)
}
```

`IRemoteAPILabService` has no login, bearer-token `me`, refresh-token, token DTO, `fetchExample`, arbitrary target, request-builder, or raw transport member. Authentication/profile/validation/refresh/sign-out remain available only through the injected shared session actions.

- `AppDependencies` gains one app-owned `let localDatabaseExamples: any ILocalDatabaseExampleRepository = LocalDatabaseExampleRepository(database: localDatabase)` and one app-owned `let remoteAPILab: any IRemoteAPILabService = RemoteAPILabService(remote: remote)`. Every live/preview/test/UI-test graph creates them once over that graph's exact low-level database/scripted remote; the Services factory reuses them together with the phase-1 `diagnostics` instance and phase-3 `sessionActions`.
- Produces; `ServicesDependencies` gains `localDatabase: any ILocalDatabaseExampleRepository`, `remoteAPI: any IRemoteAPILabService`, `diagnostics: NetworkDiagnosticRecorder`, and reuses `sessionActions: any ISessionActions`. It never exposes `IRemoteService`:

```swift
nonisolated struct LocalDatabaseLabState: Equatable, Sendable { var records: [ExampleRecord]; var nextCursor: String?; var hasMore: Bool; var isLoading: Bool; var searchText: String; var pageSize: Int }
nonisolated enum LocalDatabaseLabRetryOperation: Equatable, Sendable { case fetch(String); case page(search: String?, afterID: String?, pageSize: Int); case create(ExampleRecord); case update(ExampleRecord); case upsert(ExampleRecord); case upsertBatch([ExampleRecord]); case delete(String); case deleteAll; case reset }
nonisolated struct RemoteAPILabState: Equatable, Sendable { var productIDs: [Int]; var categorySlugs: [String]; var nextSkip: Int; var isLoading: Bool; var diagnosticEvents: [NetworkDiagnosticEvent] }
nonisolated enum RemoteLabRetryOperation: Equatable, Sendable { case search(String); case categories; case categoryProducts(String); case detail(Int); case nextPage; case diagnostic(HTTPDiagnosticRequest); case validate; case refresh }
@MainActor @Observable final class LocalDatabaseLabViewModel {
    init(repository: any ILocalDatabaseExampleRepository, pageSize: Int = 20)
    private(set) var state: LocalDatabaseLabState; private(set) var actualResult: ServiceLabResult
    func fetchByID() async; func createDraft() async; func updateDraft() async; func upsertDraft() async; func upsertBatch() async
    func setPageSize(_ value: Int) async; func refresh() async; func loadMore() async; func deleteByID() async
    func deleteAllConfirmed() async; func resetDemoData() async; func retryLastOperation() async
}
@MainActor @Observable final class RemoteAPILabViewModel {
    init(remote: any IRemoteAPILabService, session: any ISessionActions, diagnostics: NetworkDiagnosticRecorder)
    var username: String; var password: String
    private(set) var state: RemoteAPILabState; private(set) var actualResult: ServiceLabResult
    func tryProductSearch() async; func tryCategories() async; func tryCategoryProducts() async
    func tryProductDetail() async; func loadMoreProducts() async
    func runDiagnostic(_ request: HTTPDiagnosticRequest) async
    func login() async; func validateSession() async
    func refreshSession() async; func retrySessionPersistence(_ token: SessionPersistenceRetryToken) async
    func discardSessionPersistenceRetry(_ token: SessionPersistenceRetryToken) async
    func signOut() async; func refreshDiagnostics() async; func clearDiagnostics() async
    func cancelCurrentOperation(); func retryLastOperation() async
}
```

- [ ] **Step 1: Write operation-coverage RED**

```swift
@MainActor @Test func mutationResetsCursorBeforeReload() async {
    let repository = ExampleRepositorySpy.twoPages
    let model = LocalDatabaseLabViewModel(repository: repository, pageSize: 1)
    await model.refresh(); await model.loadMore(); await model.createDraft()
    #expect(repository.requestedCursors == [nil, "a", nil])
}

@MainActor @Test func cancelledRemoteTryIsSilent() async {
    let started = AsyncOneShotSignal<Void>(); let model = RemoteAPILabViewModel.fixture(script: .suspendedSearch(started))
    let task = Task { await model.tryProductSearch() }
    await started.wait()
    model.cancelCurrentOperation(); await task.value
    #expect(model.actualResult == .idle)
}
```

Use one table test to cover database fetch/create/update/single-upsert insert/single-upsert replace/batch upsert/search/paging/delete/delete-all and every remote-lab facade boundary: all-products paging, search, category-object list, products-by-category, detail, delay in the documented `0...5000` millisecond range, cancel/retry, and 400/401/404/500. Every retryable database failure stores only a bounded `LocalDatabaseLabRetryOperation` with validated ID/payload/page inputs; `retryLastOperation()` repeats exactly that semantic repository call once, while cancellation clears no successful state and invalid input is never retained. Tests cover each descriptor, replacement by the latest failure, successful clear, and no closure/error/password/raw database object capture. A separate semantic-session table covers Login/Validate (`/auth/me` internally)/Refresh/Sign Out without the lab ever seeing a token. Add an API-surface test proving `ServicesDependencies`, `RemoteAPILabViewModel`, and `IRemoteAPILabService` contain no `IRemoteService`, login/refresh DTO, access/refresh token, bearer `String`, `me(accessToken:)`, or `fetchExample` member. Page-size tests accept every integer `1...50`, reject 0/51 without a repository call or state mutation, and prove a valid change clears records/cursor then reloads from nil with the selected lookahead-backed size.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/ServicesDatabaseRemoteLabsTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL with missing database and remote lab ViewModels.

- [ ] **Step 3: Implement the operation matrices**

```swift
func loadMore() async {
    guard state.hasMore, !state.isLoading else { return }
    await loadPage(afterID: state.nextCursor, replacing: false)
}

func createDraft() async {
    do {
        try await repository.create(
            id: draftRecord.id,
            payload: draftRecord.payload
        )
        state.nextCursor = nil
        await loadPage(afterID: nil, replacing: true)
    } catch is CancellationError { return }
      catch { actualResult = .failure(Self.safeMessage(for: error)) }
}
```

Basic database preset seeds three valid IDs and pages them; Advanced exposes all operations, including distinct single Upsert and Batch Upsert controls, a numeric page-size control for the complete `1...50` contract (default 20), retry of the last typed failed operation, and confirmed Delete All with count. Create rejects existing IDs, Update rejects missing IDs, and Upsert demonstrably inserts or replaces before resetting the cursor and reloading. `setPageSize` validates before mutation; on success it cancels the current load, stores the size, resets cursor/results, and reloads from nil. Basic Remote uses scripted search; Advanced exposes the remaining fixed operations, with category discovery and products-by-category as separate actions so `categories()` is not hidden behind a hard-coded slug. `AppDependencies` wraps its exact phase-1 scripted/live remote once in `RemoteAPILabService`, then supplies only that token-free facade, its exact local-database facade, and `diagnostics` through the existing Services factory; composition tests route a call through each spy and prove no second remote, database container, or recorder. `refreshDiagnostics()` copies only the bounded allowlisted recorder DTO; `clearDiagnostics()` clears the actor and visible array. Every login attempt goes only through `ISessionActions`, captures the UI fields, clears `password` with `defer` on success/failure/cancellation, and is never stored as a retry operation. Retry retains only typed bounded operation values with no credentials, closures, or raw errors. Treat both `CancellationError` and exact `RemoteServiceError.cancelled` as silent; all other session/network failures use bounded safe presentation mapping.

- [ ] **Step 4: Run GREEN**

Run Step 2 plus `-only-testing:AppTemplateTests/LocalDatabaseContractTests -only-testing:AppTemplateTests/RemoteServiceTests`. Expected: PASS with zero unplanned requests and only `ExampleRecord` mutations.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Services/Screens/LocalDatabase \
  AppTemplate/Features/Services/Infrastructure/Remote \
  AppTemplate/Features/Services/Screens/RemoteAPI \
  AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift \
  AppTemplate/Features/Services/Flow/ServicesFlowView.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/Features/Services/ServicesDatabaseRemoteLabsTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: add database and remote learning labs"
```

### Task 4: Scoped Notification Lab, Safe History, and Phase Gate

**Files:**

- Create: `AppTemplate/Features/Services/Infrastructure/LocalNotifications/ILocalNotificationLabService.swift`; `AppTemplate/Features/Services/Infrastructure/LocalNotifications/ILocalNotificationAppWideCapabilities.swift`; `AppTemplate/Features/Services/Infrastructure/LocalNotifications/LocalNotificationLabService.swift`; `AppTemplate/Features/Services/Infrastructure/LocalNotifications/LocalNotificationLabAssetProvider.swift`
- Create: `AppTemplate/Resources/NotificationDemo/notification-demo-image.png`; `AppTemplate/Resources/NotificationDemo/notification-demo-video.mov`; `AppTemplate/Resources/notification-demo.aiff`
- Create: `AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabViewModel.swift`; `AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabView.swift`
- Create: `AppTemplateUITests/Robots/ServicesRobot.swift`
- Modify: `AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift`; `AppTemplate/App/AppDependencies/AppDependencies.swift`; `AppTemplate/App/Entry/AppLaunchConfiguration.swift`; `AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift`
- Modify: `AppTemplate/Features/Services/Dependencies/ServicesDependencies.swift`; `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`; `AppTemplateUITests/AppTemplateUITests.swift`
- Test: `AppTemplateTests/Features/Services/ServicesNotificationLabTests.swift`; `AppTemplateTests/Features/Services/LocalNotificationLabAssetProviderTests.swift`

**Interfaces:**

- Consumes phase-6 `IAppNotificationCategoryCatalog` with concrete `AppNotificationCategoryCatalog`, and only `any ILocalNotificationEventReading` backed by the sole phase-6 `LocalNotificationEventHistory`; Services cannot call `append`. Its `records()`, `updates()`, and `clear()` expose `[LocalNotificationEventRecord]` carrying safe `LocalNotificationEventSummary`; raw `ILocalNotificationService` is private to the concrete facade.
- Produces:

```swift
nonisolated protocol ILocalNotificationLabService: Sendable {
    func settings() async -> LocalNotificationSettings
    func requestAuthorization(_ options: LocalNotificationAuthorizationOptions) async throws -> Bool
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) async throws; func resetLabCategories() async throws; func scheduleLab(_ request: LocalNotificationRequest) async throws
    func pendingLab() async -> [LocalNotificationPendingSnapshot]; func deliveredLab() async -> [LocalNotificationDeliveredSnapshot]
    func removeLabPending(_ ids: Set<LocalNotificationID>) async; func removeLabDelivered(_ ids: Set<LocalNotificationID>) async
    func resetLabData() async throws
}
nonisolated protocol ILocalNotificationAppWideCapabilities: Sendable {
    func pendingAppOwned() async -> [LocalNotificationPendingSnapshot]; func deliveredAppOwned() async -> [LocalNotificationDeliveredSnapshot]
    func removeAllPending() async; func removeAllDelivered() async
    func setBadgeCount(_ count: Int) async throws; func clearBadge() async throws
}
nonisolated enum LocalNotificationLabAsset: CaseIterable, Sendable { case image, audio, video }
nonisolated enum LocalNotificationLabAssetError: Error, Equatable, Sendable {
    case missing(String), invalidFileURL(String), unreadable(String), invalidSoundDuration(String)
}
nonisolated enum LocalNotificationLabResource: Equatable, Sendable { case attachment(LocalNotificationLabAsset), sound }
nonisolated enum LocalNotificationLabURLValidation: Equatable, Sendable { case valid, invalidFileURL, unreadable, soundTooLong }
nonisolated struct LocalNotificationLabAssetProvider: Sendable {
    init(bundle: Bundle)
    init(resolve: @escaping @Sendable (LocalNotificationLabResource) -> URL?, validate: @escaping @Sendable (URL) -> LocalNotificationLabURLValidation)
    func attachmentURL(_ asset: LocalNotificationLabAsset) throws -> URL
    func notificationSoundName() throws -> String
}
@MainActor @Observable final class LocalNotificationLabViewModel {
    init(lab: any ILocalNotificationLabService, appWide: any ILocalNotificationAppWideCapabilities,
         history: any ILocalNotificationEventReading, assets: LocalNotificationLabAssetProvider)
    private(set) var settings: LocalNotificationSettings?
    private(set) var pendingLab: [LocalNotificationPendingSnapshot]; private(set) var deliveredLab: [LocalNotificationDeliveredSnapshot]
    private(set) var pendingAppOwned: [LocalNotificationPendingSnapshot]; private(set) var deliveredAppOwned: [LocalNotificationDeliveredSnapshot]
    private(set) var authorizationOptions: LocalNotificationAuthorizationOptions; private(set) var eventRecords: [LocalNotificationEventRecord]
    private(set) var actualResult: ServiceLabResult
    func setAuthorizationOption(_ option: LocalNotificationAuthorizationOptions, enabled: Bool)
    func refreshSettings() async; func refreshLabLists() async; func refreshAppOwnedLists() async
    func requestSelectedAuthorization() async
    func replaceLabCategories(_ categories: [LocalNotificationCategory]) async; func resetLabCategories() async
    func scheduleLab(_ request: LocalNotificationRequest) async; func removeSelectedPending(_ ids: Set<LocalNotificationID>) async
    func removeSelectedDelivered(_ ids: Set<LocalNotificationID>) async; func resetLabData() async
    func removeAllAppOwnedPendingConfirmed() async; func removeAllAppOwnedDeliveredConfirmed() async
    func setBadgeCount(_ count: Int) async; func clearBadge() async
    func attachmentURL(_ asset: LocalNotificationLabAsset) throws -> URL; func notificationSoundName() throws -> String
    func startEventUpdates() async; func stopEventUpdates() async; func clearEventHistory() async
}
```

- Concrete `LocalNotificationLabService.init(service:catalog:namespace:)` uses raw service only for IDs equal to `services.lab` or prefixed `services.lab.` and rejects every other category/request/removal ID before a service/catalog call. It delegates every category replacement/reset to the catalog. `resetLabData()` first successfully resets lab categories, then removes only lab pending and delivered IDs; a catalog failure throws before removal. It never clears history, badge, Store requests, or Store categories.
- `ServicesDependencies` gains `notificationLab: any ILocalNotificationLabService`, `notificationAppWide: any ILocalNotificationAppWideCapabilities`, `notificationHistory: any ILocalNotificationEventReading`, and `notificationAssets: LocalNotificationLabAssetProvider`; the existing AppDependencies factory supplies the exact phase-6 catalog/history instances and creates scoped facades around them, never another history or raw service field.

- [ ] **Step 1: Write scoped/category/late-subscription coverage RED**

```swift
@Test func labCategoryPreservesStoreCategory() async throws {
    let graph = NotificationLabFixture.withStoreCategory
    try await graph.lab.replaceLabCategories([fixtureLabCategory()])
    #expect(await graph.catalog.ids == ["store.product-reminder", "services.lab"])
}

@MainActor @Test func lateSubscriberRendersReplayAndClearUsesSoleHistory() async {
    let graph = NotificationLabFixture.withExistingHistoryRecord
    let model = graph.makeViewModel()
    await model.startEventUpdates()
    #expect(model.eventRecords.count == 1)
    await model.clearEventHistory()
    #expect(model.eventRecords.isEmpty)
    #expect(await graph.history.records().isEmpty)
}

@MainActor @Test func stoppingObservationReturnsAndPreventsLaterDelivery() async {
    let graph = NotificationLabFixture.empty
    let model = graph.makeViewModel()
    await model.startEventUpdates(); await model.stopEventUpdates()
    await graph.appendSafeFixtureEvent()
    #expect(model.eventRecords.isEmpty)
}

@Test func bundledDemoAssetsAndNamedSoundResolve() throws {
    let provider = LocalNotificationLabAssetProvider(bundle: .main)
    for asset in [LocalNotificationLabAsset.image, .audio, .video] {
        #expect(try provider.attachmentURL(asset).isFileURL)
    }
    #expect(try provider.notificationSoundName() == "notification-demo.aiff")
}
```

One table test invokes every produced method. Authorization tests enumerate raw values `1...15` and prove every nonempty alert/sound/badge/provisional combination is forwarded unchanged; empty, unknown-bit, and mixed-known/unknown values fail with `.invalidAuthorizationOptions` before any service call. The UI exposes four independent toggles, disables Try It while none is selected, and never silently adds an option. The UI contract test covers settings, immediate/interval/calendar, distinctly labelled lab-only pending/delivered lists and selected removals, distinctly labelled app-wide owned lists and confirmed all removals, replace/reset category sets with action/text input, content/metadata, image/audio/video attachment options, event Clear, and badge. Routing spies prove lab refresh/removal calls only `ILocalNotificationLabService`, app-wide refresh/remove calls only `ILocalNotificationAppWideCapabilities`, and app-wide snapshots include both Store and lab IDs without permitting selected arbitrary IDs. A reset-order test proves failed category reset leaves all lab requests untouched, and success removes only lab IDs. An asset-provider table uses the injected resolver/validator to run valid, missing, invalid-file-URL, and unreadable fixtures for every image/audio/video attachment plus the root sound, adds a deterministic 30-seconds-or-longer sound fixture, and expects the exact typed error.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/ServicesNotificationLabTests \
  -only-testing:AppTemplateTests/LocalNotificationLabAssetProviderTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL because the scoped facade and Services notification ViewModel are missing.

- [ ] **Step 3: Implement facade, Basic/Advanced, and scripted UI route**

```swift
func startEventUpdates() async {
    guard eventTask == nil else { return }
    let stream = await history.updates()
    let ready = AsyncOneShotSignal<Void>()
    eventTask = Task { @MainActor [weak self] in
        var didSignalReady = false
        for await records in stream {
            guard !Task.isCancelled else { break }
            self?.eventRecords = records
            if !didSignalReady {
                didSignalReady = true
                _ = await ready.resolve(())
            }
        }
        if !didSignalReady { _ = await ready.resolve(()) }
    }
    await ready.wait()
}
func stopEventUpdates() async {
    let task = eventTask; eventTask = nil
    task?.cancel(); await task?.value
}
```

`LocalNotificationEventHistory.updates()` must atomically register the subscriber and synchronously yield its replay snapshot first; the retained task then consumes only later snapshots. `startEventUpdates()` therefore returns after deterministic replay instead of waiting for the infinite stream and is idempotent. The View owns an outer lifecycle task whose cancellation awaits `stopEventUpdates()`; history `onTermination` then unregisters the continuation. `clearEventHistory()` awaits `history.clear()` and immediately publishes the empty local snapshot. Tests use a bounded signal/timeout (never sleeps) to cover start twice, stop completion, termination, late replay, one live delivery, and clear.

Basic provides safe immediate scheduling and lab-only current lists/history. Advanced exposes the complete operation set from the RED table. Store category is immutable; Services edits only the lab contribution. A separate App-wide Controls section reads its own Store+lab pending/delivered snapshots and owns only confirmed all-removal and badge actions; its state and labels cannot be confused with lab-scoped lists. Authorization forwards exactly the selected validated OptionSet. Populate the already-frozen `UITestScenario.servicesBasic` seed and add `testServicesBasicTryActualResetJourneys()` using `ServicesRobot`; because the black-box XCUITest bundle does not import the app executable module, the robot owns only a nested accessibility-wire `Destination` enum whose raw values are asserted end-to-end against the rendered `ServicesRoute` rows. It never enters production navigation. The final robot assertion waits for `ui-test.script-status.exhausted`; pending/failed/timeout fails. Unscripted operations fail.

Check in the three small original demo resources. The provider resolves image/video under `NotificationDemo`, resolves attachment audio and the custom notification sound from the root resource, requires a readable regular file URL, verifies the named sound through synchronous AudioToolbox metadata with finite positive duration strictly below 30 seconds, and returns only the sound leaf name; missing/invalid/unreadable/too-long resources produce the typed safe error without a deprecated synchronous AVAsset property.

- [ ] **Step 4: Run Phase 7 GREEN**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testServicesBasicTryActualResetJourneys \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: PASS, zero required skips/warnings/live calls; every service shows Expected and Actual and Reset touches only its documented scope.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Features/Services/Infrastructure/LocalNotifications \
  AppTemplate/Resources/NotificationDemo AppTemplate/Resources/notification-demo.aiff \
  AppTemplate/App/Services/LocalNotifications/LocalNotificationDependencies.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift \
  AppTemplate/Features/Services AppTemplateTests/Features/Services \
  AppTemplateUITests/AppTemplateUITests.swift AppTemplateUITests/Robots/ServicesRobot.swift
git commit -m "feat: complete services notification lab"
```
