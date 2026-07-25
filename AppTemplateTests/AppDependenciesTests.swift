import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredInMemoryServices() async throws {
        let dependencies = AppDependencies.live()
        let items = try await dependencies.browseRepository.items()
        let session = try await dependencies.sessionService.currentSession()

        #expect(dependencies.browseRepository is InMemoryBrowseRepository)
        #expect(dependencies.sessionService is InMemorySessionService)
        #expect(items.map(\.id) == ["swiftui", "observation", "routing"])
        #expect(session == nil)
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() async throws {
        let item = BrowseItem(id: "preview", title: "Preview", summary: "Fixture")
        let session = UserSession(id: "preview-user", displayName: "Preview User")
        let dependencies = AppDependencies.preview(
            browseItems: [item],
            session: session
        )
        let items = try await dependencies.browseRepository.items()
        let restoredSession = try await dependencies.sessionService.currentSession()

        #expect(items == [item])
        #expect(restoredSession == session)
    }

    @Test
    func testGraphKeepsInjectedServices() async throws {
        let item = BrowseItem(
            id: "injected-item",
            title: "Injected",
            summary: "Unique repository behavior"
        )
        let session = UserSession(
            id: "injected-user",
            displayName: "Injected User"
        )
        let repository = InjectedBrowseRepository(item: item)
        let service = InjectedSessionService(session: session)
        let dependencies = AppDependencies.test(
            browseRepository: repository,
            sessionService: service
        )
        let items = try await dependencies.browseRepository.items()
        let restoredSession = try await dependencies.sessionService.currentSession()
        let resolvedRepository = try #require(
            dependencies.browseRepository as? InjectedBrowseRepository
        )
        let resolvedService = try #require(
            dependencies.sessionService as? InjectedSessionService
        )

        #expect(resolvedRepository === repository)
        #expect(resolvedService === service)
        #expect(items == [item])
        #expect(restoredSession == session)
    }
}

private actor InjectedBrowseRepository: BrowseRepository {
    private let item: BrowseItem

    init(item: BrowseItem) {
        self.item = item
    }

    func items() -> [BrowseItem] {
        [item]
    }

    func item(id: BrowseItem.ID) -> BrowseItem? {
        id == item.id ? item : nil
    }
}

private actor InjectedSessionService: SessionService {
    private let session: UserSession

    init(session: UserSession) {
        self.session = session
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        session
    }

    func signOut() {
    }
}
