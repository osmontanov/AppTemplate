import Foundation
import Synchronization
import SwiftUI
import Testing
import UserNotifications
@testable import AppTemplate

@MainActor
struct AppDependenciesTests {
    @Test
    func scenarioGraphsAreFreshAndTheirEmptyTransportsFailClosed() async throws {
        let scenario = try UITestScenario.named("services-basic")
        let first = AppDependencies.uiTesting(scenario: scenario)
        let second = AppDependencies.uiTesting(scenario: scenario)

        #expect(first.remote as AnyObject !== second.remote as AnyObject)
        #expect(first.imageLoader as AnyObject !== second.imageLoader as AnyObject)
        #expect(first.appStateStorage as AnyObject !== second.appStateStorage as AnyObject)
        #expect(first.sessionRepository !== second.sessionRepository)
        #expect(first.sessionStartupValidationPolicy == .disabled)
        #expect(first.sessionRefreshSchedulePolicy == .disabled)
        #expect(first.keychain as AnyObject !== second.keychain as AnyObject)
        #expect(first.localDatabase as AnyObject !== second.localDatabase as AnyObject)
        #expect(first.diagnostics !== second.diagnostics)
        #expect(first.uiTestScriptTracker !== second.uiTestScriptTracker)
        #expect(first.imageLoader is ScriptedImageLoader)
        #expect(
            first.localNotifications.categoryCatalog as AnyObject
                !== second.localNotifications.categoryCatalog as AnyObject
        )

