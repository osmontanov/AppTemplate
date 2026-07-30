import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredServices() async throws {
        let dependencies = AppDependencies.live()
        let items = try await dependencies.browse.service.items()

        #expect(dependencies.browse.service is BrowseService)
        #expect(dependencies.localDatabase is LocalDatabaseService)
        #expect(dependencies.remote is RemoteService)
        let _: ProjectsDependencies = dependencies.projects
        #expect(items.map(\.id) == ["swiftui", "observation", "routing"])
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() async throws {
        let item = BrowseItem(id: "preview", title: "Preview", summary: "Fixture")
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let dependencies = AppDependencies.preview(
            browseItems: [item],
            localDatabaseService: localDatabaseService,
            remoteService: remoteService
        )
        let items = try await dependencies.browse.service.items()
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )

        #expect(items == [item])
        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        let _: ProjectsDependencies = dependencies.projects
    }

    @Test
    func testGraphKeepsInjectedServices() async throws {
        let item = BrowseItem(
            id: "injected-item",
            title: "Injected",
            summary: "Unique repository behavior"
        )
        let browseService = InjectedBrowseService(item: item)
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let dependencies = AppDependencies.test(
            browseService: browseService,
            localDatabaseService: localDatabaseService,
            remoteService: remoteService
        )
        let items = try await dependencies.browse.service.items()
        let resolvedBrowseService = try #require(
            dependencies.browse.service as? InjectedBrowseService
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )

        #expect(resolvedBrowseService === browseService)
        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        #expect(items == [item])
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

private actor InjectedLocalDatabaseService: ILocalDatabaseService {}
private actor InjectedRemoteService: IRemoteService {}
