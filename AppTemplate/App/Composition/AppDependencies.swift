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
                repository: InMemoryBrowseRepository.live()
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
                repository: InMemoryBrowseRepository(items: browseItems)
            ),
            session: SessionDependencies(
                service: InMemorySessionService(initialSession: session)
            )
        )
    }

    static func test(
        browseRepository: any BrowseRepository,
        sessionService: any SessionService
    ) -> AppDependencies {
        AppDependencies(
            browse: BrowseDependencies(
                repository: browseRepository
            ),
            session: SessionDependencies(
                service: sessionService
            )
        )
    }
}
