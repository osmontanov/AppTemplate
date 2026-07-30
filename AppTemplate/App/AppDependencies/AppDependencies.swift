nonisolated
struct AppDependencies: Sendable {
    let projects: ProjectsDependencies
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService

    init(
        projects: ProjectsDependencies,
        localDatabase: any ILocalDatabaseService,
        remote: any IRemoteService
    ) {
        self.projects = projects
        self.localDatabase = localDatabase
        self.remote = remote
    }

    static func live() -> AppDependencies {
        AppDependencies(
            projects: ProjectsDependencies(),
            localDatabase: LocalDatabaseService(),
            remote: RemoteService()
        )
    }

    static func preview(
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            projects: ProjectsDependencies(),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService
    ) -> AppDependencies {
        AppDependencies(
            projects: ProjectsDependencies(),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }
}
