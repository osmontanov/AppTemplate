nonisolated
struct AppDependencies: Sendable {
    let browse: BrowseDependencies
    let projects: ProjectsDependencies
    let session: SessionDependencies
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService

    init(
        browse: BrowseDependencies,
        projects: ProjectsDependencies,
        session: SessionDependencies,
        localDatabase: any ILocalDatabaseService,
        remote: any IRemoteService
    ) {
        self.browse = browse
        self.projects = projects
        self.session = session
        self.localDatabase = localDatabase
        self.remote = remote
    }

    static func live() -> AppDependencies {
        let sessionService = SessionService(initialSession: nil)

        return AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService.live()
            ),
            projects: ProjectsDependencies(),
            session: SessionDependencies(
                service: sessionService
            ),
            localDatabase: LocalDatabaseService(),
            remote: RemoteService()
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        session: UserSession?,
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        let sessionService = SessionService(initialSession: session)

        return AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService(items: browseItems)
            ),
            projects: ProjectsDependencies(),
            session: SessionDependencies(
                service: sessionService
            ),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }

    static func test(
        browseService: any IBrowseService,
        sessionService: any ISessionService,
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(),
        remoteService: any IRemoteService = RemoteService()
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: browseService
            ),
            projects: ProjectsDependencies(),
            session: SessionDependencies(
                service: sessionService
            ),
            localDatabase: localDatabaseService,
            remote: remoteService
        )
    }
}
