# Connected Mini Store — Phase 2: Persistence Foundations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Goal

Migrate policy and local data without loss, then expose serialized favorites/cart, Store preferences, and stable cursor pagination.

## Architecture

AppState schema 2 persists only onboarding and maintenance. Frozen SwiftData V1 migrates explicitly to V2, which repeats ExampleRecord and adds favorite/cart entities. Actor repositories own semantic read-modify-write commands. ILocalDatabaseService stays unchanged; the Services Example facade owns strict CREATE validation and lookahead pagination.

## Tech Stack

Swift 6, SwiftData VersionedSchema/SchemaMigrationPlan, actors, AsyncStream, typed UserDefaults, Swift Testing, Xcode 26.

**Normative design:** `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md` at commit `e372913a20bcebd09675fe3f7cf965d2cd40a11d`.

## Global Constraints

- RED → GREEN → regression; each task leaves the project compiling.
- Never alter the LocalDatabaseSchemaV1 declaration after V2 is introduced.
- CREATE accepts only nonempty lowercase ASCII [a-z0-9._-]. The physical ExampleRecordAdapter still accepts every exact nonblank legacy ID; spaces, mixed case, and Unicode remain fetchable/pageable/updatable/deletable and are never rewritten.
- SwiftData applies id > afterID and ascending ID sorting. Swift never reimplements cursor comparison.
- Favorites use canonical (userID, productID); cart uses one constant aggregate ID and monotonic revision.
- Favorites return ascending product ID, and every persisted/returned cart aggregate keeps lines ascending by product ID; concurrent callers cannot make UI ordering nondeterministic.
- Do not edit AppTemplate.xcodeproj/project.pbxproj or AppTemplate/Resources/Localizable.xcstrings; do not stage the spec, graphify-out/, or unrelated changes.

## Task 1: Migrate AppState V1 to policy-only V2

**Create**

- AppTemplateTests/App/ApplicationState/AppStateV1MigrationTests.swift
- AppTemplate/App/Navigation/Routing/LegacyAuthenticationState.swift
- AppTemplateTests/App/Navigation/Routing/LegacyAuthenticationStateTests.swift

**Modify**

- AppTemplate/App/ApplicationState/AppState.swift
- AppTemplate/App/ApplicationState/AppStateStore.swift
- AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift
- AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift
- AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift
- AppTemplate/App/AppDependencies/AppDependencies.swift
- AppTemplate/App/Entry/AppTemplateApp.swift
- AppTemplate/App/Entry/AppLaunchConfiguration.swift
- AppTemplate/App/Entry/UITesting/UITestScenario.swift
- AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift
- AppTemplate/App/Entry/ContentView.swift
- AppTemplate/App/PreviewSupport/PreviewFixtures.swift
- AppTemplateTests/App/ApplicationState/AppStateStoreTests.swift
- AppTemplateTests/App/ApplicationState/Persistence/InMemoryAppStateStorageTests.swift
- AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift
- AppTemplateTests/App/Models/State/AppStateTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift
- AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift
- AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift
- AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift
- AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift
- AppTemplateTests/App/Composition/AppDependenciesTests.swift
- AppTemplateTests/Features/Home/Screens/Home/HomeViewModelTests.swift
- AppTemplateTests/Features/Maintenance/Screens/Maintenance/MaintenanceViewModelTests.swift
- AppTemplateTests/Features/Onboarding/Screens/Onboarding/OnboardingViewModelTests.swift
- AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift
- AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift

**Test**

- AppTemplateTests/App/ApplicationState/AppStateV1MigrationTests.swift
- AppTemplateTests/App/ApplicationState/AppStateStoreTests.swift
- AppTemplateTests/App/Models/State/AppStateTests.swift
- AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift

**Consumes / Produces**

~~~swift
nonisolated struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let initial: AppState
    let schemaVersion: Int
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool
    init(
        schemaVersion: Int = currentSchemaVersion,
        hasCompletedOnboarding: Bool,
        isMaintenanceEnabled: Bool
    )
}
nonisolated enum AppStatePersistenceFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
    case encodingFailed
    case migrationSaveFailed
    case unsupportedFutureSchema(Int)
}
@MainActor @Observable final class LegacyAuthenticationState {
    private(set) var isAuthenticated: Bool
    init(isAuthenticated: Bool = false)
    func signIn(); func signOut()
}
~~~