        await #expect(throws: ScriptedImageLoaderError.unexpectedURL) {
            _ = try await first.imageLoader.load(
                URL(string: "https://cdn.dummyjson.com/unplanned.png")!,
                policy: .product
            )
        }
        await #expect(throws: RemoteServiceError.self) {
            _ = try await first.remote.categories()
        }
    }

    @Test
    func appDependencyFactoriesKeepExactInjectedImageLoaderWithoutLoading() throws {
        let imageLoader = InjectedImageLoader()
        let preview = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(displayName: "Preview", version: "1")
            ),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: imageLoader
        )
        let live = AppDependencies.live(
            imageLoader: imageLoader,
            notificationGraph: .inMemory()
        )

        let resolvedPreview = try #require(preview.imageLoader as? InjectedImageLoader)
        let resolvedLive = try #require(live.imageLoader as? InjectedImageLoader)
        #expect(resolvedPreview === imageLoader)
        #expect(resolvedLive === imageLoader)
        #expect(imageLoader.loadCount == 0)
    }

    @Test
    func nonLiveFactoriesRequireAndKeepFreshImageLoaders() throws {
        let state = AppState(
            hasCompletedOnboarding: false,
            isMaintenanceEnabled: false
        )
        let firstLoader = InjectedImageLoader()
        let secondLoader = InjectedImageLoader()
        let first = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: firstLoader
        )
        let second = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: secondLoader
        )

        #expect(first.imageLoader as AnyObject === firstLoader)
        #expect(second.imageLoader as AnyObject === secondLoader)
        #expect(first.imageLoader as AnyObject !== second.imageLoader as AnyObject)
        #expect(firstLoader.loadCount == 0)
        #expect(secondLoader.loadCount == 0)
    }

    @MainActor
    @Test
    func previewGraphsUseFreshInMemoryNotifications() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let first = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let second = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )

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

        let dependencies = AppNotificationGraph.live(
            imageLoader: FailClosedImageLoader(),
            clock: .live,
            runtimeResolver: {
                recorder.record("resolve")
                return runtime
            }
        ).dependencies

        #expect(recorder.values == ["resolve", "install"])
        #expect(api.operations.isEmpty)

        try await dependencies.bootstrapCategoriesIfNeeded()
        try await dependencies.bootstrapCategoriesIfNeeded()

        #expect(recorder.values == ["resolve", "install", "categories.read", "categories.set"])
        #expect(api.operations == ["categories.read", "categories.set"])
        #expect(
            api.installedCategoryIdentifiers == [
                try LocalNotificationNamespace().physicalCategoryID(
                    AppNotificationIdentifiers.storeCategory
                )
            ]
        )
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
        let dependencies = AppNotificationGraph.live(
            imageLoader: FailClosedImageLoader(),
            clock: .live,
            runtimeResolver: { runtime }
        ).dependencies

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await dependencies.bootstrapCategoriesIfNeeded()
                }
            }
            try await group.waitForAll()
        }

        #expect(api.operations == ["categories.read", "categories.set"])
        #expect(
            api.installedCategoryIdentifiers == [
                "Foreign.category",
                try LocalNotificationNamespace().physicalCategoryID(
                    AppNotificationIdentifiers.storeCategory
                )
            ]
        )
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
        var graph: AppNotificationGraph? = .live(
            imageLoader: FailClosedImageLoader(),
            clock: .live,
            runtimeResolver: { runtime }
        )

        #expect(weakInstaller.installCount == 1)
        #expect(weakInstaller.delegate != nil)

        graph = nil

        #expect(graph == nil)
        #expect(weakInstaller.delegate == nil)
    }

    @Test
    func previewUITestAndInMemoryFactoriesNeverResolveLiveRuntime() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let state = AppState(
            hasCompletedOnboarding: false,
            isMaintenanceEnabled: false
        )
        let preview = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let uiTest = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let direct = AppNotificationGraph.inMemory().dependencies

        #expect(preview.localNotifications.service is InMemoryLocalNotificationService)
        #expect(uiTest.localNotifications.service is InMemoryLocalNotificationService)
        #expect(direct.service is InMemoryLocalNotificationService)
        #expect(
            preview.localNotifications.categoryCatalog as AnyObject
                !== uiTest.localNotifications.categoryCatalog as AnyObject
        )
        let directCopy = direct
        #expect(
            direct.categoryCatalog as AnyObject
                === directCopy.categoryCatalog as AnyObject
        )
        try await preview.localNotifications.bootstrapCategoriesIfNeeded()
        try await uiTest.localNotifications.bootstrapCategoriesIfNeeded()
        try await direct.bootstrapCategoriesIfNeeded()
        let expected = [StoreProductNotificationCategory.make()]
        #expect(
            await (preview.localNotifications.service as? InMemoryLocalNotificationService)?
                .registeredCategoriesForTesting() == expected
        )
        #expect(
            await (uiTest.localNotifications.service as? InMemoryLocalNotificationService)?
                .registeredCategoriesForTesting() == expected
        )
        #expect(
            await (direct.service as? InMemoryLocalNotificationService)?
                .registeredCategoriesForTesting() == expected
        )
    }

    @Test
    func pluralLabReplacementBuildsAValidatedSchedulableInMemoryCatalog() async throws {
        let category = try LocalNotificationFixtures.category(id: "configured")
        let graph = AppNotificationGraph.inMemory().dependencies
        let request = LocalNotificationRequest(
            id: try LocalNotificationID("request"),
            content: LocalNotificationContent(
                body: "Body",
                categoryID: category.id
            ),
            trigger: .immediate
        )

        try await graph.categoryCatalog.replaceLabCategories([category])
        try await graph.service.schedule(request)

        #expect(
            await graph.categoryCatalog.categories()
                == [StoreProductNotificationCategory.make(), category]
        )
        #expect(await graph.service.pending().map(\.id) == [request.id])
    }

    @Test
    func scenarioBootstrapRegistersStoreCategoryBeforeSeedingPendingRequests() async throws {
        let request = LocalNotificationRequest(
            id: try LocalNotificationID("seeded-store-request"),
            content: LocalNotificationContent(
                body: "Body",
                categoryID: AppNotificationIdentifiers.storeCategory
            ),
            trigger: .immediate
        )
        let scenario = UITestScenario(
            id: .servicesBasic,
            appState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(examples: []),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [:]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .authorized,
                pendingRequests: [request]
            ),
            imageSeed: UITestImageSeed(steps: []),
            networkPolicy: .failClosed,
            remoteSteps: []
        )
        let dependencies = AppDependencies.uiTesting(scenario: scenario)

        try await dependencies.bootstrap()

        #expect(
            await dependencies.localNotifications.service.pending().map(\.id)
                == [request.id]
        )
        #expect(
            await dependencies.localNotifications.categoryCatalog.categories()
                == [StoreProductNotificationCategory.make()]
        )
    }

    @Test
    func notificationBootstrapRoutesOnlyThroughTheInjectedCategoryCatalog() async throws {
        let base = AppNotificationGraph.inMemory().dependencies
        let catalog = NotificationCategoryCatalogRoutingSpy()
        let graph = LocalNotificationDependencies(
            service: base.service,
            categoryCatalog: catalog,
            eventHub: base.eventHub,
            eventHistory: base.eventHistory,
            navigationCoordinator: base.navigationCoordinator,
            delegateBridge: nil
        )

        try await graph.bootstrapCategoriesIfNeeded()

        #expect(await catalog.bootstrapCallCount == 1)
        #expect(
            await (base.service as? InMemoryLocalNotificationService)?
                .registeredCategoriesForTesting().isEmpty == true
        )
    }

    @Test
    func appDependencyFactoriesKeepTheExactInjectedNotificationGraph() throws {
        let notifications = AppNotificationGraph.inMemory()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Injected", version: "1")
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader(),
            notificationGraph: notifications
        )

        #expect(
            dependencies.localNotifications.service as AnyObject
                === notifications.dependencies.service as AnyObject
        )
        #expect(
            dependencies.localNotifications.eventHub
                === notifications.dependencies.eventHub
        )
        #expect(
            dependencies.localNotifications.navigationCoordinator
                === notifications.dependencies.navigationCoordinator
        )
        #expect(
            dependencies.localNotifications.categoryCatalog as AnyObject
                === notifications.dependencies.categoryCatalog as AnyObject
        )
    }


    @Test(.timeLimit(.minutes(1)))
    func sceneEligibilityDoesNotWaitForCategoryBootstrap() async throws {
        let dependencies = AppNotificationGraph.inMemory().dependencies
        let registration = LocalNotificationSceneRegistration(
            coordinator: dependencies.navigationCoordinator
        )
        let receiver = NotificationSceneReceiver()
        let bootstrap = ControlledNotificationBootstrap()
        registration.setNavigationState(
            isRestored: true,
            isMain: true,
            isReady: true
        )
        registration.setPlatformEligible(true)
        let runTask = Task {
            await registration.run(
                receiver: receiver,
                bootstrap: { try await bootstrap.wait() }
            )
        }
        await bootstrap.waitUntilEntered()

        await dependencies.navigationCoordinator.deliver(
            .navigate(.openProduct(7))
        )
        await receiver.waitForCount(1)
        #expect(receiver.commands == [.navigate(.openProduct(7))])

        runTask.cancel()
        await bootstrap.resume()
        await runTask.value
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
            notificationGraph: .inMemory()
        )
        let remote = dependencies.remote as? RemoteService

        #expect(dependencies.localDatabase is LocalDatabaseService)
        #expect(dependencies.remote is RemoteService)
        #expect(remote?.diagnosticRecorder === dependencies.diagnostics)
        #expect(dependencies.appStateStorage is UserDefaultsAppStateStorage)
        #expect(dependencies.keychain is KeychainService)
        #expect(dependencies.settings.appInfo is AppInfoService)
        #expect(dependencies.imageLoader is ProductImageLoader)
    }

    @Test
    func liveGraphRetainsInjectedKeychainExactlyWithoutEagerAccess() async throws {
        let injected = KeychainServiceSpy()
        let dependencies = AppDependencies.live(
            keychainService: injected,
            notificationGraph: .inMemory()
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
            notificationGraph: .inMemory()
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
            notificationGraph: .inMemory()
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
        let firstPreview = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let secondPreview = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
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
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstUI = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let secondUI = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
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
        let preview1 = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let preview2 = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        try await preview1.keychain.set(Data([1]), for: .data("Isolation"))
        #expect(try await preview2.keychain.data(for: .data("Isolation")) == nil)

        let state = AppState(
            hasCompletedOnboarding: false,
            isMaintenanceEnabled: false
        )
        let ui1 = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let ui2 = AppDependencies.uiTesting(
            initialState: state,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        try await ui1.keychain.set(Data([1]), for: .data("Isolation"))
        #expect(try await ui2.keychain.data(for: .data("Isolation")) == nil)
    }

    @Test
    func previewAndUITestingGraphsRejectTestOnlyModel() async {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let preview = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let uiTesting = AppDependencies.uiTesting(
            initialState: AppState(
                hasCompletedOnboarding: false,
                isMaintenanceEnabled: false
            ),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
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
            ),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )

        #expect(dependencies.appStateStorage is InMemoryAppStateStorage)
    }

    @Test
    func uiTestingGraphUsesFreshInMemoryStateAndFixedAppInfo() throws {
        let initialState = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstDependencies = AppDependencies.uiTesting(
            initialState: initialState,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let secondDependencies = AppDependencies.uiTesting(
            initialState: initialState,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let firstStorage = try #require(
            firstDependencies.appStateStorage as? InMemoryAppStateStorage
        )
        let secondStorage = try #require(
            secondDependencies.appStateStorage as? InMemoryAppStateStorage
        )

        #expect(firstDependencies.localDatabase is LocalDatabaseService)
        #expect(firstDependencies.remote is InjectedRemoteService)
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
        let imageLoader = InjectedImageLoader()
        let diagnostics = NetworkDiagnosticRecorder()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Preview App",
                version: "9.8.7"
            )
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
            remoteService: remoteService,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            appStateStorage: appStateStorage,
            localDatabaseService: localDatabaseService,
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
        #expect(dependencies.imageLoader as AnyObject === imageLoader)
        #expect(dependencies.diagnostics === diagnostics)
        #expect(dependencies.settings.appInfo.displayName == "Preview App")
        #expect(dependencies.settings.appInfo.version == "9.8.7")
    }

    @Test
    func testGraphKeepsInjectedServices() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let keychainService = KeychainServiceSpy()
        let imageLoader = InjectedImageLoader()
        let diagnostics = NetworkDiagnosticRecorder()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Test App",
                version: "3.2.1"
            )
        )
        let dependencies = AppDependencies.test(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            appStateStorage: appStateStorage,
            keychainService: keychainService,
            settings: settings,
            notificationGraph: .inMemory()
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
        #expect(dependencies.imageLoader as AnyObject === imageLoader)
        #expect(dependencies.diagnostics === diagnostics)
        #expect(dependencies.settings.appInfo.displayName == "Test App")
        #expect(dependencies.settings.appInfo.version == "3.2.1")
    }

    @Test
    func graphRetainsOneIdentityForEveryStoreRepository() {
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(displayName: "Preview", version: "1")
            ),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )

        #expect(dependencies.favorites as AnyObject === dependencies.favorites as AnyObject)
        #expect(dependencies.cart as AnyObject === dependencies.cart as AnyObject)
        #expect(dependencies.storePreferences as AnyObject === dependencies.storePreferences as AnyObject)
    }

    @Test
    func storeFactoryReusesInjectedSessionProductsCartPreferencesAppInfoAndUISupport() async {
        let remote = InjectedRemoteService()
        let imageLoader = InjectedImageLoader()
        let appInfo = AppInfoService(displayName: "Shared", version: "4.2")
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(appInfo: appInfo),
            remoteService: remote,
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: imageLoader
        )

        let session = CompositionSessionActionsSpy()
        let first = dependencies.makeStoreDependencies(session: session)
        let second = dependencies.makeStoreDependencies(session: session)

        #expect(first.session as AnyObject === session)
        #expect(second.session as AnyObject === session)
        #expect(first.products as AnyObject === dependencies.products as AnyObject)
        #expect(first.products as AnyObject === second.products as AnyObject)
        #expect(first.favorites as AnyObject === dependencies.favorites as AnyObject)
        #expect(first.favorites as AnyObject === second.favorites as AnyObject)
        #expect(first.cart as AnyObject === dependencies.cart as AnyObject)
        #expect(first.preferences as AnyObject === dependencies.storePreferences as AnyObject)
        #expect(first.appInfo as AnyObject === dependencies.appInfo as AnyObject)
        #expect(first.appInfo as AnyObject === dependencies.settings.appInfo as AnyObject)
        #expect(dependencies.storeUISupport.images as AnyObject === imageLoader)

        _ = await first.session.login(username: "emilys", password: "emilyspass")
        #expect(session.loginCalls == 1)
    }

    @Test
    func productRepositoryUsesTheExactGraphRemoteWithoutEagerTransport() async {
        let remote = InjectedRemoteService()
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(displayName: "Preview", version: "1")
            ),
            remoteService: remote,
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )

        await #expect(throws: RemoteServiceError.self) {
            _ = try await dependencies.products.categories()
        }
    }

    @Test
    func previewStoreRepositoriesAreGraphLocalAndShareTheirGraphDatabase() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let first = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let second = AppDependencies.preview(
            settings: settings,
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let product = ProductSnapshot(
            id: 41,
            title: "Graph-local",
            price: 1,
            thumbnailURL: nil
        )

        #expect(try await first.favorites.ensureFavorite(product, userID: 7))
        #expect(try await first.cart.add(product, quantity: 1).revision == 1)
        try await first.storePreferences.setLayout(.list)

        #expect(try await first.localDatabase.fetch(
            FavoriteProductSnapshot.self,
            id: "user:7|product:41"
        ) != nil)
        #expect(!(try await second.favorites.contains(userID: 7, productID: 41)))
        #expect(try await second.cart.cart().revision == 0)
        #expect(await second.storePreferences.current() == .defaults)
    }

}

