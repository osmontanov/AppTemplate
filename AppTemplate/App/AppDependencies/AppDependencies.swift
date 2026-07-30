nonisolated
struct AppDependencies: Sendable {
    let browse: BrowseDependencies
    let projects: ProjectsDependencies
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService

    init(
        browse: BrowseDependencies,
        projects: ProjectsDependencies,
        localDatabase: any ILocalDatabaseService,
        remote: any IRemoteService
    ) {
        self.browse = browse
        self.projects = projects
        self.localDatabase = localDatabase
        self.remote = remote
    }

    static func live() -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService.live()
            ),
            projects: ProjectsDependencies(),
            localDatabase: LocalDatabaseService(),
            remote: RemoteService()
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService(items: browseItems)
            ),
            projects: ProjectsDependencies(),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }

    static func test(
        browseService: any IBrowseService,
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: browseService
            ),
            projects: ProjectsDependencies(),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }
}