- [ ] **RED:** Decode literal schema-1 bytes with isAuthenticated=true. Assert both policy flags survive and V2 is saved, while the discarded Boolean never seeds the temporary runtime authentication owner. On migration-save failure assert migrated flags remain visible, currentData remains the original bytes, savedData is empty, and status is migrationSaveFailed. Freeze a literal schema-3 future fixture: it remains byte-for-byte untouched, publishes `.readOnly(.unsupportedFutureSchema(3))`, and no mutation or repair write succeeds; schema 2 is current and must no longer be used as the future-version fixture. Until phase 3 installs Session, preserve the active legacy Authentication and Settings examples through one app-owned, deliberately nonpersisted `LegacyAuthenticationState`: Sign In selects Main, Sign Out selects Authentication, and Onboarding/Maintenance keep their existing priority. Relaunch starts signed out even if schema 1 said true. Tests prove the working transition in both views, no AppState save for auth actions, and one shared owner across scenes.

~~~swift
@Test @MainActor func failedMigrationPreservesV1Bytes() {
    let old = Data(#"{"schemaVersion":1,"isAuthenticated":true,"hasCompletedOnboarding":true,"isMaintenanceEnabled":false}"#.utf8)
    let storage = AppStateStorageSpy(loadResult: .data(old), saveError: TestError.failed)
    let store = AppStateStore(storage: storage)
    #expect(store.state.hasCompletedOnboarding)
    #expect(storage.currentData == old)
    #expect(storage.savedData.isEmpty)
    #expect(store.persistenceStatus == .readOnly(.migrationSaveFailed))
}
~~~

- [ ] Run RED; expect removed AppState property/initializer errors and missing migrationSaveFailed.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppStateV1MigrationTests -only-testing:AppTemplateTests/AppStateStoreTests -only-testing:AppTemplateTests/AppStateTests
~~~

- [ ] **GREEN:** Add a frozen private AppStateV1 decoder, discard only isAuthenticated, and treat migration as an explicit resolution. Publish decoded policy, attempt V2 save, then mark writable; failure never repairs/removes old bytes. Future schema 3+ follows the existing fail-closed read-only path and never saves over its loaded bytes. During this compiling transition, `AppFlowPolicy.resolve(_:legacyAuthentication:)` reads policy flags plus the app-owned observable `LegacyAuthenticationState`; `AppFlowCoordinator.signIn/signOut` mutate only that runtime owner and perform the same typed root transitions the existing examples expect, never AppState storage. AppDependencies/AppTemplateApp create it once and pass it to the coordinator; previews/tests inject a fresh value. Update shared `makeTestAppFlowCoordinator` to construct/pass the same fresh legacy owner and call the transitional policy signature, so every feature suite remains source-compatible without global state. Phase 3 atomically removes this owner and `.authentication` root when Session restoration lands. Run `rg -n 'isAuthenticated|AppState\(' AppTemplate AppTemplateTests -g '*.swift'` and update every source, fixture, and feature/navigation test in the Modify list in the same compiling commit; after frozen schema-1 fixtures are excluded, no active caller reads or initializes `AppState.isAuthenticated`.

~~~swift
private struct AppStateV1: Decodable {
    let schemaVersion: Int
    let isAuthenticated: Bool
    let hasCompletedOnboarding: Bool
    let isMaintenanceEnabled: Bool
    var migrated: AppState {
        AppState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isMaintenanceEnabled: isMaintenanceEnabled
        )
    }
}
~~~

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppStateV1MigrationTests -only-testing:AppTemplateTests/AppStateStoreTests -only-testing:AppTemplateTests/AppStateTests -only-testing:AppTemplateTests/LegacyAuthenticationStateTests -only-testing:AppTemplateTests/AppFlowPolicyTests -only-testing:AppTemplateTests/AppFlowCoordinatorTests -only-testing:AppTemplateTests/SettingsViewModelTests -only-testing:AppTemplateTests/AppDependenciesTests
git add AppTemplate/App/ApplicationState/AppState.swift AppTemplate/App/ApplicationState/AppStateStore.swift AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift AppTemplate/App/Navigation/Routing/LegacyAuthenticationState.swift AppTemplate/App/Navigation/Routing/AppFlowPolicy.swift AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/UITesting/UITestScenario.swift AppTemplate/App/Entry/UITesting/UITestScenarioSeeds.swift AppTemplate/App/Entry/ContentView.swift AppTemplate/App/PreviewSupport/PreviewFixtures.swift AppTemplateTests/App/ApplicationState/AppStateV1MigrationTests.swift AppTemplateTests/App/ApplicationState/AppStateStoreTests.swift AppTemplateTests/App/ApplicationState/Persistence/InMemoryAppStateStorageTests.swift AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift AppTemplateTests/App/Models/State/AppStateTests.swift AppTemplateTests/App/Navigation/Routing/LegacyAuthenticationStateTests.swift AppTemplateTests/App/Navigation/Routing/AppFlowPolicyTests.swift AppTemplateTests/App/Navigation/Routing/AppFlowCoordinatorTests.swift AppTemplateTests/App/Navigation/Routing/AppRouterTests.swift AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationLifecycleTests.swift AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift AppTemplateTests/App/Composition/AppDependenciesTests.swift AppTemplateTests/Features/Home/Screens/Home/HomeViewModelTests.swift AppTemplateTests/Features/Maintenance/Screens/Maintenance/MaintenanceViewModelTests.swift AppTemplateTests/Features/Onboarding/Screens/Onboarding/OnboardingViewModelTests.swift AppTemplateTests/Features/Settings/Screens/Settings/SettingsViewModelTests.swift AppTemplateTests/TestSupport/AppFlowCoordinatorSpy.swift
git commit -m "feat: migrate app state policy to schema two"
~~~

