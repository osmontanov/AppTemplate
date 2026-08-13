nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let settings: SettingsDependencies
    let localNotifications: LocalNotificationDependencies

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
        localNotifications: LocalNotificationDependencies? = nil,
        localNotificationRuntimeResolver: @MainActor () -> UserNotificationCenterRuntime =
            UserNotificationCenterRuntimeFactory.live
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .live(locationResolver: localDatabaseStoreLocationResolver)
            ),
            remote: RemoteService(),
            appStateStorage: UserDefaultsAppStateStorage(userDefaults: userDefaultsService),
            keychain: keychainService,
            settings: SettingsDependencies(appInfo: AppInfoService()),
            localNotifications: localNotifications ?? .live(
                runtimeResolver: localNotificationRuntimeResolver
            )
        )
    }

    @MainActor
    static func uiTesting(
        initialState: AppState,
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .inMemory()
            ),
            remote: RemoteService(),
            appStateStorage: InMemoryAppStateStorage(initialState: initialState),
            keychain: InMemoryKeychainService(),
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "AppTemplate UI Tests",
                    version: "1.0"
                )
            ),
            localNotifications: localNotifications ?? .inMemory()
        )
    }

    @MainActor
    static func preview(
        settings: SettingsDependencies,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        remoteService: any IRemoteService = RemoteService(),
        keychainService: any IKeychainService = InMemoryKeychainService(),
        localNotifications: LocalNotificationDependencies? = nil
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            settings: settings,
            localNotifications: localNotifications ?? .inMemory()
        )
    }

    @MainActor
    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
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
            localNotifications: localNotifications
        )
    }
}
