import XCTest

nonisolated
final class AppTemplateUITests: XCTestCase {
    private enum Scenario: String {
        case accessibilitySmoke = "accessibility-smoke"
        case servicesBasic = "services-basic"
    }

    @MainActor
    func testOnboardingRootIsVisible() throws {
        let app = try launch(
            scenario: .accessibilitySmoke,
            expectedRootIdentifier: "screen.onboarding"
        )

        XCTAssertTrue(element(in: app, identifier: "screen.onboarding").exists)
    }

    @MainActor
    func testBrowseTabShowsBrowseScreen() throws {
        let app = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )

        try activateTab(
            in: app,
            identifier: "tab.browse",
            destinationIdentifier: "screen.browse"
        )
    }

    #if os(iOS)
    @MainActor
    func testTabIdentifiersSurviveIndependentRelaunches() throws {
        let identifiers = [
            "tab.home",
            "tab.browse",
            "tab.projects",
            "tab.settings"
        ]
        let first = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )

        for identifier in identifiers {
            _ = try requireExistence(
                element(in: first, identifier: identifier)
            )
        }
        first.terminate()

        let second = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )
        try activateTab(
            in: second,
            identifier: "tab.browse",
            destinationIdentifier: "screen.browse"
        )
    }
    #endif

    @MainActor
    func testNavigationGuideCanBeOpened() throws {
        let app = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )

        try activate(
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
    func testBrowseOptionsCanBePresentedAndDismissed() throws {
        let app = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )

        try activateTab(
            in: app,
            identifier: "tab.browse",
            destinationIdentifier: "screen.browse"
        )
        try activate(
            element(in: app, identifier: "action.openBrowseOptions")
        )

        let browseOptions = try requireExistence(
            element(in: app, identifier: "screen.browseOptions")
        )

        try activate(
            element(in: app, identifier: "action.dismissBrowseOptions")
        )

        XCTAssertTrue(browseOptions.waitForNonExistence(timeout: 5))
    }

    #if os(macOS)
    @MainActor
    func testSettingsWindowCanBeOpened() throws {
        let app = try launch(
            scenario: .servicesBasic,
            expectedRootIdentifier: "screen.home"
        )

        try activate(element(in: app, identifier: "tab.settings"))
        try activate(
            element(in: app, identifier: "action.openSettingsWindow")
        )

        XCTAssertTrue(
            element(in: app, identifier: "screen.appSettings")
                .waitForExistence(timeout: 5)
        )
    }
    #endif

    @MainActor
    private func launch(
        scenario: Scenario,
        expectedRootIdentifier: String
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        #if os(macOS)
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-scenario", scenario.rawValue
        ]
        #else
        app.launchArguments = [
            "--ui-testing", "--ui-test-scenario", scenario.rawValue
        ]
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        #endif

        let expectedRoot = element(
            in: app,
            identifier: expectedRootIdentifier
        )
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 1) {
            let menuBar = try requireExistence(app.menuBars.firstMatch)
            let fileMenuBarItem = try requireExistence(
                menuBar.menuBarItems.element(boundBy: 2)
            )
            if !app.windows.firstMatch.exists {
                fileMenuBarItem.click()

                let fileMenu = try requireExistence(
                    fileMenuBarItem.menus.firstMatch
                )
                let newWindowActions = fileMenu.menuItems.matching(
                    identifier: "menuAction:"
                )
                let newWindowAction = try requireSingleElement(
                    newWindowActions,
                    description: "File-menu window action"
                )
                let actionToInvoke = try XCTUnwrap(
                    app.windows.firstMatch.exists ? nil : newWindowAction,
                    "Initial window appeared while resolving the "
                        + "File-menu bootstrap action"
                )
                actionToInvoke.click()
            }
        }
        #endif

        _ = try requireExistence(expectedRoot)
        let failedMarker = element(
            in: app,
            identifier: "ui-test.script-status.failed"
        )
        XCTAssertFalse(failedMarker.exists, "UI-test script failed before readiness")
        let exhaustedMarker = element(
            in: app,
            identifier: "ui-test.script-status.exhausted"
        )
        XCTAssertTrue(
            exhaustedMarker.waitForExistence(timeout: 5),
            failedMarker.exists
                ? "UI-test script entered failed state"
                : "UI-test script remained pending"
        )
        #if os(macOS)
        _ = try requireSingleElement(
            app.windows,
            description: "initial application window"
        )
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
    private func requireExistence(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        try XCTUnwrap(
            element.waitForExistence(timeout: timeout) ? element : nil,
            "Expected UI element to exist",
            file: file,
            line: line
        )
    }

    @MainActor
    private func requireSingleElement(
        _ query: XCUIElementQuery,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        let count = query.count
        return try XCTUnwrap(
            count == 1 ? query.firstMatch : nil,
            "Expected exactly one \(description), found \(count)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func activate(_ element: XCUIElement) throws {
        let element = try requireExistence(element)
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    @MainActor
    private func activateTab(
        in app: XCUIApplication,
        identifier: String,
        destinationIdentifier: String
    ) throws {
        try activate(element(in: app, identifier: identifier))

        let destination = element(
            in: app,
            identifier: destinationIdentifier
        )
        if !destination.waitForExistence(timeout: 2) {
            try activate(element(in: app, identifier: identifier))
        }

        _ = try requireExistence(
            element(in: app, identifier: destinationIdentifier)
        )
    }
}