## Task 2: Freeze V1 and migrate disk SwiftData to V2

**Create**

- AppTemplate/App/Models/Store/ProductSnapshot.swift
- AppTemplate/App/Models/Store/FavoriteProductSnapshot.swift
- AppTemplate/App/Models/Store/CartLine.swift
- AppTemplate/App/Models/Store/CartAggregate.swift
- AppTemplate/App/Services/LocalDatabase/Adapters/FavoriteProductSnapshotAdapter.swift
- AppTemplate/App/Services/LocalDatabase/Adapters/CartAggregateAdapter.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseV1ToV2MigrationTests.swift

**Modify**

- AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift
- AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift
- AppTemplate/App/Services/LocalDatabase/LocalDatabaseModelRegistry.swift
- AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift
- AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift
- AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift

**Test**

- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseV1ToV2MigrationTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift
- AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift

**Consumes / Produces**

~~~swift
nonisolated enum LocalDatabaseSchemaV2: VersionedSchema {
    static let versionIdentifier: Schema.Version
    static var models: [any PersistentModel.Type] { get }
}
// Nested in LocalDatabaseSchemaV2 in LocalDatabaseSchema.swift.
@Model final class StoredFavoriteProductSnapshot {
    @Attribute(.unique) var canonicalID: String
    var userID: Int
    var productID: Int
    var snapshotData: Data
}
@Model final class StoredCartAggregate {
    @Attribute(.unique) var id: String
    var revision: Int64
    var linesData: Data
}
nonisolated struct ProductSnapshot: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let price: Decimal
    let thumbnailURL: URL?
}
nonisolated struct FavoriteProductSnapshot: LocalDatabaseModel, Codable, Equatable, Sendable {
    static func canonicalID(userID: Int, productID: Int) -> String
    let canonicalID: String
    let userID: Int
    let product: ProductSnapshot
    var id: String { canonicalID }
}
nonisolated struct CartLine: Codable, Equatable, Sendable {
    let product: ProductSnapshot
    var quantity: Int
}
nonisolated struct CartAggregate: LocalDatabaseModel, Codable, Equatable, Sendable {
    static let singletonID: String
    let id: String
    var revision: Int64
    var lines: [CartLine]
}
~~~

`FavoriteProductSnapshot` freezes `typealias ID = String`, `Query = FavoriteProductQuery`, and `Persistence = FavoriteProductSnapshotAdapter`; `CartAggregate` freezes `typealias ID = String`, `Query = CartAggregateQuery`, and `Persistence = CartAggregateAdapter`. Each adapter declares the matching `Value`/V2 `Entity`/`Query` associated types, so all three `LocalDatabaseModel` conformances are compile-time bijections rather than registry-only assertions.

