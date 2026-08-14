import Testing
@testable import AppTemplate

struct AccessibilityIdentifierTests {
    @Test
    func identifiersAreStableCompleteUniqueAndNotVisibleCopy() {
        let screenIDs = AppAccessibilityIdentifier.Screen.allCases.map(AppAccessibilityIdentifier.screen)
        #expect(screenIDs == [
            "screen.store.catalog", "screen.store.product", "screen.store.reviews",
            "screen.store.cart", "screen.store.checkout", "screen.authentication",
            "screen.session-recovery", "screen.store.favorites", "screen.store.profile",
            "screen.store.settings", "screen.store.product-reminder", "screen.services.root",
            "screen.services.lab", "screen.onboarding", "screen.maintenance",
            "screen.session-restoring"
        ])

        let actionIDs = AppAccessibilityIdentifier.Action.allCases.map(AppAccessibilityIdentifier.action)
        #expect(actionIDs == [
            "action.service.try", "action.service.reset", "action.product-reminder.schedule",
            "action.store.favorite", "action.authentication.sign-in", "action.store.sign-out",
            "action.cancel", "action.store.checkout.continue"
        ])

        let resultIDs = AppAccessibilityIdentifier.ResultRole.allCases.map(AppAccessibilityIdentifier.result)
        #expect(resultIDs == [
            "result.actual.success", "result.actual.failure", "result.loading", "result.empty"
        ])

        let destinationIDs = AppAccessibilityIdentifier.ServiceDestination.allCases.map(
            AppAccessibilityIdentifier.serviceDestination
        )
        #expect(destinationIDs == [
            "service.app-state", "service.app-info", "service.user-defaults", "service.keychain",
            "service.local-database", "service.remote-api", "service.local-notifications"
        ])

        for identifiers in [screenIDs, actionIDs, resultIDs, destinationIDs] {
            #expect(Set(identifiers).count == identifiers.count)
            #expect(identifiers.allSatisfy { $0 == $0.lowercased() && !$0.contains(" ") })
        }
    }

    @Test
    func servicesRoutesPreserveNormativeOrderAndExhaustiveDestinationMapping() {
        #expect(ServicesRoute.allCases.map(\.accessibilityDestination) == [
            .appState, .appInfo, .userDefaults, .keychain, .localDatabase, .remoteAPI,
            .localNotifications
        ])
        #expect(ServicesRoute.allCases.map {
            AppAccessibilityIdentifier.serviceDestination($0.accessibilityDestination)
        } == [
            "service.app-state", "service.app-info", "service.user-defaults", "service.keychain",
            "service.local-database", "service.remote-api", "service.local-notifications"
        ])
    }
}
