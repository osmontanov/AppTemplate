import Foundation
import Testing
@testable import AppTemplate

struct ServicesGuideTests {
    @MainActor
    @Test
    func catalogHasNormativeOrderUniqueRoutesAndCompleteGuides() {
        let items = ServicesCatalogViewModel.items

        #expect(items.map(\.route) == [
            .appState,
            .appInfo,
            .userDefaults,
            .keychain,
            .localDatabase,
            .remoteAPI,
            .localNotifications
        ])
        #expect(Set(items.map(\.route)).count == 7)
        #expect(items.allSatisfy {
            !$0.guide.why.isEmpty
                && !$0.guide.preset.isEmpty
                && !$0.guide.expected.isEmpty
        })
        #expect(items.map(\.id) == items.map(\.route))
    }

    @Test
    func everyLabUsesTheRequiredSectionOrder() {
        #expect(ServiceLabGuideSection.allCases.map(\.title) == [
            "Why",
            "Preset",
            "Try It",
            "Expected",
            "Actual",
            "Reset Demo Data",
            "Advanced"
        ])
    }

    @Test(arguments: [
        (ServiceLabResult.idle, false),
        (.running, false),
        (.success("Completed safely."), true),
        (.failure("Could not complete."), false)
    ])
    func onlySuccessReportsSuccess(
        result: ServiceLabResult,
        expected: Bool
    ) {
        #expect(result.isSuccess == expected)
    }

    @Test(arguments: [
        (ServicesRoute.appState, #"{"tag":"app-state"}"#),
        (.appInfo, #"{"tag":"app-info"}"#),
        (.userDefaults, #"{"tag":"user-defaults"}"#),
        (.keychain, #"{"tag":"keychain"}"#),
        (.localDatabase, #"{"tag":"local-database"}"#),
        (.remoteAPI, #"{"tag":"remote-api"}"#),
        (.localNotifications, #"{"tag":"local-notifications"}"#)
    ])
    func catalogRoutesKeepStableWireTags(
        route: ServicesRoute,
        expectedJSON: String
    ) throws {
        let data = try JSONEncoder().encode(route)
        #expect(String(decoding: data, as: UTF8.self) == expectedJSON)
        #expect(try JSONDecoder().decode(ServicesRoute.self, from: data) == route)
    }
}
