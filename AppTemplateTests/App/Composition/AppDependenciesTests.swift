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
        #expect(dependencies.settings.appInfo is AppInfoService)
    }

    @Test
    func previewGraphUsesInMemoryStateStorageByDefault() {
        let dependencies = AppDependencies.preview(
            settings: SettingsDependencies(
                appInfo: AppInfoService(
                    displayName: "Preview App",
                    version: "9.8.7"
                )
            )
        )

        #expect(dependencies.appStateStorage is InMemoryAppStateStorage)
    }

    @Test
    func previewGraphUsesOnlyProvidedValues() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Preview App",
                version: "9.8.7"
            )
        )
        let dependencies = AppDependencies.preview(
            settings: settings,
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
        #expect(dependencies.settings.appInfo.displayName == "Preview App")
        #expect(dependencies.settings.appInfo.version == "9.8.7")
    }

    @Test
    func testGraphKeepsInjectedServices() throws {
        let localDatabaseService = InjectedLocalDatabaseService()
        let remoteService = InjectedRemoteService()
        let appStateStorage = InjectedAppStateStorage()
        let settings = SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "Test App",
                version: "3.2.1"
            )
        )
        let dependencies = AppDependencies.test(
            localDatabaseService: localDatabaseService,
            remoteService: remoteService,
            appStateStorage: appStateStorage,
            settings: settings
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
        #expect(dependencies.settings.appInfo.displayName == "Test App")
        #expect(dependencies.settings.appInfo.version == "3.2.1")
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
