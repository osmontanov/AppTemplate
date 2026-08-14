import XCTest

@MainActor
struct StoreRobot {
    let app: XCUIApplication
    let appRobot: AppRobot

    func loadNextCatalogPage() throws {
        try appRobot.activate(app.buttons["Load more"])
        let product = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Offline Phone Three"))
            .firstMatch
        _ = try XCTUnwrap(
            product.waitForExistence(timeout: 5) ? product : nil,
            "Second catalog page did not appear"
        )
    }

    func openProduct(_ title: String) throws {
        let button = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", title))
            .firstMatch
        try appRobot.activate(button)
        _ = try appRobot.require("screen.store.product")
    }

    func openReviews() throws {
        try appRobot.activate(app.buttons["Reviews"])
        _ = try appRobot.require("screen.store.reviews")
    }

    func navigateBack() throws {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        try appRobot.activate(button)
    }

    func addCurrentProductToCart() throws {
        try appRobot.activate(app.buttons["Add to cart"])
    }

    func openCurrentProductReminder() throws {
        try appRobot.activate(appRobot.element("action.store.reminder"))
        _ = try appRobot.require("screen.store.product-reminder")
    }

    func scheduleQuickReminder() throws {
        try appRobot.activate(appRobot.element("action.product-reminder.schedule"))
        _ = try appRobot.require("result.product-reminder.scheduled")
    }

    func cancelCurrentProductReminder() throws {
        try appRobot.activate(appRobot.element("action.product-reminder.cancel"))
        _ = try appRobot.require("status.product-reminder.not-scheduled")
    }

    func openMoreDestination(_ title: String) throws {
        try appRobot.activate(app.buttons["More"])
        try appRobot.activate(app.buttons[title])
    }

    func favoriteCurrentProduct() throws {
        try appRobot.activate(appRobot.element("action.store.favorite"))
        _ = try appRobot.require("screen.authentication")
    }

    func signInWithDemoCredentials() throws {
        try appRobot.activate(app.buttons["Use demo credentials"])
        try appRobot.activate(app.buttons["Sign in"])
        _ = try appRobot.require("screen.store.product", timeout: 10)
        let authentication = appRobot.element("screen.authentication")
        _ = authentication.waitForNonExistence(timeout: 5)
    }

    func requireFavorite(_ title: String) throws {
        _ = try appRobot.require("screen.store.favorites")
        let product = app.buttons[title]
        _ = try XCTUnwrap(
            product.waitForExistence(timeout: 5) ? product : nil,
            "Resumed favorite did not appear"
        )
    }

    func openAccountAndSignOut() throws {
        let accountButton = app.buttons["Account"]
        let accountRadio = app.radioButtons["Account"]
        let account = accountButton.waitForExistence(timeout: 2)
            ? accountButton : accountRadio
        try appRobot.activate(account)
        try appRobot.activate(app.buttons["Sign Out"])
        _ = try appRobot.require("screen.store.profile")
        _ = try XCTUnwrap(
            app.buttons["Sign Out"].waitForNonExistence(timeout: 5) ? true : nil,
            "Committed Guest publication did not leave protected Account"
        )
    }

    func completeCheckout() throws {
        _ = try appRobot.require("screen.store.cart")
        try beginCheckout()
        try appRobot.activate(app.buttons["Place demo order"])
        _ = try appRobot.require("screen.store.cart")
        _ = try XCTUnwrap(
            app.staticTexts["Your cart changed. Review it before trying checkout again."]
                .waitForExistence(timeout: 5)
                ? app.staticTexts["Your cart changed. Review it before trying checkout again."]
                : nil,
            "Checkout did not surface the scripted revision conflict"
        )

        try beginCheckout()
        try appRobot.activate(app.buttons["Place demo order"])
        let done = app.buttons["Done"]
        _ = try XCTUnwrap(
            done.waitForExistence(timeout: 5) ? done : nil,
            "Checkout never reached local success"
        )
        try appRobot.activate(done)
        _ = try appRobot.require("screen.store.cart")
    }

    private func beginCheckout() throws {
        try appRobot.activate(app.buttons["Demo checkout"])
        _ = try appRobot.require("screen.store.checkout")
        try appRobot.activate(app.buttons["Review order"])
    }
}
