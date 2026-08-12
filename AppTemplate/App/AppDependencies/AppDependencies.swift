nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let settings: SettingsDependencies

    static func live(
        localDatabaseStoreLocationResolver:
            LocalDatabaseStoreLocationResolver = .live(),
        userDefaultsService: any IUserDefaultsService = UserDefaultsService(
            namespace: "AppTemplate"
        ),
        keychainService: any IKeychainService = KeychainService(
            service: "AppTemplate"
        )
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .live(locationResolver: localDatabaseStoreLocationResolver)
            ),
            remote: RemoteService(),
            appStateStorage: UserDefaultsAppStateStorage(userDefaults: userDefaultsService),
            keychain: keychainService,
            settings: SettingsDependencies(appInfo: AppInfoService())
        )
    }

    static func uiTesting(initialState: AppState) -> AppDependencies {
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
            )
        )
    }

    static func preview(
        settings: SettingsDependencies,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        remoteService: any IRemoteService = RemoteService(),
        keychainService: any IKeychainService = InMemoryKeychainService()
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            settings: settings
        )
    }

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
        appStateStorage: any IAppStateStorage,
        keychainService: any IKeychainService,
        settings: SettingsDependencies
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            keychain: keychainService,
            settings: settings
        )
    }
}
