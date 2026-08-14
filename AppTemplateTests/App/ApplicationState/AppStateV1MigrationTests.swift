import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppStateV1MigrationTests {
    @Test
    func successfulMigrationPublishesPolicyAndSavesPolicyOnlyV2() throws {
        let old = Data(
            #"{"schemaVersion":1,"isAuthenticated":true,"hasCompletedOnboarding":true,"isMaintenanceEnabled":false}"#.utf8
        )
        let storage = AppStateStorageSpy(loadResult: .data(old))

        let store = AppStateStore(storage: storage)

        #expect(
            store.state == AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        )
        #expect(store.persistenceStatus == .writable)
        #expect(storage.savedData.count == 1)
        let saved = try #require(storage.savedData.first)
        let object = try #require(
            JSONSerialization.jsonObject(with: saved) as? [String: Any]
        )
        #expect(object["schemaVersion"] as? Int == 2)
        #expect(object["isAuthenticated"] == nil)
    }

    @Test
    func failedMigrationPreservesV1BytesAndPublishesMigratedPolicy() {
        let old = Data(
            #"{"schemaVersion":1,"isAuthenticated":true,"hasCompletedOnboarding":true,"isMaintenanceEnabled":false}"#.utf8
        )
        let storage = AppStateStorageSpy(
            loadResult: .data(old),
            saveError: MigrationError.failed
        )

        let store = AppStateStore(storage: storage)

        #expect(store.state.hasCompletedOnboarding)
        #expect(!store.state.isMaintenanceEnabled)
        #expect(storage.currentData == old)
        #expect(storage.savedData.isEmpty)
        #expect(storage.removeCallCount == 0)
        #expect(
            store.persistenceStatus == .readOnly(.migrationSaveFailed)
        )
    }

    @Test
    func futureV3BytesRemainUntouchedAndReadOnly() {
        let future = Data(
            #"{"schemaVersion":3,"future":"preserve-me"}"#.utf8
        )
        let storage = AppStateStorageSpy(loadResult: .data(future))
        let store = AppStateStore(storage: storage)
        let proposed = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )

        #expect(store.state == .initial)
        #expect(
            store.persistenceStatus == .readOnly(
                .unsupportedFutureSchema(3)
            )
        )
        #expect(
            store.setState(proposed)
                == .rejected(.unsupportedFutureSchema(3))
        )
        #expect(storage.currentData == future)
        #expect(storage.savedData.isEmpty)
        #expect(storage.removeCallCount == 0)
    }
}

nonisolated
private enum MigrationError: Error {
    case failed
}
