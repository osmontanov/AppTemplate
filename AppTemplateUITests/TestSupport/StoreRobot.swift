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

    func openMoreDestination(_ title: String) throws {
        try appRobot.activate(app.buttons["More"])
        try appRobot.activate(app.buttons[title])
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
