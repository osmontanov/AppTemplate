import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppStateStoreTests {
    @Test
    func missingValueLoadsInitialStateOnceWithoutWriting() {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage)

        #expect(store.state == .initial)
        #expect(storage.loadCallCount == 1)
        #expect(storage.savedData.isEmpty)
    }

    @Test
    func validCurrentRecordRestoresWithoutWriting() throws {
        let state = AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(state))
        )
        let store = AppStateStore(storage: storage)

        #expect(store.state == state)
        #expect(storage.savedData.isEmpty)
    }

    @Test(arguments: [
        AppStateStorageLoadResult.invalidValue,
        .data(Data("not-json".utf8))
    ])
    func invalidRecordsRepairToOneCurrentInitialRecord(
        result: AppStateStorageLoadResult
    ) throws {
        let storage = AppStateStorageSpy(loadResult: result)

        let first = AppStateStore(storage: storage)
        let second = AppStateStore(storage: storage)

        #expect(first.state == .initial)
        #expect(second.state == .initial)
        #expect(storage.savedData.count == 1)
        #expect(
            try JSONDecoder().decode(
                AppState.self,
                from: #require(storage.savedData.first)
            ) == .initial
        )
    }

    @Test
    func unsupportedSchemaRepairsExactlyOnce() throws {
        let unsupported = AppState(
            schemaVersion: 2,
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(unsupported))
        )

        let first = AppStateStore(storage: storage)
        let second = AppStateStore(storage: storage)

        #expect(first.state == .initial)
        #expect(second.state == .initial)
        #expect(storage.savedData.count == 1)
    }

    @Test
    func changedStateWritesOnceAndIdenticalStateIsIdempotent() {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage)
        let changed = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )

        #expect(store.setState(changed))
        #expect(!store.setState(changed))
        #expect(store.state == changed)
        #expect(storage.savedData.count == 1)
    }
}
