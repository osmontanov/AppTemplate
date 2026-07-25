nonisolated struct AppDependencies: Sendable {
    let browseRepository: any BrowseRepository
    let sessionService: any SessionService

    init(
        browseRepository: any BrowseRepository,
        sessionService: any SessionService
    ) {
        self.browseRepository = browseRepository
        self.sessionService = sessionService
    }

    static func live() -> AppDependencies {
        AppDependencies(
            browseRepository: InMemoryBrowseRepository.live(),
            sessionService: InMemorySessionService(initialSession: nil)
        )
    }

    static func preview(
        browseItems: [BrowseItem],
        session: UserSession?
    ) -> AppDependencies {
        AppDependencies(
            browseRepository: InMemoryBrowseRepository(items: browseItems),
            sessionService: InMemorySessionService(initialSession: session)
        )
    }

    static func test(
        browseRepository: any BrowseRepository,
        sessionService: any SessionService
    ) -> AppDependencies {
        AppDependencies(
            browseRepository: browseRepository,
            sessionService: sessionService
        )
    }
}
