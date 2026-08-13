import Foundation
import Synchronization
import SwiftUI
import Testing
import UserNotifications
@testable import AppTemplate

@MainActor
struct AppDependenciesTests {
    @MainActor
    @Test
    func previewGraphsUseFreshInMemoryNotifications() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let first = AppDependencies.preview(settings: settings)
        let second = AppDependencies.preview(settings: settings)

        try await first.localNotifications.service.schedule(
            LocalNotificationFixtures.request(id: "one")
        )

        #expect(await second.localNotifications.service.pending().isEmpty)
    }

    @Test
    func liveNotificationGraphResolvesAndInstallsOnceBeforeCenterWork() async throws {
        let recorder = NotificationCompositionRecorder()
        let api = RecordingUserNotificationCenterAPI(recorder: recorder)
        let runtime = makeRuntime(api: api, recorder: recorder)

        let dependencies = LocalNotificationDependencies.live(
            runtimeResolver: {
                recorder.record("resolve")
                return runtime
            }
        )

        #expect(recorder.values == ["resolve", "install"])
        #expect(api.operations.isEmpty)

        try await dependencies.bootstrapCategoriesIfNeeded()
        try await dependencies.bootstrapCategoriesIfNeeded()

        #expect(recorder.values == ["resolve", "install", "categories.read", "categories.set"])
        #expect(api.operations == ["categories.read", "categories.set"])
    }

    @Test
    func concurrentEmptyCatalogBootstrapReplacesOwnedCategoriesOnlyOnce() async throws {
        let recorder = NotificationCompositionRecorder()
        let owned = UNNotificationCategory(
            identifier: "AppTemplate.LocalNotification.category.stale",
            actions: [],
            intentIdentifiers: []
        )
        let foreign = UNNotificationCategory(
            identifier: "Foreign.category",
            actions: [],
            intentIdentifiers: []
        )
        let api = RecordingUserNotificationCenterAPI(
            recorder: recorder,
            categories: [owned, foreign]
        )
        let runtime = makeRuntime(api: api, recorder: recorder)
        let dependencies = LocalNotificationDependencies.live(
            runtimeResolver: { runtime }
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await dependencies.bootstrapCategoriesIfNeeded()
                }
            }
            try await group.waitForAll()
        }

        #expect(api.operations == ["categories.read", "categories.set"])
        #expect(api.installedCategoryIdentifiers == ["Foreign.category"])
    }

    @Test
    func liveNotificationGraphStronglyRetainsBridgeWhenInstallerIsWeak() {
        let recorder = NotificationCompositionRecorder()
        let api = RecordingUserNotificationCenterAPI(recorder: recorder)
        let weakInstaller = WeakNotificationDelegateInstaller()
        let runtime = UserNotificationCenterRuntimeFactory.make(
            makeClient: { UserNotificationCenterClient(api: api) },
            installDelegate: { weakInstaller.install($0) }
        )
        var dependencies: LocalNotificationDependencies? = .live(
            runtimeResolver: { runtime }
        )

        #expect(weakInstaller.installCount == 1)
        #expect(weakInstaller.delegate != nil)

        dependencies = nil

        #expect(dependencies == nil)
        #expect(weakInstaller.delegate == nil)
    }

    @Test
    func previewUITestAndInMemoryFactoriesNeverResolveLiveRuntime() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: false,
            isMaintenanceEnabled: false
        )
        let preview = AppDependencies.preview(settings: settings)
        let uiTest = AppDependencies.uiTesting(initialState: state)
        let direct = LocalNotificationDependencies.inMemory()

        #expect(preview.localNotifications.service is InMemoryLocalNotificationService)
        #expect(uiTest.localNotifications.service is InMemoryLocalNotificationService)
        #expect(direct.service is InMemoryLocalNotificationService)
        try await preview.localNotifications.bootstrapCategoriesIfNeeded()
        try await uiTest.localNotifications.bootstrapCategoriesIfNeeded()
        try await direct.bootstrapCategoriesIfNeeded()
    }

    @Test
    func requiredCategoryInMemoryFactoryBuildsAValidatedSchedulableCatalog() async throws {
        let category = try LocalNotificationFixtures.category(id: "configured")
        let graph = try LocalNotificationDependencies.inMemory(
            requiredCategories: [category]
        )
        let request = LocalNotificationRequest(
            id: try LocalNotificationID("request"),
            content: LocalNotificationContent(
                body: "Body",
                categoryID: category.id
            ),
            trigger: .immediate
        )

        try await graph.service.schedule(request)

        #expect(await graph.service.pending().map(\.id) == [request.id])
    }

    @Test
    func appDependencyFactoriesKeepTheExactInjectedNotificationGraph() throws {
        let notifications = LocalNotificationDependencies.inMemory()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Injected", version: "1")
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
            localNotifications: notifications
        )

        #expect(
            dependencies.localNotifications.service as AnyObject
                === notifications.service as AnyObject
        )
        #expect(dependencies.localNotifications.eventHub === notifications.eventHub)
        #expect(
            dependencies.localNotifications.navigationCoordinator
                === notifications.navigationCoordinator
        )
    }

    @Test
    func sceneRegistrationPublishesLatestEligibilityOnlyAfterBootstrap() async throws {
        let graph = LocalNotificationDependencies.inMemory()
        let registration = LocalNotificationSceneRegistration(
            coordinator: graph.navigationCoordinator
        )
        let receiver = NotificationSceneReceiver()
        let bootstrap = ControlledNotificationBootstrap()
        let runTask = Task {
            await registration.run(
                receiver: receiver,
                bootstrap: { try await bootstrap.wait() }
            )
        }
        await bootstrap.waitUntilEntered()

        registration.setEligible(true)
        registration.setEligible(false)
        registration.setEligible(true)
        await bootstrap.resume()
        await bootstrap.waitUntilReturned()

        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://settings")
        )
        await receiver.waitForCount(1)
        #expect(receiver.urls == [URL(string: "apptemplate://settings")!])

        runTask.cancel()
        await runTask.value
    }

    @Test
    func sceneRegistrationContinuesNavigationAfterBootstrapFailure() async throws {
        let graph = LocalNotificationDependencies.inMemory()
        let registration = LocalNotificationSceneRegistration(
            coordinator: graph.navigationCoordinator
        )
        let receiver = NotificationSceneReceiver()
        registration.setEligible(true)
        let runTask = Task {
            await registration.run(
                receiver: receiver,
                bootstrap: { throw NotificationCompositionTestError.bootstrap }
            )
        }

        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://home")
        )
        await receiver.waitForCount(1)
        #expect(receiver.urls == [URL(string: "apptemplate://home")!])

        runTask.cancel()
        await runTask.value
    }

    @Test
    func cancellingSceneRegistrationUnregistersItsReceiver() async throws {
        let graph = LocalNotificationDependencies.inMemory()
        let registration = LocalNotificationSceneRegistration(
            coordinator: graph.navigationCoordinator
        )
        let first = NotificationSceneReceiver()
        registration.setEligible(true)
        let runTask = Task {
            await registration.run(receiver: first, bootstrap: {})
        }
        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://home")
        )
        await first.waitForCount(1)

        runTask.cancel()
        await runTask.value
        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://browse")
        )

        let second = NotificationSceneReceiver()
        let secondID = UUID()
        graph.navigationCoordinator.register(id: secondID, receiver: second)
        graph.navigationCoordinator.setEligible(true, id: secondID)
        await second.waitForCount(1)
        #expect(first.urls == [URL(string: "apptemplate://home")!])
        #expect(second.urls == [URL(string: "apptemplate://browse")!])
    }

    @Test
    func staleSceneTaskCleanupCannotUnregisterNewerGeneration() async throws {
        let graph = LocalNotificationDependencies.inMemory()
        let registration = LocalNotificationSceneRegistration(
            coordinator: graph.navigationCoordinator
        )
        let receiver = NotificationSceneReceiver()
        registration.setEligible(true)
        let firstBootstrap = ControlledNotificationBootstrap()
        let firstTask = Task {
            await registration.run(
                receiver: receiver,
                bootstrap: { try await firstBootstrap.wait() }
            )
        }
        await firstBootstrap.waitUntilEntered()
        let secondTask = Task {
            await registration.run(receiver: receiver, bootstrap: {})
        }
        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://home")
        )
        await receiver.waitForCount(1)

        await firstBootstrap.resume()
        await firstTask.value
        await graph.eventHub.publish(
            try LocalNotificationFixtures.openedFixture(url: "apptemplate://projects")
        )
        await receiver.waitForCount(2)
        #expect(
            receiver.urls == [
                URL(string: "apptemplate://home")!,
                URL(string: "apptemplate://projects")!
            ]
        )

        secondTask.cancel()
        await secondTask.value
    }

    @Test
    func iOSScenePhaseEligibilityMapsOnlyActiveToTrue() {
        #expect(LocalNotificationSceneEligibility.isEligible(.active))
        #expect(!LocalNotificationSceneEligibility.isEligible(.inactive))
        #expect(!LocalNotificationSceneEligibility.isEligible(.background))
    }

    @Test
    func liveGraphUsesDeclaredServices() {
        let dependencies = AppDependencies.live(
            localNotifications: .inMemory()
        )

        #expect(dependencies.localDatabase is LocalDatabaseService)
        #expect(dependencies.remote is RemoteService)
        #expect(dependencies.appStateStorage is UserDefaultsAppStateStorage)
        #expect(dependencies.keychain is KeychainService)
        #expect(dependencies.settings.appInfo is AppInfoService)
    }

    @Test
    func liveGraphRetainsInjectedKeychainExactlyWithoutEagerAccess() async throws {
        let injected = KeychainServiceSpy()
        let dependencies = AppDependencies.live(
            keychainService: injected,
            localNotifications: .inMemory()
        )
        let resolved = try #require(dependencies.keychain as? KeychainServiceSpy)

        #expect(resolved === injected)
        let counts = await injected.callCounts()
        #expect(counts.reads == 0)
        #expect(counts.writes == 0)
        #expect(counts.removals == 0)
    }

    @Test func liveGraphConsumesInjectedUserDefaultsServiceThroughAppStateAdapter() throws {
        let spy = UserDefaultsServiceSpy(value: Data([0x01, 0x02]))
        let dependencies = AppDependencies.live(
            userDefaultsService: spy,
            localNotifications: .inMemory()
        )
        let storage = dependencies.appStateStorage

        #expect(try storage.load() == .data(Data([0x01, 0x02])))
        try storage.save(Data([0x03]))
        try storage.remove()
        let expectedKey = UserDefaultsServiceSpy.KeyRecord(
            logicalName: "AppState",
            physicalKind: .data
        )
        #expect(spy.requestedValueKeys == [expectedKey])
        #expect(spy.requestedSetKeys == [expectedKey])
        #expect(spy.savedValues == [Data([0x03])])
        #expect(spy.requestedRemoveKeys == [expectedKey])
    }

    @Test
    func liveGraphDefersResolverUntilFirstValidRegisteredOperation() async {
        let calls = Mutex(0)
        let dependencies = AppDependencies.live(
            localDatabaseStoreLocationResolver: .init(resolve: {
                calls.withLock { $0 += 1 }
                throw LocalDatabaseTestError.injectedFailure
            }),
            localNotifications: .inMemory()
        )

        #expect(calls.withLock { $0 } == 0)
        do {
            _ = try await dependencies.localDatabase.fetch(
                ExampleRecord.self,
                id: "record-1"
            )
            Issue.record("Expected initialization failure")
        } catch let error as LocalDatabaseError {
            guard case .initialization = error else {
                Issue.record("Expected LocalDatabaseError.initialization")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
        #expect(calls.withLock { $0 } == 1)
    }

    @Test
    func previewAndUITestingGraphsUseFreshDatabases() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let firstPreview = AppDependencies.preview(settings: settings)
        let secondPreview = AppDependencies.preview(settings: settings)
        try await firstPreview.localDatabase.upsert(
            ExampleRecord(id: "preview", payload: "first")
        )
        #expect(
            try await secondPreview.localDatabase.fetch(
                ExampleRecord.self,
                id: "preview"
            )
                == nil
        )

        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstUI = AppDependencies.uiTesting(initialState: state)
        let secondUI = AppDependencies.uiTesting(initialState: state)
        try await firstUI.localDatabase.upsert(
            ExampleRecord(id: "ui", payload: "first")
        )
        #expect(
            try await secondUI.localDatabase.fetch(
                ExampleRecord.self,
                id: "ui"
            ) == nil
        )
    }

    @Test
    func previewAndUITestingGraphsUseFreshInMemoryKeychains() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let preview1 = AppDependencies.preview(settings: settings)
        let preview2 = AppDependencies.preview(settings: settings)
        try await preview1.keychain.set(Data([1]), for: .data("Isolation"))
        #expect(try await preview2.keychain.data(for: .data("Isolation")) == nil)

        let state = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: false,
            isMaintenanceEnabled: false
        )
        let ui1 = AppDependencies.uiTesting(initialState: state)
        let ui2 = AppDependencies.uiTesting(initialState: state)
        try await ui1.keychain.set(Data([1]), for: .data("Isolation"))
        #expect(try await ui2.keychain.data(for: .data("Isolation")) == nil)
    }

    @Test
    func previewAndUITestingGraphsRejectTestOnlyModel() async {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let preview = AppDependencies.preview(settings: settings)
        let uiTesting = AppDependencies.uiTesting(
            initialState: AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: false,
                isMaintenanceEnabled: false
            )
        )

        await expectUnregisteredTestModel(preview.localDatabase)
        await expectUnregisteredTestModel(uiTesting.localDatabase)
    }

    @Test
    func previewGraphUsesInMemoryStateStorageByDefault() {
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "Preview App",
                    version: "9.8.7"
                )
            )
        )

        #expect(dependencies.appStateStorage is InMemoryAppStateStorage)
    }

    @Test
    func uiTestingGraphUsesFreshInMemoryStateAndFixedAppInfo() throws {
        let initialState = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstDependencies = AppDependencies.uiTesting(initialState: initialState)
        let secondDependencies = AppDependencies.uiTesting(initialState: initialState)
        let firstStorage = try #require(
            firstDependencies.appStateStorage as? InMemoryAppStateStorage
        )
        let secondStorage = try #require(
            secondDependencies.appStateStorage as? InMemoryAppStateStorage
        )

        #expect(firstDependencies.localDatabase is LocalDatabaseService)
        #expect(firstDependencies.remote is RemoteService)
        #expect(firstDependencies.settings.appInfo.displayName == "AppTemplate UI Tests")
        #expect(firstDependencies.settings.appInfo.version == "1.0")
        #expect(try decodedState(from: firstStorage) == initialState)

        try firstStorage.remove()

        #expect(try decodedState(from: secondStorage) == initialState)
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let keychainService = KeychainServiceSpy()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Preview App",
                version: "9.8.7"
            )
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
            appStateStorage: appStateStorage,
            localDatabaseService: localDatabaseService,
            remoteService: remoteService,
            keychainService: keychainService
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )
        let resolvedAppStateStorage = try #require(
            dependencies.appStateStorage as? InjectedAppStateStorage
        )
        let resolvedKeychainService = try #require(
            dependencies.keychain as? KeychainServiceSpy
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        #expect(resolvedAppStateStorage === appStateStorage)
        #expect(resolvedKeychainService === keychainService)
        #expect(dependencies.settings.appInfo.displayName == "Preview App")
        #expect(dependencies.settings.appInfo.version == "9.8.7")
    }

    @Test
    func testGraphKeepsInjectedServices() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let keychainService = KeychainServiceSpy()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Test App",
                version: "3.2.1"
            )
        )
        let dependencies = AppDependencies.test(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService,
            appStateStorage: appStateStorage,
            keychainService: keychainService,
            settings: settings,
            localNotifications: .inMemory()
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )
        let resolvedAppStateStorage = try #require(
            dependencies.appStateStorage as? InjectedAppStateStorage
        )
        let resolvedKeychainService = try #require(
            dependencies.keychain as? KeychainServiceSpy
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        #expect(resolvedAppStateStorage === appStateStorage)
        #expect(resolvedKeychainService === keychainService)
        #expect(dependencies.settings.appInfo.displayName == "Test App")
        #expect(dependencies.settings.appInfo.version == "3.2.1")
    }
}

