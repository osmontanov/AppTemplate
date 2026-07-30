import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredServices() {
        let dependencies = AppDependencies.live()

        #expect(dependencies.localDatabase is LocalDatabaseService)
        #expect(dependencies.remote is RemoteService)
        let _: ProjectsDependencies = dependencies.projects
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let dependencies = AppDependencies.preview(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        let _: ProjectsDependencies = dependencies.projects
    }

    @Test
    func testGraphKeepsInjectedServices() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let dependencies = AppDependencies.test(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        let _: ProjectsDependencies = dependencies.projects
    }
}

private actor InjectedLocalDatabaseService: ILocalDatabaseService {}
private actor InjectedRemoteService: IRemoteService {}
