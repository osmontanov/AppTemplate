nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService

    static func live() -> AppDependencies {
        AppDependencies(
            localDatabase: LocalDatabaseService(),
            remote: RemoteService()
        )
    }

    static func preview(
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService
    ) -> AppDependencies {
        AppDependencies(
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }
}
