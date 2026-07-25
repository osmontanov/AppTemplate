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
        let repository = InMemoryBrowseRepository(items: [])
        let service = InMemorySessionService(initialSession: nil)
        let dependencies = AppDependencies.test(
            browseRepository: repository,
            sessionService: service
        )
        let items = try await dependencies.browseRepository.items()

        #expect(dependencies.browseRepository is InMemoryBrowseRepository)
        #expect(dependencies.sessionService is InMemorySessionService)
        #expect(items.isEmpty)
    }
}
