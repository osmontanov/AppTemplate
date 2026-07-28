nonisolated struct AppDependencies: Sendable {
    let browse: BrowseDependencies
    let session: SessionDependencies

    init(
        browse: BrowseDependencies,
        session: SessionDependencies
    ) {
        self.browse = browse
        self.session = session
    }

    static func live() -> AppDependencies {
        let sessionService = SessionService(initialSession: nil)

        return AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService.live()
            ),
            session: SessionDependencies(
                service: sessionService
            )
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        session: UserSession?
    ) -> AppDependencies {
        let sessionService = SessionService(initialSession: session)

        return AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService(items: browseItems)
            ),
            session: SessionDependencies(
                service: sessionService
            )
        )
    }

    static func test(
        browseService: any IBrowseService,
        sessionService: any ISessionService
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: browseService
            ),
            session: SessionDependencies(
                service: sessionService
            )
        )
    }
}
