import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppStateStoreTests {
    @Test
    func futureSchemaLoadsInitialReadOnlyWithoutChangingStoredBytes()
        throws {
        let future = Data(
            #"{"schemaVersion":2,"future":"preserve-me"}"#.utf8
        )
        let storage = AppStateStorageSpy(loadResult: .data(future))

        let store = AppStateStore(storage: storage)

        #expect(store.state == .initial)
        #expect(
            store.persistenceStatus == .readOnly(
                .unsupportedFutureSchema(2)
            )
        )
        #expect(storage.currentData == future)
        #expect(storage.savedData.isEmpty)
        #expect(storage.removeCallCount == 0)
    }

    @Test
    func failedSaveRejectsMutationAndMakesStoreReadOnly() {
        let storage = AppStateStorageSpy(saveError: StorageError.failed)
        let store = AppStateStore(storage: storage)
        let proposed = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )

        #expect(store.setState(proposed) == .rejected(.saveFailed))
        #expect(store.state == .initial)
        #expect(store.persistenceStatus == .readOnly(.saveFailed))
    }

    @Test
    func failedLoadUsesInitialReadOnlyWithoutRepairing() {
        let storage = AppStateStorageSpy(loadError: StorageError.failed)
        let store = AppStateStore(storage: storage)

        #expect(store.state == .initial)
        #expect(store.persistenceStatus == .readOnly(.loadFailed))
        #expect(storage.savedData.isEmpty)
    }

    @Test
    func failedEncodingRejectsMutationWithoutChangingMemory() {
        let storage = AppStateStorageSpy()
        let store = AppStateStore(storage: storage, encode: { _ in
            throw EncodingErrorStub.failed
        })
        let proposed = AppState(
            isAuthenticated: false,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )

        #expect(store.setState(proposed) == .rejected(.encodingFailed))
        #expect(store.state == .initial)
        #expect(store.persistenceStatus == .readOnly(.encodingFailed))
        #expect(storage.savedData.isEmpty)
    }

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
    func legacySchemaRepairsExactlyOnce() throws {
        let legacy = AppState(
            schemaVersion: 0,
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(try JSONEncoder().encode(legacy))
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

        #expect(store.setState(changed) == .persisted)
        #expect(store.setState(changed) == .unchanged)
        #expect(store.state == changed)
        #expect(storage.savedData.count == 1)
    }
}

nonisolated
private enum EncodingErrorStub: Error {
    case failed
}

nonisolated
private enum StorageError: Error {
    case failed
}
