import Foundation
import Testing
@testable import AppTemplate

struct AppDependenciesTests {
    @Test
    func liveGraphUsesDeclaredServices() {
        let dependencies = AppDependencies.live()

        #expect(dependencies.localDatabase is LocalDatabaseService)
        #expect(dependencies.remote is RemoteService)
        #expect(dependencies.appStateStorage is UserDefaultsAppStateStorage)
    }

    @Test
    func previewGraphUsesInMemoryStateStorageByDefault() {
        let dependencies = AppDependencies.preview()

        #expect(dependencies.appStateStorage is InMemoryAppStateStorage)
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let dependencies = AppDependencies.preview(
            appStateStorage: appStateStorage,
            localDatabaseService: localDatabaseService,
            remoteService: remoteService
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )
        let resolvedAppStateStorage = try #require(
            dependencies.appStateStorage as? InjectedAppStateStorage
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        #expect(resolvedAppStateStorage === appStateStorage)
    }

    @Test
    func testGraphKeepsInjectedServices() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let dependencies = AppDependencies.test(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService,
            appStateStorage: appStateStorage
        )
        let resolvedLocalDatabaseService = try #require(
            dependencies.localDatabase as? InjectedLocalDatabaseService
        )
        let resolvedRemoteService = try #require(
            dependencies.remote as? InjectedRemoteService
        )
        let resolvedAppStateStorage = try #require(
            dependencies.appStateStorage as? InjectedAppStateStorage
        )

        #expect(resolvedLocalDatabaseService === localDatabaseService)
        #expect(resolvedRemoteService === remoteService)
        #expect(resolvedAppStateStorage === appStateStorage)
    }
}

private actor InjectedLocalDatabaseService: ILocalDatabaseService {}
private actor InjectedRemoteService: IRemoteService {}

nonisolated
private final class InjectedAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    func load() -> AppStateStorageLoadResult { .missing }
    func save(_ data: Data) {}
    func remove() {}
}
