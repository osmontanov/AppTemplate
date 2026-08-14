import XCTest

nonisolated
final class ShellUITests: XCTestCase {
    @MainActor
    func testGuestStoreJourney() throws {
        let appRobot = try AppRobot.launchGuestStore()
        let store = appRobot.store()

        try store.loadNextCatalogPage()
        try store.openProduct("Offline Phone One")
        try store.openReviews()
        try store.navigateBack()
        try store.openProduct("Offline Phone Two")
        try store.addCurrentProductToCart()
        try store.navigateBack()
        try store.navigateBack()

        try store.openMoreDestination("Cart")
        try store.completeCheckout()
        try store.navigateBack()

        try store.openMoreDestination("Profile")
        _ = try appRobot.require("screen.store.profile")
        try appRobot.openSection(
            "tab.services",
            expecting: "screen.services.root"
        )
        try appRobot.openSection(
            "tab.store",
            expecting: "screen.store.profile"
        )

        try appRobot.waitForScriptExhaustion()
    }
}
