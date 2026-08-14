import XCTest

nonisolated
final class StoreJourneyTests: XCTestCase {
    @MainActor
    func testGuestCatalogReviewsCartCheckoutProfileAndPaths() throws {
        let robot = AppRobot()
        let app = robot.launch(.guestStore)
        let store = StoreRobot(app: app)

        try store.loadNextCatalogPage()
        try store.openProductDeepLink(id: 1)
        try store.navigateBack()
        try store.openProduct("Offline Phone Two")
        try store.addCurrentProductToCart()
        try store.navigateBack()

        try store.openToolbarDestination("action.store.cart")
        try store.completeCheckout()
        try store.navigateBack()

        try store.openToolbarDestination("action.store.profile")
        _ = try robot.require("screen.store.profile", in: app)
        try robot.openSection(
            "tab.services",
            expecting: "screen.services.root",
            in: app
        )
        try robot.openSection(
            "tab.store",
            expecting: "screen.store.profile",
            in: app
        )
        try store.navigateBack()
        try store.openProduct("Offline Phone One")
        try store.openReviews()
        try robot.assertScenarioScriptsExhausted(in: app)
    }

    @MainActor
    func testProtectedFavoriteAuthenticationResumeAndSignOut() throws {
        let robot = AppRobot()
        let app = robot.launch(.protectedFavorite)
        let store = StoreRobot(app: app)

        try store.openProtectedFavoritesDeepLink()
        robot.assertScenarioScriptsHealthy(in: app)
        let authentication = AuthenticationRobot(app: app)
        try authentication.cancel()
        _ = try robot.require("screen.store.catalog", in: app)
        robot.assertScenarioScriptsHealthy(in: app)

        try store.openProduct("Protected Phone")
        try store.favorite()
        try authentication.requireReady()
        try authentication.submitInvalidAccount()
        robot.assertScenarioScriptsHealthy(in: app)
        try authentication.cancel()
        _ = try robot.require("screen.store.product", in: app)
        try store.favorite()
        try authentication.requireReady()
        try store.authenticateWithDemoAccount()
        robot.assertScenarioScriptsHealthy(in: app)
        try store.navigateBack()
        robot.assertScenarioScriptsHealthy(in: app)
        try store.openToolbarDestination("action.store.favorites")
        try store.requireFavorite("Protected Phone")
        robot.assertScenarioScriptsHealthy(in: app)
        try store.navigateBack()
        try store.openToolbarDestination("action.store.profile")
        robot.assertScenarioScriptsHealthy(in: app)
        try store.openAccountAndSignOut()
        robot.assertScenarioScriptsHealthy(in: app)

        _ = try robot.require("screen.store.profile", in: app)
        XCTAssertFalse(robot.element("screen.authentication", in: app).exists)
        try robot.assertScenarioScriptsExhausted(in: app)
    }

    @MainActor
    func testInMemoryQuickReminderAndCancel() throws {
        let robot = AppRobot()
        let app = robot.launch(.productReminder)
        let store = StoreRobot(app: app)

        try store.openProduct("Reminder Phone")
        try store.openCurrentProductReminder()
        try store.scheduleQuickReminder()
        try store.cancelCurrentProductReminder()
        try robot.assertScenarioScriptsExhausted(in: app)
    }
}
