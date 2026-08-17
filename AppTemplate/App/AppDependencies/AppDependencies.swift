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
    let notificationGraph: AppNotificationGraph
    let diagnostics: NetworkDiagnosticRecorder
    let imageLoader: any IImageLoader
    let uiTestScriptTracker: UITestScriptConsumptionTracker?
    let uiTestNotificationLabSteps: [UITestNotificationLabStep]?
    let bootstrap: @Sendable () async throws -> Void

    var localNotifications: LocalNotificationDependencies {
        notificationGraph.dependencies
    }

    // Every factory routes through here, so the repositories derived from a
    // database/remote/clock are constructed once. Inputs stay explicit: adding a
    // stored property breaks this call and every factory that must supply it.
    @MainActor
    private static func compose(
        database: any ILocalDatabaseService,
        remote: any IRemoteService,
        imageLoader: any IImageLoader,
        clock: AppClock,
        keychain: any IKeychainService,
        storePreferencesService: any IUserDefaultsService,
        appStateStorage: any IAppStateStorage,
        appInfo: any IAppInfoService,
        servicesLabUserDefaults: any IUserDefaultsService,
        servicesLabKeychain: any IKeychainService,
        notificationGraph: AppNotificationGraph,
        diagnostics: NetworkDiagnosticRecorder,
        sessionStartupValidationPolicy: SessionStartupValidationPolicy,
        sessionRefreshSchedulePolicy: SessionRefreshSchedulePolicy,
        cart: (any ICartRepository)? = nil,
        uiTestScriptTracker: UITestScriptConsumptionTracker? = nil,
        uiTestNotificationLabSteps: [UITestNotificationLabStep]? = nil,
        bootstrap: @escaping @Sendable () async throws -> Void = {}
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: database,
            localDatabaseExamples: LocalDatabaseExampleRepository(database: database),
            favorites: FavoritesRepository(database: database),
            cart: cart ?? CartRepository(database: database),
            storePreferences: StorePreferencesRepository(
                userDefaults: storePreferencesService
            ),
            products: ProductRepository(remote: remote),
            appInfo: appInfo,
            storeUISupport: StoreUISupport(images: imageLoader, clock: clock),
            remote: remote,
            remoteAPILab: RemoteAPILabService(remote: remote),
            appStateStorage: appStateStorage,
            keychain: keychain,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            sessionRepository: SessionRepository(
                remote: remote,
                secureStore: SessionSecureStore(keychain: keychain),
                clock: clock
            ),
            clock: clock,
            sessionStartupValidationPolicy: sessionStartupValidationPolicy,
            sessionRefreshSchedulePolicy: sessionRefreshSchedulePolicy,
            notificationGraph: notificationGraph,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: uiTestScriptTracker,
            uiTestNotificationLabSteps: uiTestNotificationLabSteps,
            bootstrap: bootstrap
        )
    }

    @MainActor
    static func live(
        localDatabaseService: (any ILocalDatabaseService)? = nil,
        localDatabaseStoreLocationResolver:
            LocalDatabaseStoreLocationResolver? = nil,
        userDefaultsService: any IUserDefaultsService = UserDefaultsService(
            namespace: AppNamespace.primary
        ),
        keychainService: any IKeychainService = KeychainService(
            service: AppNamespace.primary
        ),
        servicesLabUserDefaultsService: (any IUserDefaultsService)? = nil,
        servicesLabKeychainService: (any IKeychainService)? = nil,
        remoteService: (any IRemoteService)? = nil,
        appInfoService: any IAppInfoService = AppInfoService(),
        imageLoader: any IImageLoader = CachingImageLoader(),
        clock: AppClock? = nil,
        sessionStartupValidationPolicy: SessionStartupValidationPolicy = .automatic,
        sessionRefreshSchedulePolicy: SessionRefreshSchedulePolicy = .automatic,
        notificationGraph: AppNotificationGraph? = nil,
        localNotificationRuntimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> AppDependencies {
        let diagnostics = NetworkDiagnosticRecorder()
        let database: any ILocalDatabaseService = localDatabaseService
            ?? LocalDatabaseService(configuration: .live(
                locationResolver: localDatabaseStoreLocationResolver ?? .live()
            ))
        let remote: any IRemoteService = remoteService
            ?? RemoteService(diagnosticRecorder: diagnostics)
        let resolvedClock = clock ?? .live
        let resolvedNotificationGraph = notificationGraph ?? .live(
            imageLoader: imageLoader,
            clock: resolvedClock,
            runtimeResolver: localNotificationRuntimeResolver
        )
        return compose(
            database: database,
            remote: remote,
            imageLoader: imageLoader,
            clock: resolvedClock,
            keychain: keychainService,
            storePreferencesService: userDefaultsService,
            appStateStorage: UserDefaultsAppStateStorage(
                userDefaults: userDefaultsService
            ),
            appInfo: appInfoService,
            servicesLabUserDefaults: servicesLabUserDefaultsService
                ?? UserDefaultsService(
                    namespace: AppNamespace.servicesLab,
                    userDefaults: .standard
                ),
            servicesLabKeychain: servicesLabKeychainService
                ?? KeychainService(service: AppNamespace.servicesLab),
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            sessionStartupValidationPolicy: sessionStartupValidationPolicy,
            sessionRefreshSchedulePolicy: sessionRefreshSchedulePolicy
        )
    }

    @MainActor
    static func uiTesting(
        scenario: UITestScenario
    ) -> AppDependencies {
        let diagnostics = NetworkDiagnosticRecorder()
        let tracker = UITestScriptConsumptionTracker(
            networkSteps: scenario.remoteSteps.count,
            imageSteps: scenario.imageSeed.steps.count,
            notificationSteps: scenario.notificationSeed.labSteps.count
        )
        let transport = ScriptedNetworkTransport(
            steps: scenario.remoteSteps,
            tracker: tracker
        )
        let fixedInstant = ContinuousClock().now
        let fixedClock = AppClock(
            now: { Date(timeIntervalSince1970: 0) },
            monotonicNow: { fixedInstant },
            sleep: { try await Task.sleep(for: $0) }
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
            dummyJSONProvider: publicProvider,
            authenticationProvider: authenticationProvider,
            diagnosticRecorder: diagnostics
        )
        let imageLoader = ScriptedImageLoader(
            steps: scenario.imageSeed.steps,
            tracker: tracker
        )
        let database = LocalDatabaseService(configuration: .inMemory())
        let baseCart = CartRepository(database: database)
        let cart: any ICartRepository = scenario.id == .guestStore
            ? UITestConflictOnceCartRepository(base: baseCart)
            : baseCart
        let keychain = InMemoryKeychainService()
        let preferencesService = InMemoryUserDefaultsService(
            namespace: AppNamespace.primary
        )
        let servicesLabUserDefaults = InMemoryUserDefaultsService(
            namespace: AppNamespace.servicesLab
        )
        let servicesLabKeychain = InMemoryKeychainService()
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
        return compose(
            database: database,
            remote: remote,
            imageLoader: imageLoader,
            clock: fixedClock,
            keychain: keychain,
            storePreferencesService: preferencesService,
            appStateStorage: InMemoryAppStateStorage(initialState: scenario.appState),
            appInfo: appInfo,
            servicesLabUserDefaults: servicesLabUserDefaults,
            servicesLabKeychain: servicesLabKeychain,
            notificationGraph: notificationGraph,
            diagnostics: diagnostics,
            sessionStartupValidationPolicy: scenario.sessionSeed.validationMode == .scripted
                ? .automatic : .disabled,
            sessionRefreshSchedulePolicy: .disabled,
            cart: cart,
            uiTestScriptTracker: tracker,
            uiTestNotificationLabSteps: scenario.notificationSeed.labSteps,
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
        let keychain = InMemoryKeychainService()
        let clock = AppClock.live
        let appInfo = AppInfoService(
            displayName: "AppTemplate UI Tests",
            version: "1.0"
        )
        let resolvedNotificationGraph = notificationGraph ?? .inMemory(
            imageLoader: imageLoader,
            clock: clock
        )
        return compose(
            database: database,
            remote: remoteService,
            imageLoader: imageLoader,
            clock: clock,
            keychain: keychain,
            storePreferencesService: InMemoryUserDefaultsService(
                namespace: AppNamespace.primary
            ),
            appStateStorage: InMemoryAppStateStorage(initialState: initialState),
            appInfo: appInfo,
            servicesLabUserDefaults: InMemoryUserDefaultsService(
                namespace: AppNamespace.servicesLab
            ),
            servicesLabKeychain: InMemoryKeychainService(),
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled
        )
    }

    @MainActor
    static func preview(
        appInfo: any IAppInfoService,
        remoteService: any IRemoteService,
        diagnostics: NetworkDiagnosticRecorder,
        imageLoader: any IImageLoader,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        storePreferencesService: any IUserDefaultsService = InMemoryUserDefaultsService(
            namespace: AppNamespace.primary
        ),
        keychainService: any IKeychainService = InMemoryKeychainService(),
        notificationGraph: AppNotificationGraph? = nil
    ) -> AppDependencies {
        let clock = AppClock.live
        let resolvedNotificationGraph = notificationGraph ?? .inMemory(
            imageLoader: imageLoader,
            clock: clock
        )
        return compose(
            database: localDatabaseService,
            remote: remoteService,
            imageLoader: imageLoader,
            clock: clock,
            keychain: keychainService,
            storePreferencesService: storePreferencesService,
            appStateStorage: appStateStorage,
            appInfo: appInfo,
            servicesLabUserDefaults: InMemoryUserDefaultsService(
                namespace: AppNamespace.servicesLab
            ),
            servicesLabKeychain: InMemoryKeychainService(),
            notificationGraph: resolvedNotificationGraph,
            diagnostics: diagnostics,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled
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
        appInfo: any IAppInfoService,
        notificationGraph: AppNotificationGraph,
        storePreferencesService: any IUserDefaultsService = InMemoryUserDefaultsService(
            namespace: AppNamespace.primary
        )
    ) -> AppDependencies {
        compose(
            database: localDatabaseService,
            remote: remoteService,
            imageLoader: imageLoader,
            clock: .live,
            keychain: keychainService,
            storePreferencesService: storePreferencesService,
            appStateStorage: appStateStorage,
            appInfo: appInfo,
            servicesLabUserDefaults: InMemoryUserDefaultsService(
                namespace: AppNamespace.servicesLab
            ),
            servicesLabKeychain: InMemoryKeychainService(),
            notificationGraph: notificationGraph,
            diagnostics: diagnostics,
            sessionStartupValidationPolicy: .disabled,
            sessionRefreshSchedulePolicy: .disabled
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
        let notificationFacade = LocalNotificationLabService(
            service: notificationGraph.dependencies.service,
            catalog: notificationGraph.dependencies.categoryCatalog,
            namespace: "services.lab"
        )
        let notificationLab: any ILocalNotificationLabService
        let notificationAppWide: any ILocalNotificationAppWideCapabilities
        if let steps = uiTestNotificationLabSteps,
           let tracker = uiTestScriptTracker {
            let scripted = ScriptedLocalNotificationLabService(
                lab: notificationFacade,
                appWide: notificationFacade,
                steps: steps,
                tracker: tracker
            )
            notificationLab = scripted
            notificationAppWide = scripted
        } else {
            notificationLab = notificationFacade
            notificationAppWide = notificationFacade
        }
        return ServicesDependencies(
            appState: appState,
            appFlowCoordinator: appFlowCoordinator,
            appStateStatus: appStateStatus,
            sessionActions: sessionActions,
            appInfo: appInfo,
            userDefaultsLab: servicesLabUserDefaults,
            keychainLab: servicesLabKeychain,
            localDatabase: localDatabaseExamples,
            remoteAPI: remoteAPILab,
            diagnostics: diagnostics,
            notificationLab: notificationLab,
            notificationAppWide: notificationAppWide,
            notificationHistory: notificationGraph.dependencies.eventReader,
            notificationAssets: LocalNotificationLabAssetProvider(bundle: .main)
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
