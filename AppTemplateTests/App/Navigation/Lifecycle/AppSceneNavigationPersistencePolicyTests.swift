import Foundation
import Testing
@testable import AppTemplate

struct AppSceneNavigationPersistencePolicyTests {
    @Test
    func restoredPolicyUsesStoredDataAndAllowsWrites() {
        let storedData = Data("stored-navigation".utf8)

        #expect(
            AppSceneNavigationPersistencePolicy.restored.restorationData(
                from: storedData
            ) == storedData
        )
        #expect(
            AppSceneNavigationPersistencePolicy.restored
                .allowsSnapshotPersistence
        )
    }

    @Test
    func ephemeralPolicyIgnoresStoredDataAndRejectsWrites() {
        let storedData = Data("stored-navigation".utf8)

        #expect(
            AppSceneNavigationPersistencePolicy.ephemeral.restorationData(
                from: storedData
            ) == nil
        )
        #expect(
            !AppSceneNavigationPersistencePolicy.ephemeral
                .allowsSnapshotPersistence
        )
    }
}
