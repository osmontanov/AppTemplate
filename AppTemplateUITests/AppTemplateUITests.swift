import XCTest

nonisolated final class AppTemplateUITests: XCTestCase {
    @MainActor
    func testOnboardingRootIsVisible() {
        let app = launch(root: "onboarding")

        XCTAssertTrue(
            element(in: app, identifier: "screen.onboarding")
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testBrowseTabShowsBrowseScreen() {
        let app = launch(root: "main")

        activate(element(in: app, identifier: "tab.browse"))

        XCTAssertTrue(
            element(in: app, identifier: "screen.browse")
                .waitForExistence(timeout: 5)
        )
    }

    #if os(iOS)
    @MainActor
    func testTabIdentifiersSurviveIndependentRelaunches() {
        let identifiers = [
            "tab.home",
            "tab.browse",
            "tab.projects",
            "tab.settings"
        ]
        let first = launch(root: "main")

        for identifier in identifiers {
            XCTAssertTrue(
                element(in: first, identifier: identifier)
                    .waitForExistence(timeout: 5)
            )
        }
        first.terminate()

        let second = launch(root: "main")
        activate(element(in: second, identifier: "tab.browse"))

        XCTAssertTrue(
            element(in: second, identifier: "screen.browse")
                .waitForExistence(timeout: 5)
        )
    }
    #endif

    @MainActor
    func testNavigationGuideCanBeOpened() {
        let app = launch(root: "main")

        activate(
            element(
                in: app,
                identifier: "action.openNavigationGuide"
            )
        )

        XCTAssertTrue(
            element(in: app, identifier: "screen.navigationGuide")
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testBrowseOptionsCanBePresentedAndDismissed() {
        let app = launch(root: "main")

        activate(element(in: app, identifier: "tab.browse"))
        activate(
            element(in: app, identifier: "action.openBrowseOptions")
        )

        let browseOptions = element(
            in: app,
            identifier: "screen.browseOptions"
        )
        XCTAssertTrue(browseOptions.waitForExistence(timeout: 5))

        activate(
            element(in: app, identifier: "action.dismissBrowseOptions")
        )

        XCTAssertTrue(browseOptions.waitForNonExistence(timeout: 5))
    }

    #if os(macOS)
    @MainActor
    func testSettingsWindowCanBeOpened() {
        let app = launch(root: "main")

        activate(element(in: app, identifier: "tab.settings"))
        activate(
            element(in: app, identifier: "action.openSettingsWindow")
        )

        XCTAssertTrue(
            element(in: app, identifier: "screen.appSettings")
                .waitForExistence(timeout: 5)
        )
    }
    #endif

    @MainActor
    private func launch(root: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-test-root", root]
        app.launch()
        #if os(macOS)
        app.activate()
        let expectedRootIdentifier = root == "main"
            ? "screen.home"
            : "screen.\(root)"
        let expectedRoot = element(
            in: app,
            identifier: expectedRootIdentifier
        )
        if !expectedRoot.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        #endif
        return app
    }

    @MainActor
    private func element(
        in app: XCUIApplication,
        identifier: String
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func activate(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }
}
