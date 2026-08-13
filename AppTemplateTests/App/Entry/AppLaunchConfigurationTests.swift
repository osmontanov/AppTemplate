import Testing
@testable import AppTemplate

struct AppLaunchConfigurationTests {
    @Test(arguments: UITestScenario.Name.allCases)
    func parsesEveryStableScenarioName(_ name: UITestScenario.Name) throws {
        let scenario = try UITestScenario.named(name.rawValue)
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-testing", "--ui-test-scenario", name.rawValue
        ]) == .uiTesting(scenario))
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "--ui-test-scenario", name.rawValue, "--ui-testing"
        ]) == .uiTesting(scenario))
    }

    @Test
    func unrelatedProcessArgumentsAreIgnored() throws {
        let scenario = try UITestScenario.named("guest-store")
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "-NSDocumentRevisionsDebugMode", "YES",
            "--ui-testing", "--ui-test-scenario", "guest-store"
        ]) == .uiTesting(scenario))
        #expect(AppLaunchConfiguration(arguments: ["AppTemplate", "-SomeFlag"]) == .live)
    }

    #if os(macOS)
    @Test
    func supportsOneLeadingPersistenceIsolationPair() throws {
        let scenario = try UITestScenario.named("services-basic")
        #expect(AppLaunchConfiguration(arguments: [
            "AppTemplate", "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-scenario", "services-basic"
        ]) == .uiTesting(scenario))
    }

    @Test(arguments: [
        ["AppTemplate", "-ApplePersistenceIgnoreState", "NO", "--ui-testing", "--ui-test-scenario", "services-basic"],
        ["AppTemplate", "--ui-testing", "--ui-test-scenario", "services-basic", "-ApplePersistenceIgnoreState", "YES"],
        ["AppTemplate", "-ApplePersistenceIgnoreState", "YES", "-ApplePersistenceIgnoreState", "YES", "--ui-testing", "--ui-test-scenario", "services-basic"]
    ])
    func malformedPersistenceIsolationNeverProducesValidUITesting(_ arguments: [String]) {
        guard case .invalidUITesting = AppLaunchConfiguration(arguments: arguments) else {
            Issue.record("Malformed persistence isolation produced a valid launch")
            return
        }
    }
    #endif

    @Test(arguments: [
        (["AppTemplate", "--ui-testing"], UITestConfigurationError.missingScenario),
        (["AppTemplate", "--ui-test-scenario", "guest-store"], .missingScenario),
        (["AppTemplate", "--ui-testing", "--ui-testing", "--ui-test-scenario", "guest-store"], .duplicateOption("--ui-testing")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "guest-store", "--ui-test-scenario", "services-basic"], .duplicateOption("--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-root", "main"], .unknownOption("--ui-test-root")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "guest-store", "--ui-surprise"], .unknownOption("--ui-surprise")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario"], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", ""], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "--other"], .malformedValue(option: "--ui-test-scenario")),
        (["AppTemplate", "--ui-testing", "--ui-test-scenario", "not-catalogued"], .unknownScenario("not-catalogued"))
    ])
    func uiTestIntentNeverFallsBackToLive(
        _ arguments: [String],
        _ error: UITestConfigurationError
    ) {
        #expect(AppLaunchConfiguration(arguments: arguments) == .invalidUITesting(error))
    }

    @Test
    func testLaunchesAlwaysUseEphemeralNavigationPersistence() throws {
        #expect(AppLaunchConfiguration.live.sceneNavigationPersistencePolicy == .restored)
        #expect(AppLaunchConfiguration.uiTesting(try .named("guest-store")).sceneNavigationPersistencePolicy == .ephemeral)
        #expect(AppLaunchConfiguration.invalidUITesting(.missingScenario).sceneNavigationPersistencePolicy == .ephemeral)
    }
}