private func decodedState(from storage: InMemoryAppStateStorage) throws -> AppState {
    let data = try #require({
        if case let .data(data) = try storage.load() {
            return data
        }
        return nil
    }())

    return try JSONDecoder().decode(AppState.self, from: data)
}

private func expectUnregisteredTestModel(
    _ service: any ILocalDatabaseService
) async {
    do {
        _ = try await service.fetch(
            TestLocalRecord.self,
            id: TestLocalRecordID(rawValue: 1)
        )
        Issue.record("Expected LocalDatabaseError.validation")
    } catch let error as LocalDatabaseError {
        guard case let .validation(model, reason) = error else {
            Issue.record("Expected LocalDatabaseError.validation")
            return
        }
        #expect(model == TestLocalRecordAdapter.diagnosticName)
        #expect(reason == .unregisteredModel)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

private actor InjectedLocalDatabaseService: ILocalDatabaseService {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? { nil }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] { [] }

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws {}

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws {}

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool { false }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int { 0 }
}
private actor InjectedRemoteService: IRemoteService {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse {
        ExampleResponse(id: "injected", title: request.query)
    }
}

@MainActor
private final class NotificationCompositionRecorder {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

@MainActor
private final class RecordingUserNotificationCenterAPI: UserNotificationCenterAPI {
    private let recorder: NotificationCompositionRecorder
    private var categories: Set<UNNotificationCategory>
    private(set) var operations: [String] = []
    private(set) var installedCategoryIdentifiers: Set<String> = []

    init(
        recorder: NotificationCompositionRecorder,
        categories: Set<UNNotificationCategory> = []
    ) {
        self.recorder = recorder
        self.categories = categories
    }

    func notificationSettings() async -> UNNotificationSettings {
        fatalError("Construction and bootstrap must not read settings")
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        _ = options
        record("authorization")
        return false
    }

    func notificationCategories() async -> Set<UNNotificationCategory> {
        record("categories.read")
        return categories
    }

    func setNotificationCategories(
        _ categories: Set<UNNotificationCategory>
    ) async {
        self.categories = categories
        installedCategoryIdentifiers = Set(categories.map(\.identifier))
        record("categories.set")
    }

    func add(_ request: UNNotificationRequest) async throws {
        _ = request
        record("add")
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        record("pending")
        return []
    }

    func deliveredNotifications() async -> [UNNotification] {
        record("delivered")
        return []
    }

    func removePendingNotificationRequests(
        withIdentifiers identifiers: [String]
    ) async {
        _ = identifiers
        record("remove.pending")
    }

    func removeDeliveredNotifications(
        withIdentifiers identifiers: [String]
    ) async {
        _ = identifiers
        record("remove.delivered")
    }

    func setBadgeCount(_ count: Int) async throws {
        _ = count
        record("badge")
    }

    private func record(_ operation: String) {
        operations.append(operation)
        recorder.record(operation)
    }
}

@MainActor
private final class WeakNotificationDelegateInstaller {
    weak var delegate: (any UNUserNotificationCenterDelegate)?
    private(set) var installCount = 0

    func install(_ delegate: any UNUserNotificationCenterDelegate) {
        installCount += 1
        self.delegate = delegate
    }
}

@MainActor
private func makeRuntime(
    api: RecordingUserNotificationCenterAPI,
    recorder: NotificationCompositionRecorder
) -> UserNotificationCenterRuntime {
    UserNotificationCenterRuntimeFactory.make(
        makeClient: { UserNotificationCenterClient(api: api) },
        installDelegate: { _ in recorder.record("install") }
    )
}

@MainActor
private final class NotificationSceneReceiver: LocalNotificationSceneReceiving {
    private(set) var urls: [URL] = []
    private var waiters: [CountWaiter] = []

    func receiveLocalNotificationURL(_ url: URL) {
        urls.append(url)
        resumeSatisfiedWaiters()
    }

    func waitForCount(_ count: Int) async {
        guard urls.count < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append(CountWaiter(count: count, continuation: continuation))
        }
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = waiters.filter { $0.count <= urls.count }
        waiters.removeAll { $0.count <= urls.count }
        for waiter in satisfied {
            waiter.continuation.resume()
        }
    }
}

private nonisolated struct CountWaiter: Sendable {
    let count: Int
    let continuation: CheckedContinuation<Void, Never>
}

private actor ControlledNotificationBootstrap {
    private var didEnter = false
    private var didReturn = false
    private var isReleased = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var returnWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async throws {
        didEnter = true
        let waiters = entryWaiters
        entryWaiters.removeAll()
        for waiter in waiters { waiter.resume() }

        if !isReleased {
            await withCheckedContinuation { continuation in
                if isReleased {
                    continuation.resume()
                } else {
                    releaseContinuation = continuation
                }
            }
        }

        didReturn = true
        let returns = returnWaiters
        returnWaiters.removeAll()
        for waiter in returns { waiter.resume() }
    }

    func waitUntilEntered() async {
        guard !didEnter else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func resume() {
        guard !isReleased else { return }
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitUntilReturned() async {
        guard !didReturn else { return }
        await withCheckedContinuation { returnWaiters.append($0) }
    }
}

private nonisolated enum NotificationCompositionTestError: Error {
    case bootstrap
}

nonisolated
private final class InjectedAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    func load() -> AppStateStorageLoadResult { .missing }
    func save(_ data: Data) {}
    func remove() {}
}
