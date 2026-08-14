import XCTest

nonisolated
final class AppTemplateUITests: XCTestCase {
    @MainActor
    func testOnboardingRootIsVisible() throws {
        let app = launch(scenario: "accessibility-smoke")
        _ = try require("screen.onboarding", in: app)
    }

    @MainActor
    func testGuestShellUsesStoreAndServicesIdentifiers() throws {
        let app = launch(scenario: "guest-store")
        _ = try require("screen.store.catalog", in: app, timeout: 10)
        _ = try require("tab.store", in: app)
        _ = try require("tab.services", in: app)
        XCTAssertFalse(element("ui-test.script-status.failed", in: app).exists)
    }

    @MainActor
    private func launch(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        #if os(macOS)
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-scenario", scenario
        ]
        #else
        app.launchArguments = [
            "--ui-testing", "--ui-test-scenario", scenario
        ]
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        #endif
        return app
    }

    @MainActor
    private func require(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        let value = element(identifier, in: app)
        return try XCTUnwrap(
            value.waitForExistence(timeout: timeout) ? value : nil,
            "Expected \(identifier)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
}
