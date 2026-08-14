import XCTest

@MainActor
final class AppRobot {
    enum Scenario: String, CaseIterable {
        case guestStore = "guest-store"
        case protectedFavorite = "protected-favorite"
        case productReminder = "product-reminder"
        case servicesBasic = "services-basic"
        case accessibilitySmoke = "accessibility-smoke"
    }

    enum ContentSize: String {
        case standard
        case accessibilityExtraExtraExtraLarge
    }

    enum LayoutDirection: String {
        case leftToRight
        case rightToLeft
    }

    enum Locale: String {
        case system
        case arabic = "ar_SA"
    }

    struct Overrides {
        let contentSize: ContentSize
        let layoutDirection: LayoutDirection
        let locale: Locale
        let reduceMotion: Bool

        static let standard = Self(
            contentSize: .standard,
            layoutDirection: .leftToRight,
            locale: .system,
            reduceMotion: false
        )
        static let largestText = Self(
            contentSize: .accessibilityExtraExtraExtraLarge,
            layoutDirection: .leftToRight,
            locale: .system,
            reduceMotion: false
        )
        static let arabicRTL = Self(
            contentSize: .standard,
            layoutDirection: .rightToLeft,
            locale: .arabic,
            reduceMotion: false
        )
        static let reducedMotion = Self(
            contentSize: .standard,
            layoutDirection: .leftToRight,
            locale: .system,
            reduceMotion: true
        )
    }

    enum Localization: String {
        case standard
        case doubled
    }

    func launch(
        _ scenario: Scenario,
        overrides: Overrides = .standard,
        localization: Localization = .standard
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments: [String] = []
        #if os(macOS)
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        arguments += [
            "--ui-testing", "--ui-test-scenario", scenario.rawValue,
            "--ui-test-content-size", overrides.contentSize.rawValue,
            "--ui-test-layout-direction", overrides.layoutDirection.rawValue,
            "--ui-test-locale", overrides.locale.rawValue
        ]
        if overrides.reduceMotion {
            arguments.append("--ui-test-reduce-motion")
        }
        if overrides.locale == .arabic {
            arguments += ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        }
        if localization == .doubled {
            arguments += ["-NSDoubleLocalizedStrings", "YES"]
        }
        app.launchArguments = arguments
        app.launch()
        #if os(macOS)
        app.activate()
        #endif

        let expectedRoot = scenario == .accessibilitySmoke
            ? "screen.onboarding"
            : "screen.store.catalog"
        XCTAssertTrue(
            element(expectedRoot, in: app).waitForExistence(timeout: 15),
            "Expected scenario root \(expectedRoot)"
        )
        XCTAssertFalse(
            element("ui-test.script-status.failed", in: app).exists,
            "Scenario script failed during launch"
        )
        return app
    }

    func completeOnboardingIfNeeded(in app: XCUIApplication) throws {
        guard element("screen.onboarding", in: app).exists else { return }
        try activate(control("action.onboarding.finish", in: app))
        _ = try require("screen.store.catalog", in: app, timeout: 10)
    }

    func openSection(
        _ identifier: String,
        expecting destinationIdentifier: String,
        in app: XCUIApplication
    ) throws {
        try activate(control(identifier, in: app))
        _ = try require(destinationIdentifier, in: app)
    }

    func assertScenarioScriptsExhausted(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) throws {
        let failed = element("ui-test.script-status.failed", in: app)
        let exhausted = element("ui-test.script-status.exhausted", in: app)
        let pending = element("ui-test.script-status.pending", in: app)
        let terminal = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in failed.exists || exhausted.exists },
            object: nil
        )
        let result = XCTWaiter.wait(for: [terminal], timeout: timeout)
        if failed.exists {
            XCTFail("The fail-closed UI script rejected an unexpected request")
            return
        }
        guard result == .completed, exhausted.exists else {
            XCTFail(pending.exists
                ? "The UI script remained pending"
                : "The UI script did not publish a terminal status")
            return
        }
    }

    func assertScenarioScriptsHealthy(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            element("ui-test.script-status.failed", in: app).exists,
            "The fail-closed UI script rejected an unexpected request",
            file: file,
            line: line
        )
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    func control(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    func require(
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
