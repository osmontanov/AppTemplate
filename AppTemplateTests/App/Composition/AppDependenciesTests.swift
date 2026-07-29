import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredServices() async throws {
        let dependencies = AppDependencies.live()
        let items = try await dependencies.browse.service.items()
        let session = try await dependencies.session.service.currentSession()

        #expect(dependencies.browse.service is BrowseService)
        #expect(dependencies.session.service is SessionService)
        let _: ProjectsDependencies = dependencies.projects
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
        let items = try await dependencies.browse.service.items()
        let restoredSession = try await dependencies.session.service.currentSession()

        #expect(items == [item])
        #expect(restoredSession == session)
        let _: ProjectsDependencies = dependencies.projects
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
        let browseService = InjectedBrowseService(item: item)
        let service = InjectedSessionService(session: session)
        let dependencies = AppDependencies.test(
            browseService: browseService,
            sessionService: service
        )
        let items = try await dependencies.browse.service.items()
        let restoredSession = try await dependencies.session.service.currentSession()
        let resolvedBrowseService = try #require(
            dependencies.browse.service as? InjectedBrowseService
        )
        let resolvedService = try #require(
            dependencies.session.service as? InjectedSessionService
        )

        #expect(resolvedBrowseService === browseService)
        #expect(resolvedService === service)
        #expect(items == [item])
        #expect(restoredSession == session)
        let _: ProjectsDependencies = dependencies.projects
    }
}

private actor InjectedBrowseService: IBrowseService {
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

private actor InjectedSessionService: ISessionService {
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
