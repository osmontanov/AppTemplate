import Foundation
import Synchronization
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
    func liveGraphDefersResolverUntilFirstValidRegisteredOperation() async {
        let calls = Mutex(0)
        let dependencies = AppDependencies.live(
            localDatabaseStoreLocationResolver: .init(resolve: {
                calls.withLock { $0 += 1 }
                throw LocalDatabaseTestError.injectedFailure
            })
        )

        #expect(calls.withLock { $0 } == 0)
        do {
            _ = try await dependencies.localDatabase.fetch(
                ExampleRecord.self,
                id: "record-1"
            )
            Issue.record("Expected initialization failure")
        } catch let error as LocalDatabaseError {
            guard case .initialization = error else {
                Issue.record("Expected LocalDatabaseError.initialization")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
        #expect(calls.withLock { $0 } == 1)
    }

    @Test
    func previewAndUITestingGraphsUseFreshDatabases() async throws {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let firstPreview = AppDependencies.preview(settings: settings)
        let secondPreview = AppDependencies.preview(settings: settings)
        try await firstPreview.localDatabase.upsert(
            ExampleRecord(id: "preview", payload: "first")
        )
        #expect(
            try await secondPreview.localDatabase.fetch(
                ExampleRecord.self,
                id: "preview"
            )
                == nil
        )

        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
        let firstUI = AppDependencies.uiTesting(initialState: state)
        let secondUI = AppDependencies.uiTesting(initialState: state)
        try await firstUI.localDatabase.upsert(
            ExampleRecord(id: "ui", payload: "first")
        )
        #expect(
            try await secondUI.localDatabase.fetch(
                ExampleRecord.self,
                id: "ui"
            ) == nil
        )
    }

    @Test
    func previewAndUITestingGraphsRejectTestOnlyModel() async {
        let settings = SettingsDependencies(
            appInfo: AppInfoService(displayName: "Preview", version: "1")
        )
        let preview = AppDependencies.preview(settings: settings)
        let uiTesting = AppDependencies.uiTesting(
            initialState: AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: false,
                isMaintenanceEnabled: false
            )
        )

        await expectUnregisteredTestModel(preview.localDatabase)
        await expectUnregisteredTestModel(uiTesting.localDatabase)
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

private func expectUnregisteredTestModel(
    _ service: any ILocalDatabaseService
) async {
    do {
        _ = try await service.fetch(
            TestLocalRecord.self,
            id: TestLocalRecordID(rawValue: 1)
        )
        Issue.record("Expected LocalDatabaseError.validation")
    } catch let error as LocalDatabaseError {
        guard case let .validation(model, reason) = error else {
            Issue.record("Expected LocalDatabaseError.validation")
            return
        }
        #expect(model == TestLocalRecordAdapter.diagnosticName)
        #expect(reason == .unregisteredModel)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

private actor InjectedLocalDatabaseService: ILocalDatabaseService {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? { nil }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] { [] }

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws {}

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws {}

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool { false }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int { 0 }
}
private actor InjectedRemoteService: IRemoteService {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse {
        ExampleResponse(id: "injected", title: request.query)
    }
}

nonisolated
private final class InjectedAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    func load() -> AppStateStorageLoadResult { .missing }
    func save(_ data: Data) {}
    func remove() {}
}
