import XCTest

@MainActor
struct StoreRobot {
    let app: XCUIApplication
    private let robot = AppRobot()

    func openProduct() throws {
        try openProduct("Accessibility Phone")
    }

    func openProduct(_ title: String) throws {
        let button = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", title))
            .firstMatch
        try robot.activate(button)
        _ = try robot.require("screen.store.product", in: app)
        _ = try robot.require("action.store.add-to-cart", in: app)
    }

    func openProductDeepLink(id: Int) throws {
        XCTAssertEqual(id, 1, "The frozen guest scenario scripts product 1")
        try activateDeepLinkHarness("ui-test.action.open-product-link")
        _ = try robot.require("screen.store.product", in: app)
        _ = try robot.require("action.store.add-to-cart", in: app)
    }

    func openProtectedFavoritesDeepLink() throws {
        let seededProduct = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Protected Phone"))
            .firstMatch
        XCTAssertTrue(seededProduct.waitForExistence(timeout: 5))
        try activateDeepLinkHarness("ui-test.action.open-favorites-link")
        _ = try robot.require("screen.authentication", in: app)
    }

    func loadNextCatalogPage() throws {
        try robot.activate(robot.control("action.store.load-more", in: app))
        let product = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Offline Phone Three"))
            .firstMatch
        XCTAssertTrue(product.waitForExistence(timeout: 5))
    }

    func openReviews() throws {
        try robot.activate(robot.control("action.store.reviews", in: app))
        _ = try robot.require("screen.store.reviews", in: app)
    }

    func navigateBack() throws {
        #if os(macOS)
        app.typeKey("[", modifierFlags: .command)
        #else
        try robot.activate(app.buttons["BackButton"])
        #endif
    }

    func addCurrentProductToCart() throws {
        try robot.activate(robot.control("action.store.add-to-cart", in: app))
        _ = try robot.require("result.actual.success", in: app)
    }

    func favorite() throws {
        try robot.activate(robot.control("action.store.favorite", in: app))
    }

    func authenticateWithDemoAccount() throws {
        try AuthenticationRobot(app: app).submitDemoAccount()
        _ = try robot.require("screen.store.product", in: app, timeout: 10)
        XCTAssertTrue(robot.element("screen.authentication", in: app)
            .waitForNonExistence(timeout: 5))
    }

    func signOut() throws {
        try robot.activate(robot.control("action.store.sign-out", in: app))
        _ = try robot.require("screen.store.profile", in: app)
    }

    func assertPrimaryActionsReachable() throws {
        for identifier in ["action.store.search", "action.store.filter", "action.store.cart"] {
            let action = try robot.require(identifier, in: app)
            XCTAssertTrue(action.isHittable, "Expected reachable \(identifier)")
        }
        let more = robot.element("action.store.more", in: app)
        let profile = robot.element("action.store.profile", in: app)
        XCTAssertTrue(
            more.waitForExistence(timeout: 2) || profile.waitForExistence(timeout: 2),
            "Favorites and Profile require either direct actions or More"
        )
    }

    func assertLocalizedPriceReachable() throws {
        let product = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Accessibility Phone"))
            .firstMatch
        XCTAssertTrue(product.waitForExistence(timeout: 5))
        XCTAssertNotEqual(product.label, "Accessibility Phone")
    }

    func openCurrentProductReminder() throws {
        try robot.activate(robot.control("action.store.reminder", in: app))
        _ = try robot.require("screen.store.product-reminder", in: app)
    }

    func scheduleQuickReminder() throws {
        try robot.activate(robot.control("action.product-reminder.schedule", in: app))
        _ = try robot.require("result.actual.success", in: app)
    }

    func cancelCurrentProductReminder() throws {
        try robot.activate(robot.control("action.product-reminder.cancel", in: app))
        _ = try robot.require("status.product-reminder.not-scheduled", in: app)
    }

    func openToolbarDestination(_ identifier: String) throws {
        let direct = robot.control(identifier, in: app)
        if direct.waitForExistence(timeout: 2) {
            try robot.activate(direct)
            return
        }
        try robot.activate(robot.control("action.store.more", in: app))
        try robot.activate(robot.control(identifier, in: app))
    }

    func requireFavorite(_ title: String) throws {
        _ = try robot.require("screen.store.favorites", in: app)
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
    }

    func openAccountAndSignOut() throws {
        let button = robot.control("action.store.profile.account", in: app)
        let account = button.waitForExistence(timeout: 2)
            ? button
            : app.radioButtons.matching(identifier: "action.store.profile.account").firstMatch
        try robot.activate(account)
        try signOut()
        XCTAssertTrue(robot.element("action.store.sign-out", in: app)
            .waitForNonExistence(timeout: 5))
    }

    func completeCheckout() throws {
        _ = try robot.require("screen.store.cart", in: app)
        try beginCheckout()
        try robot.activate(robot.control("action.store.checkout.place", in: app))
        _ = try robot.require("screen.store.cart", in: app)
        _ = try robot.require("result.actual.failure", in: app)

        try beginCheckout()
        try robot.activate(robot.control("action.store.checkout.place", in: app))
        try robot.activate(robot.control("action.store.checkout.done", in: app))
        _ = try robot.require("screen.store.cart", in: app)
    }

    private func beginCheckout() throws {
        try robot.activate(robot.control("action.store.checkout", in: app))
        _ = try robot.require("screen.store.checkout", in: app)
        try robot.activate(robot.control("action.store.checkout.continue", in: app))
    }

    private func activateDeepLinkHarness(_ identifier: String) throws {
        let control = try robot.require(identifier, in: app)
        XCTAssertTrue(control.isHittable, "Expected actionable \(identifier)")
        try robot.activate(control)
    }
}
