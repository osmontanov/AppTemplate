import Testing
@testable import AppTemplate

struct UITestScenarioTests {
    @Test(arguments: UITestScenario.Name.allCases)
    func catalogNamesRoundTripToFailClosedScenarios(_ name: UITestScenario.Name) throws {
        let scenario = try UITestScenario.named(name.rawValue)
        #expect(scenario.id == name)
        #expect(scenario.networkPolicy == .failClosed)
    }

    @Test
    func unknownNameIsRejected() {
        #expect(throws: UITestConfigurationError.unknownScenario("secret")) {
            try UITestScenario.named("secret")
        }
    }
}