`FavoriteProductSnapshot.canonicalID(userID:productID:)` returns `"user:\(userID)|product:\(productID)"`. User/product IDs and cart product IDs are positive, quantities are positive, product prices are finite/nonnegative Decimal values, and duplicate cart product IDs are rejected on decode. `CartAggregate.singletonID` is exactly `"Store.Cart"`; adapters validate identities/invariants rather than repairing them.

- [ ] **RED:** Create/close a genuinely V1-only disk container with ID " Legacy-Ж " and payload "legacy 😀 café"; compare Data(payload.utf8) after V2 reopen, exercise both new entities, and assert schema/registry entity identity sets match.

~~~swift
@Test func v1DiskReopensWithoutRewriting() async throws {
    let payload = "legacy 😀 café"
    let url = temporaryStoreURL()
    try writeFrozenV1Record(id: " Legacy-Ж ", payload: payload, at: url)
    let service = try LocalDatabaseService(configuration: .disk(url: url))
    let value = try await service.fetch(ExampleRecord.self, id: " Legacy-Ж ")
    #expect(value.map { Data($0.payload.utf8) } == Data(payload.utf8))
    #expect(LocalDatabaseModelRegistry.production.registrationCount == 3)
}
~~~

- [ ] Run RED; expect missing V2/models/adapters and registry mismatch.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/LocalDatabaseV1ToV2MigrationTests -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests
~~~

- [ ] **GREEN:** Keep V1 declaration unchanged. In LocalDatabaseSchema.swift, declare nested V2 StoredExampleRecord with identical id/payload and the stored models above. Encode ProductSnapshot/CartLine arrays with JSONEncoder.outputFormatting = [.sortedKeys]; reject favorite snapshotData over 64 KiB and cart linesData over 256 KiB on encode and decode. Add the explicit lightweight stage. Point all production adapters/factories to V2 and register exactly three adapters. Move every active adapter/store fixture to V2: `ExampleRecordAdapterTests` constructs the V2 entity, generic test support pairs the production adapter only with the V2 schema, batch/mutation tests use the V2 registry/configuration, and contract tests expect schemas `[V1,V2]`, one explicit stage, and three registrations. V1 entities/containers remain available only in the explicit on-disk migration fixture and are never passed to the production V2 adapter.

~~~swift
static let migrateV1ToV2 = MigrationStage.lightweight(
    fromVersion: LocalDatabaseSchemaV1.self,
    toVersion: LocalDatabaseSchemaV2.self
)
static var schemas: [any VersionedSchema.Type] {
    [LocalDatabaseSchemaV1.self, LocalDatabaseSchemaV2.self]
}
static var stages: [MigrationStage] { [migrateV1ToV2] }
~~~

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/LocalDatabaseV1ToV2MigrationTests -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests -only-testing:AppTemplateTests/LocalDatabasePersistenceTests -only-testing:AppTemplateTests/ExampleRecordAdapterTests -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests -only-testing:AppTemplateTests/LocalDatabaseContractTests
git add AppTemplate/App/Models/Store/ProductSnapshot.swift AppTemplate/App/Models/Store/FavoriteProductSnapshot.swift AppTemplate/App/Models/Store/CartLine.swift AppTemplate/App/Models/Store/CartAggregate.swift AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift AppTemplate/App/Services/LocalDatabase/Adapters/FavoriteProductSnapshotAdapter.swift AppTemplate/App/Services/LocalDatabase/Adapters/CartAggregateAdapter.swift AppTemplate/App/Services/LocalDatabase/LocalDatabaseModelRegistry.swift AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseV1ToV2MigrationTests.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift
git commit -m "feat: migrate local database to schema two"
~~~

## Task 3: Add atomic Store repositories and broadcast preferences

**Create**

