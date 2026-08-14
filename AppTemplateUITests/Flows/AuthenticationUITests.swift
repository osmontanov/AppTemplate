import XCTest

nonisolated
final class AuthenticationUITests: XCTestCase {
    @MainActor
    func testFavoriteLoginResumeAndSignOut() throws {
        let appRobot = try AppRobot.launchProtectedFavorite()
        let store = appRobot.store()

        try store.openProduct("Protected Phone")
        try store.favoriteCurrentProduct()
        try store.signInWithDemoCredentials()
        try store.navigateBack()
        try store.openMoreDestination("Favorites")
        try store.requireFavorite("Protected Phone")
        try store.navigateBack()
        try store.openMoreDestination("Profile")
        try store.openAccountAndSignOut()

        _ = try appRobot.require("screen.store.profile")
        XCTAssertFalse(appRobot.element("screen.authentication").exists)
        try appRobot.waitForScriptExhaustion()
    }
}
