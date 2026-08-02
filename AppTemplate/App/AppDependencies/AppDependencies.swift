nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let settings: SettingsDependencies

    static func live() -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(),
            remote: RemoteService(),
            appStateStorage: UserDefaultsAppStateStorage(),
            settings: SettingsDependencies(appInfo: AppInfoService())
        )
    }

    static func preview(
        settings: SettingsDependencies,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
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