- AppTemplate/App/Repositories/Store/IFavoritesRepository.swift
- AppTemplate/App/Repositories/Store/FavoritesRepository.swift
- AppTemplate/App/Repositories/Store/ICartRepository.swift
- AppTemplate/App/Repositories/Store/CartRepository.swift
- AppTemplate/App/Repositories/Store/IStorePreferencesRepository.swift
- AppTemplate/App/Repositories/Store/StorePreferencesRepository.swift
- AppTemplate/App/Repositories/Store/CartRepositoryError.swift
- AppTemplate/App/Models/Store/StorePreferences.swift
- AppTemplate/App/Utilities/Concurrency/AsyncOperationGate.swift
- AppTemplateTests/App/Utilities/Concurrency/AsyncOperationGateTests.swift
- AppTemplateTests/App/Repositories/Store/FavoritesRepositoryTests.swift
- AppTemplateTests/App/Repositories/Store/CartRepositoryTests.swift
- AppTemplateTests/App/Repositories/Store/StorePreferencesRepositoryTests.swift

**Modify**

- AppTemplate/App/AppDependencies/AppDependencies.swift
- AppTemplateTests/App/Composition/AppDependenciesTests.swift

**Test**

- AppTemplateTests/App/Utilities/Concurrency/AsyncOperationGateTests.swift
- AppTemplateTests/App/Repositories/Store/FavoritesRepositoryTests.swift
- AppTemplateTests/App/Repositories/Store/CartRepositoryTests.swift
- AppTemplateTests/App/Repositories/Store/StorePreferencesRepositoryTests.swift

**Consumes / Produces**

~~~swift
nonisolated protocol IFavoritesRepository: Sendable {
    func favorites(userID: Int) async throws -> [FavoriteProductSnapshot]
    func contains(userID: Int, productID: Int) async throws -> Bool
    @discardableResult func ensureFavorite(_ product: ProductSnapshot, userID: Int) async throws -> Bool
    @discardableResult func removeFavorite(userID: Int, productID: Int) async throws -> Bool
    @discardableResult func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool
}
nonisolated protocol ICartRepository: Sendable {
    func cart() async throws -> CartAggregate
    func add(_ product: ProductSnapshot, quantity: Int) async throws -> CartAggregate
    func setQuantity(productID: Int, quantity: Int) async throws -> CartAggregate
    func remove(productID: Int) async throws -> CartAggregate
    func checkout(expectedRevision: Int64) async throws
}
nonisolated enum CartRepositoryError: Error, Equatable, Sendable {
    case invalidQuantity
    case emptyCart
    case revisionConflict(expected: Int64, actual: Int64)
}
nonisolated enum StoreCatalogLayout: String, CaseIterable, Codable, Equatable, Sendable {
    case grid, list
}
nonisolated enum StoreCatalogSort: String, CaseIterable, Codable, Equatable, Sendable {
    case featured, titleAscending, titleDescending, priceAscending, priceDescending
}
nonisolated struct StorePreferences: Equatable, Sendable {
    let layout: StoreCatalogLayout
    let sort: StoreCatalogSort
    let preferredRemotePageSize: Int
    static let defaults: StorePreferences
}
nonisolated protocol IStorePreferencesRepository: Sendable {
    func current() async -> StorePreferences
    func updates() async -> AsyncStream<StorePreferences>
    func setLayout(_ layout: StoreCatalogLayout) async throws
    func setSort(_ sort: StoreCatalogSort) async throws
    func setPreferredRemotePageSize(_ size: Int) async throws
}
actor AsyncOperationGate {
    func withExclusiveAccess<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> Value
}
~~~

- [ ] **RED:** Race concurrent ensureFavorite calls and prove one canonical row plus one true/remaining false result; fetch favorites seeded out of order and require ascending product ID. Race cart adds and require persisted/returned lines to remain ascending by product ID; verify positive quantity/ID/snapshot invariants, empty-checkout rejection without revision change, monotonic revisions, stale checkout conflict, successful checkout persisting an empty aggregate at `revision + 1`, and a later add continuing from that revision. Also cover preference choices 10/20/30/50 with default 20, isolated corrupt-key repair, and multi-subscriber broadcasts. A barrier test pauses command one after its database read; command two must not begin its read until command one persists or throws/cancels and releases. Gate waiters acquire FIFO; cancelling a queued waiter removes it without blocking successors.