@MainActor
struct ServicesDependenciesCompositionTests {
    @Test
    func factoryPackagesExactOwnersWithoutEagerWorkAndSharesAppInfoCalls() {
        let appInfo = CountingAppInfoService(
            displayName: "Shared App",
            version: "8.4"
        )
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(appInfo: appInfo),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let store = AppStateStore(storage: InMemoryAppStateStorage())
        let router = AppFlowRouter(flow: .main)
        let inspector = CountingAppStateInspector(
            base: AppStateInspector(store: store, router: router)
        )
        let coordinator = AppFlowCoordinatorSpy()
        let session = CompositionSessionActionsSpy()
        let status = ServicesAppStateStatus()

        let services = dependencies.makeServicesDependencies(
            appState: inspector,
            appFlowCoordinator: coordinator,
            sessionActions: session,
            appStateStatus: status
        )

        #expect(inspector.readCount == 0)
        #expect(session.statusReadCount == 0)
        #expect(coordinator.commands.isEmpty)
        #expect(services.appState as AnyObject === inspector)
        #expect(services.appFlowCoordinator as AnyObject === coordinator)
        #expect(services.sessionActions as AnyObject === session)
        #expect(services.appStateStatus === status)

        let storeSlice = dependencies.makeStoreDependencies(session: session)
        let servicesModel = ServicesAppInfoViewModel(
            appInfo: services.appInfo,
            platformName: "Tests"
        )
        #expect(storeSlice.appInfo.displayName == "Shared App")
        #expect(dependencies.settings.appInfo.version == "8.4")
        #expect(servicesModel.displayName == "Shared App")
        #expect(servicesModel.version == "8.4")
        #expect(appInfo.displayNameReads == 2)
        #expect(appInfo.versionReads == 2)
    }
}

