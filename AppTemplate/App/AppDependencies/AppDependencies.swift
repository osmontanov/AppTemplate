nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let settings: SettingsDependencies

    static func live(
        localDatabaseStoreLocationResolver:
            LocalDatabaseStoreLocationResolver = .live()
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(
                configuration: .live(
                    locationResolver: localDatabaseStoreLocationResolver
                )
            ),
            remote: RemoteService(),
            appStateStorage: UserDefaultsAppStateStorage(),
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
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            settings: settings
        )
    }

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
        appStateStorage: any IAppStateStorage,
        settings: SettingsDependencies
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage,
            settings: settings
        )
    }
}