~~~swift
@Test func checkoutRejectsStaleRevision() async throws {
    let repository = CartRepository(database: try makeDatabase())
    let first = try await repository.add(.fixture(id: 1), quantity: 1)
    let second = try await repository.add(.fixture(id: 2), quantity: 1)
    await #expect(throws: CartRepositoryError.revisionConflict(
        expected: first.revision,
        actual: second.revision
    )) {
        try await repository.checkout(expectedRevision: first.revision)
    }
}
~~~

- [ ] Run RED; expect missing repository actors and preference types.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AsyncOperationGateTests -only-testing:AppTemplateTests/FavoritesRepositoryTests -only-testing:AppTemplateTests/CartRepositoryTests -only-testing:AppTemplateTests/StorePreferencesRepositoryTests
~~~

- [ ] **GREEN:** AsyncOperationGate implements cancellable FIFO acquisition and releases in defer after success/error/cancellation. Each app-scoped Favorites/Cart actor owns a gate and wraps the entire database read-modify-write in one withExclusiveAccess closure. The closure captures database/value arguments and never calls back into its repository actor. ensureFavorite is idempotent and returns true only when it inserts; removeFavorite returns true only when it removes the canonical row; `favorites(userID:)` sorts by `product.id`. Every cart mutation sorts lines by `product.id` before its single persist and increments revision exactly once. Checkout never deletes the singleton row: after matching `expectedRevision`, it persists the same aggregate ID with no lines and `revision + 1`, so revisions cannot reset and a stale checkout cannot clear a later cart. Preferences use Store.CatalogLayout, Store.CatalogSort, Store.RemotePageSize and repair only the corrupt key. Preference updates use `.bufferingNewest(1)` and continuation `onTermination` removes the subscriber from actor state; tests cancel subscribers and prove no retained continuation.

~~~swift
guard current.revision == expectedRevision else {
    throw CartRepositoryError.revisionConflict(
        expected: expectedRevision,
        actual: current.revision
    )
}
guard !current.lines.isEmpty else { throw CartRepositoryError.emptyCart }
try await database.upsert(
    CartAggregate(
        id: CartAggregate.singletonID,
        revision: current.revision + 1,
        lines: []
    )
)
~~~

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AsyncOperationGateTests -only-testing:AppTemplateTests/FavoritesRepositoryTests -only-testing:AppTemplateTests/CartRepositoryTests -only-testing:AppTemplateTests/StorePreferencesRepositoryTests -only-testing:AppTemplateTests/AppDependenciesTests
git add AppTemplate/App/Utilities/Concurrency/AsyncOperationGate.swift AppTemplateTests/App/Utilities/Concurrency/AsyncOperationGateTests.swift AppTemplate/App/Repositories/Store AppTemplate/App/Models/Store/StorePreferences.swift AppTemplate/App/AppDependencies/AppDependencies.swift AppTemplateTests/App/Repositories/Store AppTemplateTests/App/Composition/AppDependenciesTests.swift
git commit -m "feat: add atomic store repositories"
~~~

## Task 4: Add strict CREATE and stable cursor pagination facade

**Create**

- AppTemplate/App/Repositories/Services/ILocalDatabaseExampleRepository.swift
- AppTemplate/App/Repositories/Services/LocalDatabaseExampleRepository.swift
- AppTemplate/App/Repositories/Services/ExampleRecordCreationValidator.swift
- AppTemplate/App/Models/Local/LocalDatabasePage.swift
- AppTemplateTests/App/Repositories/Services/LocalDatabaseExampleRepositoryTests.swift

**Modify**

- AppTemplate/App/Models/Local/ExampleQuery.swift
- AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift
- AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift
- AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift

**Test**

- AppTemplateTests/App/Repositories/Services/LocalDatabaseExampleRepositoryTests.swift
- AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift

**Type ownership:** `LocalDatabasePage.swift` defines `LocalDatabasePage`; `ILocalDatabaseExampleRepository.swift` defines the complete facade protocol and `ExampleRecordRepositoryError`; `ExampleRecordCreationValidator.swift` defines the strict CREATE validator.

**Consumes / Produces**

