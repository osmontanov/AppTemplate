import Foundation

nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let legacyAuthentication: LegacyAuthenticationState
    let keychain: any IKeychainService
    let settings: SettingsDependencies
    let localNotifications: LocalNotificationDependencies
    let diagnostics: NetworkDiagnosticRecorder
    let imageLoader: any IImageLoader
    let uiTestScriptTracker: UITestScriptConsumptionTracker?
    let bootstrap: @Sendable () async throws -> Void

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
        localNotifications: LocalNotificationDependencies? = nil,
        localNotificationRuntimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> AppDependencies {
        let diagnostics = NetworkDiagnosticRecorder()
        return AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .live(locationResolver: localDatabaseStoreLocationResolver)
            ),
            remote: RemoteService(diagnosticRecorder: diagnostics),
            appStateStorage: UserDefaultsAppStateStorage(userDefaults: userDefaultsService),
            legacyAuthentication: LegacyAuthenticationState(),
            keychain: keychainService,
            settings: SettingsDependencies(appInfo: AppInfoService()),
            localNotifications: localNotifications ?? .live(
                runtimeResolver: localNotificationRuntimeResolver
            ),
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
        let keychain = InMemoryKeychainService()
        let notifications = LocalNotificationDependencies.inMemory(
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
                .contains(scenario.notificationSeed.authorizationStatus)
        )
        return AppDependencies(
            localDatabase: database,
            remote: remote,
            appStateStorage: InMemoryAppStateStorage(initialState: scenario.appState),
            legacyAuthentication: LegacyAuthenticationState(
                isAuthenticated: scenario.legacyAuthenticationIsAuthenticated
            ),
            keychain: keychain,
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "AppTemplate UI Tests",
                    version: "1.0"
                )
            ),
            localNotifications: notifications,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: tracker,
            bootstrap: {
                if let data = scenario.sessionSeed.keychainData {
                    try await keychain.set(data, for: .data("UITestSession"))
                }
                try await database.upsert(scenario.localDatabaseSeed.examples)
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
        legacyAuthentication: LegacyAuthenticationState = LegacyAuthenticationState(),
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(configuration: .inMemory()),
            remote: remoteService,
            appStateStorage: InMemoryAppStateStorage(initialState: initialState),
            legacyAuthentication: legacyAuthentication,
            keychain: InMemoryKeychainService(),
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "AppTemplate UI Tests",
                    version: "1.0"
                )
            ),
            localNotifications: localNotifications ?? .inMemory(),
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
        legacyAuthentication: LegacyAuthenticationState = LegacyAuthenticationState(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        keychainService: any IKeychainService = InMemoryKeychainService(),
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            legacyAuthentication: legacyAuthentication,
            keychain: keychainService,
            settings: settings,
            localNotifications: localNotifications ?? .inMemory(),
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
        legacyAuthentication: LegacyAuthenticationState = LegacyAuthenticationState(),
        keychainService: any IKeychainService,
        settings: SettingsDependencies,
        localNotifications: LocalNotificationDependencies
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            legacyAuthentication: legacyAuthentication,
            keychain: keychainService,
            settings: settings,
            localNotifications: localNotifications,
            diagnostics: diagnostics,
            imageLoader: imageLoader,
            uiTestScriptTracker: nil,
            bootstrap: {}
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
