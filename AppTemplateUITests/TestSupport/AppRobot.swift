import XCTest

@MainActor
struct AppRobot {
    let app: XCUIApplication

    static func launchGuestStore() throws -> AppRobot {
        let app = XCUIApplication()
        #if os(macOS)
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-scenario", "guest-store"
        ]
        #else
        app.launchArguments = [
            "--ui-testing", "--ui-test-scenario", "guest-store"
        ]
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        #endif
        let robot = AppRobot(app: app)
        _ = try robot.require("screen.store.catalog", timeout: 10)
        XCTAssertFalse(robot.element("ui-test.script-status.failed").exists)
        return robot
    }

    func store() -> StoreRobot {
        StoreRobot(app: app, appRobot: self)
    }

    func openSection(
        _ identifier: String,
        expecting destinationIdentifier: String
    ) throws {
        try activate(element(identifier))
        _ = try require(destinationIdentifier)
    }

    func waitForScriptExhaustion(timeout: TimeInterval = 10) throws {
        let failed = element("ui-test.script-status.failed")
        let exhausted = element("ui-test.script-status.exhausted")
        XCTAssertTrue(
            exhausted.waitForExistence(timeout: timeout),
            failed.exists
                ? "The fail-closed UI script rejected an unexpected request"
                : "The UI script remained pending"
        )
        XCTAssertFalse(failed.exists)
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    func require(
        _ identifier: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        let value = element(identifier)
        return try XCTUnwrap(
            value.waitForExistence(timeout: timeout) ? value : nil,
            "Expected \(identifier)",
            file: file,
            line: line
        )
    }

    func activate(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let value = try XCTUnwrap(
            element.waitForExistence(timeout: 5) ? element : nil,
            "Expected an actionable element",
            file: file,
            line: line
        )
        #if os(macOS)
        value.click()
        #else
        value.tap()
        #endif
    }
}
