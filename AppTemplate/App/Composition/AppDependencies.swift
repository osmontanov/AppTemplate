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
        AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService.live()
            ),
            session: SessionDependencies(
                service: InMemorySessionService(initialSession: nil)
            )
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        session: UserSession?
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                service: BrowseService(items: browseItems)
            ),
            session: SessionDependencies(
                service: InMemorySessionService(initialSession: session)
            )
        )
    }

    static func test(
        browseService: any IBrowseService,
        sessionService: any SessionService
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
