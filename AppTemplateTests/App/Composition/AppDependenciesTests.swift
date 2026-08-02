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
    func uiTestingGraphUsesFreshInMemoryStateAndFixedAppInfo() throws {
        let initialState = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstDependencies = AppDependencies.uiTesting(initialState: initialState)
        let secondDependencies = AppDependencies.uiTesting(initialState: initialState)
        let firstStorage = try #require(
            firstDependencies.appStateStorage as? InMemoryAppStateStorage
        )
        let secondStorage = try #require(
            secondDependencies.appStateStorage as? InMemoryAppStateStorage
        )

        #expect(firstDependencies.localDatabase is LocalDatabaseService)
        #expect(firstDependencies.remote is RemoteService)
        #expect(firstDependencies.settings.appInfo.displayName == "AppTemplate UI Tests")
        #expect(firstDependencies.settings.appInfo.version == "1.0")
        #expect(try decodedState(from: firstStorage) == initialState)

        try firstStorage.remove()

        #expect(try decodedState(from: secondStorage) == initialState)
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

private func decodedState(from storage: InMemoryAppStateStorage) throws -> AppState {
    let data = try #require({
        if case let .data(data) = try storage.load() {
            return data
        }
        return nil
    }())

    return try JSONDecoder().decode(AppState.self, from: data)
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
