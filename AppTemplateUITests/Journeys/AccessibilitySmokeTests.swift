import XCTest

nonisolated
final class AccessibilitySmokeTests: XCTestCase {
    @MainActor
    func testLargestTextKeepsStorePrimaryActionsReachable() throws {
        try runStoreSmoke(overrides: .largestText)
    }

    @MainActor
    func testDoubledStringsKeepStorePrimaryActionsReachable() throws {
        try runStoreSmoke(localization: .doubled)
    }

    @MainActor
    func testArabicRTLKeepsLocalizedStoreReachable() throws {
        let robot = AppRobot()
        let app = robot.launch(.accessibilitySmoke, overrides: .arabicRTL)
        try robot.completeOnboardingIfNeeded(in: app)
        let store = StoreRobot(app: app)
        try store.assertLocalizedPriceReachable()
        try robot.assertScenarioScriptsExhausted(in: app)
        try store.assertPrimaryActionsReachable(allowsMacOSToolbarOverflow: true)
    }

    @MainActor
    func testReduceMotionKeepsStorePrimaryActionsReachable() throws {
        try runStoreSmoke(overrides: .reducedMotion)
    }

    #if os(macOS)
    @MainActor
    func testMacOSKeyboardAndFocusSmoke() throws {
        try runStoreSmoke()
    }
    #else
    @MainActor
    func testAdaptiveIOSLayoutSmoke() throws {
        try runStoreSmoke()
    }
    #endif

    @MainActor
    private func runStoreSmoke(
        overrides: AppRobot.Overrides = .standard,
        localization: AppRobot.Localization = .standard
    ) throws {
        let robot = AppRobot()
        let app = robot.launch(
            .accessibilitySmoke,
            overrides: overrides,
            localization: localization
        )
        try robot.completeOnboardingIfNeeded(in: app)
        try StoreRobot(app: app).assertPrimaryActionsReachable()
        try robot.assertScenarioScriptsExhausted(in: app)
    }
}
