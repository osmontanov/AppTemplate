import Foundation

nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let localDatabaseExamples: any ILocalDatabaseExampleRepository
    let favorites: any IFavoritesRepository
    let cart: any ICartRepository
    let storePreferences: any IStorePreferencesRepository
    let products: any IProductRepository
    let appInfo: any IAppInfoService
    let storeUISupport: StoreUISupport
    let remote: any IRemoteService
    let remoteAPILab: any IRemoteAPILabService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let servicesLabUserDefaults: any IUserDefaultsService
    let servicesLabKeychain: any IKeychainService
    let sessionRepository: SessionRepository
    let clock: AppClock
    let sessionStartupValidationPolicy: SessionStartupValidationPolicy
    let sessionRefreshSchedulePolicy: SessionRefreshSchedulePolicy
    let settings: SettingsDependencies
    let notificationGraph: AppNotificationGraph
    let diagnostics: NetworkDiagnosticRecorder
    let imageLoader: any IImageLoader
    let uiTestScriptTracker: UITestScriptConsumptionTracker?
    let bootstrap: @Sendable () async throws -> Void

    var localNotifications: LocalNotificationDependencies {
        notificationGraph.dependencies
    }

    @MainActor
    static func live(
        localDatabaseStoreLocationResolver:
            LocalDatabaseStoreLocationResolver = .live(),
        userDefaultsService: any IUserDefaultsService = UserDefaultsService(
            namespace: "AppTemplate"
        ),
        keychainService: any IKeychainService = KeychainService(
            service: "AppTemplate"
        ),
        imageLoader: any IImageLoader = ProductImageLoader(),
        notificationGraph: AppNotificationGraph? = nil,
        localNotificationRuntimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> AppDependencies {
        let diagnostics = NetworkDiagnosticRecorder()
        let database = LocalDatabaseService(
            configuration: .live(locationResolver: localDatabaseStoreLocationResolver)
        )
        let remote = RemoteService(diagnosticRecorder: diagnostics)
        let localDatabaseExamples = LocalDatabaseExampleRepository(database: database)
        let remoteAPILab = RemoteAPILabService(remote: remote)
        let clock = AppClock.live
        let appInfo = AppInfoService()
        let resolvedNotificationGraph = notificationGraph ?? .live(
            imageLoader: imageLoader,
            clock: clock,
            runtimeResolver: localNotificationRuntimeResolver
        )
        return AppDependencies(
            localDatabase: database,
            localDatabaseExamples: localDatabaseExamples,
            favorites: FavoritesRepository(database: database),
            cart: CartRepository(database: database),
            storePreferences: StorePreferencesRepository(userDefaults: userDefaultsService),
            products: ProductRepository(remote: remote),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: clock),
            remote: remote,
            remoteAPILab: remoteAPILab,
            appStateStorage: UserDefaultsAppStateStorage(userDefaults: userDefaultsService),
            keychain: keychainService,
            servicesLabUserDefaults: UserDefaultsService(
                namespace: "AppTemplate.ServicesLab",
                userDefaults: .standard
            ),
            servicesLabKeychain: KeychainService(
                service: "AppTemplate.ServicesLab"
            ),
            sessionRepository: SessionRepository(
                remote: remote,
                secureStore: SessionSecureStore(keychain: keychainService),
                clock: clock
            ),
            clock: clock,
            sessionStartupValidationPolicy: .automatic,
            sessionRefreshSchedulePolicy: .automatic,
            settings: SettingsDependencies(appInfo: appInfo),
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: nil,
            bootstrap: {}
        )
    }

    @MainActor
    static func uiTesting(
        scenario: UITestScenario
    ) -> AppDependencies {
        let diagnostics = NetworkDiagnosticRecorder()
        let tracker = UITestScriptConsumptionTracker(
            networkSteps: scenario.remoteSteps.count,
            imageSteps: scenario.imageSeed.steps.count
        )
        let transport = ScriptedNetworkTransport(
            steps: scenario.remoteSteps,
            tracker: tracker
        )
        let fixedInstant = ContinuousClock().now
        let fixedClock = AppClock(
            now: { Date(timeIntervalSince1970: 0) },
            monotonicNow: { fixedInstant },
            sleep: { _ in try Task.checkCancellation() }
        )
        let exampleProvider = NetworkProvider<ExampleTarget>(
            transport: transport,
            clock: fixedClock,
            diagnosticRecorder: diagnostics
        )
        let publicProvider = NetworkProvider<DummyJSONTarget>(
            transport: transport,
            clock: fixedClock,
            diagnosticRecorder: diagnostics
        )
        let authenticationProvider = NetworkProvider<DummyJSONTarget>(
            transport: transport,
            clock: fixedClock,
            diagnosticRecorder: diagnostics
        )
        let remote = RemoteService(
            provider: exampleProvider,
            dummyJSONProvider: publicProvider,
            authenticationProvider: authenticationProvider,
            diagnosticRecorder: diagnostics
        )
        let imageLoader = ScriptedImageLoader(
            steps: scenario.imageSeed.steps,
            tracker: tracker
        )
        let database = LocalDatabaseService(configuration: .inMemory())
        let localDatabaseExamples = LocalDatabaseExampleRepository(database: database)
        let remoteAPILab = RemoteAPILabService(remote: remote)
        let baseCart = CartRepository(database: database)
        let cart: any ICartRepository = scenario.id == .guestStore
            ? UITestConflictOnceCartRepository(base: baseCart)
            : baseCart
        let keychain = InMemoryKeychainService()
        let preferencesService = InMemoryUserDefaultsService(namespace: "AppTemplate")
        let servicesLabUserDefaults = InMemoryUserDefaultsService(
            namespace: "AppTemplate.ServicesLab"
        )
        let servicesLabKeychain = InMemoryKeychainService()
        let storePreferences = StorePreferencesRepository(
            userDefaults: preferencesService
        )
        let notificationGraph = AppNotificationGraph.inMemory(
            settings: LocalNotificationSettings(
                authorizationStatus: scenario.notificationSeed.authorizationStatus,
                alertSetting: .disabled,
                soundSetting: .disabled,
                badgeSetting: .disabled,
                notificationCenterSetting: .disabled,
                lockScreenSetting: .disabled,
                alertStyle: .none,
                previewSetting: .never
            ),
            authorizationResult: [.authorized, .provisional, .ephemeral]
                .contains(scenario.notificationSeed.authorizationStatus),
            imageLoader: imageLoader,
            clock: fixedClock
        )
        let notifications = notificationGraph.dependencies
        let appInfo = AppInfoService(
            displayName: "AppTemplate UI Tests",
            version: "1.0"
        )
        return AppDependencies(
            localDatabase: database,
            localDatabaseExamples: localDatabaseExamples,
            favorites: FavoritesRepository(database: database),
            cart: cart,
            storePreferences: storePreferences,
            products: ProductRepository(remote: remote),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: fixedClock),
            remote: remote,
            remoteAPILab: remoteAPILab,
            appStateStorage: InMemoryAppStateStorage(initialState: scenario.appState),
            keychain: keychain,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            sessionRepository: SessionRepository(
                remote: remote,
                secureStore: SessionSecureStore(keychain: keychain),
                clock: fixedClock
            ),
            clock: fixedClock,
            sessionStartupValidationPolicy: scenario.sessionSeed.validationMode == .scripted
                ? .automatic : .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            settings: SettingsDependencies(appInfo: appInfo),
            notificationGraph: notificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: tracker,
            bootstrap: {
                if let data = scenario.sessionSeed.keychainData {
                    try await keychain.set(data, for: .data("Store.AuthSession"))
                }
                try scenario.preferencesSeed.apply(to: preferencesService)
                try await database.upsert(scenario.localDatabaseSeed.examples)
                try await database.upsert(scenario.localDatabaseSeed.favorites)
                if let cart = scenario.localDatabaseSeed.cart {
                    try await database.upsert(cart)
                }
                try await notifications.bootstrapCategoriesIfNeeded()
                for request in scenario.notificationSeed.pendingRequests {
                    try await notifications.service.schedule(request)
                }
            }
        )
    }

    @MainActor
    static func uiTesting(
        initialState: AppState,
        remoteService: any IRemoteService,
        diagnostics: NetworkDiagnosticRecorder,
        imageLoader: any IImageLoader,
        notificationGraph: AppNotificationGraph? = nil
    ) -> AppDependencies {
        let database = LocalDatabaseService(configuration: .inMemory())
        let localDatabaseExamples = LocalDatabaseExampleRepository(database: database)
        let remoteAPILab = RemoteAPILabService(remote: remoteService)
        let keychain = InMemoryKeychainService()
        let servicesLabUserDefaults = InMemoryUserDefaultsService(
            namespace: "AppTemplate.ServicesLab"
        )
        let servicesLabKeychain = InMemoryKeychainService()
        let clock = AppClock.live
        let appInfo = AppInfoService(
            displayName: "AppTemplate UI Tests",
            version: "1.0"
        )
        let resolvedNotificationGraph = notificationGraph ?? .inMemory(
            imageLoader: imageLoader,
            clock: clock
        )
        return AppDependencies(
            localDatabase: database,
            localDatabaseExamples: localDatabaseExamples,
            favorites: FavoritesRepository(database: database),
            cart: CartRepository(database: database),
            storePreferences: StorePreferencesRepository(userDefaults: InMemoryUserDefaultsService(
                namespace: "AppTemplate"
            )),
            products: ProductRepository(remote: remoteService),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: clock),
            remote: remoteService,
            remoteAPILab: remoteAPILab,
            appStateStorage: InMemoryAppStateStorage(initialState: initialState),
            keychain: keychain,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            sessionRepository: SessionRepository(
                remote: remoteService,
                secureStore: SessionSecureStore(keychain: keychain),
                clock: clock
            ),
            clock: clock,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            settings: SettingsDependencies(appInfo: appInfo),
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: nil,
            bootstrap: {}
        )
    }

    @MainActor
    static func preview(
        settings: SettingsDependencies,
        remoteService: any IRemoteService,
        diagnostics: NetworkDiagnosticRecorder,
        imageLoader: any IImageLoader,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        storePreferencesService: any IUserDefaultsService = InMemoryUserDefaultsService(
            namespace: "AppTemplate"
        ),
        keychainService: any IKeychainService = InMemoryKeychainService(),
        notificationGraph: AppNotificationGraph? = nil
    ) -> AppDependencies {
        let clock = AppClock.live
        let appInfo = settings.appInfo
        let servicesLabUserDefaults = InMemoryUserDefaultsService(
            namespace: "AppTemplate.ServicesLab"
        )
        let servicesLabKeychain = InMemoryKeychainService()
        let resolvedNotificationGraph = notificationGraph ?? .inMemory(
            imageLoader: imageLoader,
            clock: clock
        )
        let localDatabaseExamples = LocalDatabaseExampleRepository(
            database: localDatabaseService
        )
        let remoteAPILab = RemoteAPILabService(remote: remoteService)
        return AppDependencies(
            localDatabase: localDatabaseService,
            localDatabaseExamples: localDatabaseExamples,
            favorites: FavoritesRepository(database: localDatabaseService),
            cart: CartRepository(database: localDatabaseService),
            storePreferences: StorePreferencesRepository(userDefaults: storePreferencesService),
            products: ProductRepository(remote: remoteService),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: clock),
            remote: remoteService,
            remoteAPILab: remoteAPILab,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            sessionRepository: SessionRepository(
                remote: remoteService,
                secureStore: SessionSecureStore(keychain: keychainService),
                clock: clock
            ),
            clock: clock,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            settings: settings,
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: nil,
            bootstrap: {}
        )
    }

    @MainActor
    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
        diagnostics: NetworkDiagnosticRecorder,
        imageLoader: any IImageLoader,
        appStateStorage: any IAppStateStorage,
        keychainService: any IKeychainService,
        settings: SettingsDependencies,
        notificationGraph: AppNotificationGraph,
        storePreferencesService: any IUserDefaultsService = InMemoryUserDefaultsService(
            namespace: "AppTemplate"
        )
    ) -> AppDependencies {
        let clock = AppClock.live
        let appInfo = settings.appInfo
        let servicesLabUserDefaults = InMemoryUserDefaultsService(
            namespace: "AppTemplate.ServicesLab"
        )
        let servicesLabKeychain = InMemoryKeychainService()
        let localDatabaseExamples = LocalDatabaseExampleRepository(
            database: localDatabaseService
        )
        let remoteAPILab = RemoteAPILabService(remote: remoteService)
        return AppDependencies(
            localDatabase: localDatabaseService,
            localDatabaseExamples: localDatabaseExamples,
            favorites: FavoritesRepository(database: localDatabaseService),
            cart: CartRepository(database: localDatabaseService),
            storePreferences: StorePreferencesRepository(userDefaults: storePreferencesService),
            products: ProductRepository(remote: remoteService),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: clock),
            remote: remoteService,
            remoteAPILab: remoteAPILab,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            sessionRepository: SessionRepository(
                remote: remoteService,
                secureStore: SessionSecureStore(keychain: keychainService),
                clock: clock
            ),
            clock: clock,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            settings: settings,
            notificationGraph: notificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: nil,
            bootstrap: {}
        )
    }

    @MainActor
    func makeStoreDependencies(
        session: any ISessionActions
    ) -> StoreDependencies {
        StoreDependencies(
            products: products,
            session: session,
            favorites: favorites,
            cart: cart,
            preferences: storePreferences,
            reminders: notificationGraph.reminders,
            appInfo: appInfo
        )
    }

    @MainActor
    func makeServicesDependencies(
        appState: any IAppStateInspecting,
        appFlowCoordinator: any IAppFlowCoordinator,
        sessionActions: any ISessionActions,
        appStateStatus: ServicesAppStateStatus
    ) -> ServicesDependencies {
        ServicesDependencies(
            appState: appState,
            appFlowCoordinator: appFlowCoordinator,
            appStateStatus: appStateStatus,
            sessionActions: sessionActions,
            appInfo: appInfo,
            userDefaultsLab: servicesLabUserDefaults,
            keychainLab: servicesLabKeychain,
            localDatabase: localDatabaseExamples,
            remoteAPI: remoteAPILab,
            diagnostics: diagnostics
        )
    }
}

nonisolated
struct FailClosedImageLoader: IImageLoader {
    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        _ = url
        _ = policy
        throw ImageLoaderError.transport
    }
}

actor FailClosedRemoteService: IRemoteService {
    func fetchExample(_ request: ExampleRequest) async throws -> ExampleResponse {
        _ = request
        throw RemoteServiceError.invalidResponse
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