~~~swift
nonisolated struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let afterID: String?
    let limit: Int
}
nonisolated struct LocalDatabasePage<Value: Sendable, Cursor: Sendable>: Sendable {
    let values: [Value]
    let nextCursor: Cursor?
    let hasMore: Bool
}
nonisolated enum ExampleRecordRepositoryError: Error, Equatable, Sendable {
    case invalidID, invalidPageSize, alreadyExists, notFound
}
nonisolated enum ExampleRecordCreationValidator {
    static func validateNewID(_ id: String) throws
}
nonisolated protocol ILocalDatabaseExampleRepository: Sendable {
    func fetch(id: String) async throws -> ExampleRecord?
    func page(searchText: String?, afterID: String?, pageSize: Int) async throws -> LocalDatabasePage<ExampleRecord, String>
    func create(id: String, payload: String) async throws
    func update(id: String, payload: String) async throws
    func upsert(_ record: ExampleRecord) async throws
    func upsertBatch(_ records: [ExampleRecord]) async throws
    @discardableResult func delete(id: String) async throws -> Bool
    @discardableResult func deleteAll() async throws -> Int
}
actor LocalDatabaseExampleRepository: ILocalDatabaseExampleRepository {
    init(database: any ILocalDatabaseService)
}
~~~

- [ ] **RED:** Persist ASCII/whitespace/mixed-case/Unicode IDs across reopen. Verify page stability, sparse normalized search, insertion before/after cursor, page sizes 1...50, strict create, legacy fetch/update/delete, single upsert replacing an existing legacy/strict row and inserting a valid new ID, plus single/batch upsert strictness only for newly inserted identities.

~~~swift
@Test func createIsStrictButLegacyMutationsRemainValid() async throws {
    let repository = try makeRepository(seedID: " Legacy-Ж ")
    await #expect(throws: ExampleRecordRepositoryError.invalidID) {
        try await repository.create(id: "New ID", payload: "x")
    }
    #expect(try await repository.fetch(id: " Legacy-Ж ") != nil)
    try await repository.update(id: " Legacy-Ж ", payload: "changed")
    #expect(try await repository.delete(id: " Legacy-Ж "))
}
~~~

- [ ] Run RED; expect missing afterID/page/facade and failing cursor assertions.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/LocalDatabaseExampleRepositoryTests -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests
~~~

- [ ] **GREEN:** Branch descriptor construction outside #Predicate and use the same V2 key path/sort.

~~~swift
if let afterID = query.afterID {
    descriptor = FetchDescriptor<LocalDatabaseSchemaV2.StoredExampleRecord>(
        predicate: #Predicate { $0.id > afterID },
        sortBy: [SortDescriptor(\LocalDatabaseSchemaV2.StoredExampleRecord.id)]
    )
} else {
    descriptor = FetchDescriptor<LocalDatabaseSchemaV2.StoredExampleRecord>(
        sortBy: [SortDescriptor(\LocalDatabaseSchemaV2.StoredExampleRecord.id)]
    )
}
~~~

Then normalized-search the ordered post-cursor scan and apply limit. Facade validates lowercase ASCII only for create and newly inserted IDs in single/batch upsert, requests pageSize+1, trims lookahead, and returns the last visible ID only when hasMore. `create` first rejects an exact existing identity with `.alreadyExists`; `update` first requires an exact existing row and returns `.notFound` instead of silently upserting a new identity. Single upsert replaces an existing exact legacy/strict identity without rewriting its ID, or validates a new ID before insert; batch uses the same per-identity rule atomically. The repository actor serializes these check/write pairs. Physical adapter validate(id:) remains exact nonblank. UI resets cursor on search/page-size/refresh/mutation.

- [ ] Run PASS and commit.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/LocalDatabaseExampleRepositoryTests -only-testing:AppTemplateTests/ExampleRecordAdapterTests -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests -only-testing:AppTemplateTests/LocalDatabasePersistenceTests -only-testing:AppTemplateTests/LocalDatabaseContractTests
git add AppTemplate/App/Repositories/Services AppTemplate/App/Models/Local/LocalDatabasePage.swift AppTemplate/App/Models/Local/ExampleQuery.swift AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift AppTemplateTests/App/Repositories/Services/LocalDatabaseExampleRepositoryTests.swift AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift
git commit -m "feat: add cursor local database facade"
~~~

## Phase 2 Verification

- [ ] Run all tests/build and inspect forbidden paths.

~~~bash
xcodebuild test -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -quiet -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
git status --short
git diff --cached --name-only
~~~
