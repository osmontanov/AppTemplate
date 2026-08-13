import Foundation

nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let settings: SettingsDependencies
    let localNotifications: LocalNotificationDependencies
    let diagnostics: NetworkDiagnosticRecorder
    let imageLoader: any IImageLoader

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
            keychain: keychainService,
            settings: SettingsDependencies(appInfo: AppInfoService()),
            localNotifications: localNotifications ?? .live(
                runtimeResolver: localNotificationRuntimeResolver
            ),
            diagnostics: diagnostics,
            imageLoader: imageLoader
        )
    }

    @MainActor
    static func uiTesting(
        initialState: AppState,
        remoteService: any IRemoteService,
        diagnostics: NetworkDiagnosticRecorder,
        imageLoader: any IImageLoader,
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .inMemory()
            ),
            remote: remoteService,
            appStateStorage: InMemoryAppStateStorage(initialState: initialState),
            keychain: InMemoryKeychainService(),
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "AppTemplate UI Tests",
                    version: "1.0"
                )
            ),
            localNotifications: localNotifications ?? .inMemory(),
            diagnostics: diagnostics,
            imageLoader: imageLoader
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
        keychainService: any IKeychainService = InMemoryKeychainService(),
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            settings: settings,
            localNotifications: localNotifications ?? .inMemory(),
            diagnostics: diagnostics,
            imageLoader: imageLoader
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
        localNotifications: LocalNotificationDependencies
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            settings: settings,
            localNotifications: localNotifications,
            diagnostics: diagnostics,
            imageLoader: imageLoader
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
