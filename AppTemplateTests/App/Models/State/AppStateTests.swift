import Foundation
import Testing
@testable import AppTemplate

struct AppStateTests {
    @Test
    func initialStateUsesCurrentSchemaAndSafeFlags() {
        let state = AppState.initial

        #expect(state.schemaVersion == 1)
        #expect(!state.isAuthenticated)
        #expect(!state.hasCompletedOnboarding)
        #expect(!state.isMaintenanceEnabled)
    }

    @Test
    func codingRoundTripPreservesEveryFieldAndOnlyExpectedKeys() throws {
        let source = AppState(
            isAuthenticated: true,
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
                "isAuthenticated",
                "hasCompletedOnboarding",
                "isMaintenanceEnabled"
            ]
        )
    }
}