@MainActor
struct AppDependenciesTask3Tests {
    @Test
    func storeFactoryUsesTheExactAppScopedFavoritesActor() {
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(displayName: "Task 3", version: "1")
            ),
            remoteService: InjectedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: InjectedImageLoader()
        )
        let session = CompositionSessionActionsSpy()

        let first = dependencies.makeStoreDependencies(session: session)
        let second = dependencies.makeStoreDependencies(session: session)

        #expect(first.favorites as AnyObject === dependencies.favorites as AnyObject)
        #expect(first.favorites as AnyObject === second.favorites as AnyObject)
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

@MainActor
private final class CompositionSessionActionsSpy: ISessionActions {
    private var storedStatus = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    private(set) var statusReadCount = 0
    var status: SessionStatusPresentation {
        statusReadCount += 1
        return storedStatus
    }
    var presentation: SessionPresentation { status.session }
    private(set) var loginCalls = 0

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        _ = username
        _ = password
        loginCalls += 1
        return .cancelled
    }
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        _ = token
        return .invalidToken
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        _ = token
    }
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}

@MainActor
private final class CountingAppStateInspector: IAppStateInspecting {
    private let base: any IAppStateInspecting
    private(set) var readCount = 0

    init(base: any IAppStateInspecting) {
        self.base = base
    }

