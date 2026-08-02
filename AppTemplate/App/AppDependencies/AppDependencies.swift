nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage

    static func live() -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(),
            remote: RemoteService(),
            appStateStorage: UserDefaultsAppStateStorage()
        )
    }

    static func preview(
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage
        )
    }

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
        appStateStorage: any IAppStateStorage
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService,
            appStateStorage: appStateStorage
        )
    }
}
