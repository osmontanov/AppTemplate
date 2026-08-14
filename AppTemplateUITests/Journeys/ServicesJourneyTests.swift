import XCTest

nonisolated
final class ServicesJourneyTests: XCTestCase {
    @MainActor
    func testBasicServicesTryActualAndReset() throws {
        let robot = AppRobot()
        let app = robot.launch(.servicesBasic)
        let services = ServicesRobot(app: app)
        try services.runAppStateCommandsAndMaintenancePreservation()
        try services.runBasicLab(.userDefaults)
        try services.runBasicLab(.keychain)
        try services.runLocalDatabasePaginationLab()
        try services.runBasicLab(.remoteAPI)
        try services.runBasicLab(.localNotifications)
        try robot.assertScenarioScriptsExhausted(in: app)
    }
}