    var inspection: AppStateInspection {
        readCount += 1
        return base.inspection
    }
}

nonisolated
private final class CountingAppInfoService:
    IAppInfoService,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let storedDisplayName: String
    private let storedVersion: String
    private var displayNameReadCount = 0
    private var versionReadCount = 0

    init(displayName: String, version: String) {
        storedDisplayName = displayName
        storedVersion = version
    }

    var displayName: String {
        lock.withLock {
            displayNameReadCount += 1
            return storedDisplayName
        }
    }

    var version: String {
        lock.withLock {
            versionReadCount += 1
            return storedVersion
        }
    }

    var displayNameReads: Int {
        lock.withLock { displayNameReadCount }
    }

    var versionReads: Int {
        lock.withLock { versionReadCount }
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

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        _ = request
        throw RemoteServiceError.invalidResponse
    }

    func categories() async throws -> [ProductCategoryDTO] {
        throw RemoteServiceError.invalidResponse
    }

    func product(id: Int) async throws -> ProductDTO {
        _ = id
        throw RemoteServiceError.invalidResponse
    }

    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO {
        _ = request
        throw RemoteServiceError.invalidResponse
    }

    func me(accessToken: String) async throws -> UserProfileDTO {
        _ = accessToken
        throw RemoteServiceError.invalidResponse
    }

    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO {
        _ = request
        throw RemoteServiceError.invalidResponse
    }

    func diagnostic(
        _ request: HTTPDiagnosticRequest
    ) async throws -> HTTPDiagnosticDTO {
        _ = request
        throw RemoteServiceError.invalidResponse
    }
}

nonisolated
private final class InjectedImageLoader: IImageLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var storedLoadCount = 0

    var loadCount: Int { lock.withLock { storedLoadCount } }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        _ = url
        _ = policy
        lock.withLock { storedLoadCount += 1 }
        throw ImageLoaderError.transport
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
    private(set) var commands: [NotificationNavigationCommand] = []
    private var waiters: [CountWaiter] = []

    func receiveNotificationCommand(_ command: NotificationNavigationCommand) async {
        commands.append(command)
        resumeSatisfiedWaiters()
    }

    func waitForCount(_ count: Int) async {
        guard commands.count < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append(CountWaiter(count: count, continuation: continuation))
        }
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = waiters.filter { $0.count <= commands.count }
        waiters.removeAll { $0.count <= commands.count }
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

private actor NotificationCategoryCatalogRoutingSpy:
    IAppNotificationCategoryCatalog
{
    private(set) var bootstrapCallCount = 0

    func categories() async -> [LocalNotificationCategory] { [] }

    func bootstrapIfNeeded() async throws {
        bootstrapCallCount += 1
    }

    func replaceLabCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        _ = categories
    }

    func resetLabCategories() async throws {}
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
