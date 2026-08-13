import Foundation
import Testing
@testable import AppTemplate

struct AppStateTests {
    @Test
    func initialStateUsesCurrentSchemaAndSafeFlags() {
        let state = AppState.initial

        #expect(state.schemaVersion == 2)
        #expect(!state.hasCompletedOnboarding)
        #expect(!state.isMaintenanceEnabled)
    }

    @Test
    func codingRoundTripPreservesEveryFieldAndOnlyExpectedKeys() throws {
        let source = AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: true
        )
        let data = try JSONEncoder().encode(source)
        let restored = try JSONDecoder().decode(AppState.self, from: data)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(restored == source)
        #expect(
            Set(object.keys) == [
                "schemaVersion",
                "hasCompletedOnboarding",
                "isMaintenanceEnabled"
            ]
        )
    }
}
