import XCTest

@MainActor
struct ServicesRobot {
    enum Destination: String, CaseIterable {
        case appState = "service.app-state"
        case appInfo = "service.app-info"
        case userDefaults = "service.user-defaults"
        case keychain = "service.keychain"
        case localDatabase = "service.local-database"
        case remoteAPI = "service.remote-api"
        case localNotifications = "service.local-notifications"
    }

    let app: XCUIApplication
    private let robot = AppRobot()

    func runBasicLab(_ destination: Destination) throws {
        try openServices()
        try open(destination)
        try robot.activate(robot.control("action.service.try", in: app))
        try requireAfterScrolling("result.actual.success")
        try robot.activate(try controlAfterScrolling("action.service.reset"))
        try returnToCatalog()
    }

    func runLocalDatabasePaginationLab() throws {
        try openServices()
        try open(.localDatabase)
        try robot.activate(try controlAfterScrolling("action.service.try"))
        try requireAfterScrolling("result.actual.success")
        try robot.activate(try controlAfterScrolling("action.services.local-database.load-more"))
        try requireAfterScrolling("result.actual.success")
        try robot.activate(try controlAfterScrolling("action.service.reset"))
        try returnToCatalog()
    }

    func runAppStateCommandsAndMaintenancePreservation() throws {
        try openServices()
        try open(.appState)

        try robot.activate(try controlAfterScrolling("action.services.app-state.open-app-info"))
        _ = try robot.require("screen.services.app-info", in: app)
        try returnToCatalog()

        try open(.appState)
        try robot.activate(try controlAfterScrolling("action.services.app-state.open-store"))
        _ = try robot.require("screen.store.catalog", in: app)

        try robot.openSection(
            "tab.services",
            expecting: "screen.services.app-state",
            in: app
        )
        try returnToCatalog()
        try assertDestinationWiresAndOpen(.appState)
        try robot.activate(try controlAfterScrolling("action.services.app-state.maintenance"))
        try robot.activate(robot.control("action.services.app-state.confirm", in: app))
        _ = try robot.require("screen.maintenance", in: app)

        try robot.activate(robot.control("action.maintenance.return", in: app))
        _ = try robot.require("screen.services.app-state", in: app)
        try returnToCatalog()
    }

    func openServices() throws {
        try robot.openSection(
            "tab.services",
            expecting: "screen.services.root",
            in: app
        )
    }

    func assertDestinationWiresAndOpen(_ destination: Destination) throws {
        for candidate in Destination.allCases {
            _ = try robot.require(candidate.rawValue, in: app)
        }
        try open(destination)
    }

    private func open(_ destination: Destination) throws {
        try robot.activate(robot.control(destination.rawValue, in: app))
        let screen = destination.rawValue.replacingOccurrences(of: "service.", with: "screen.services.")
        _ = try robot.require(screen, in: app)
    }

    private func requireAfterScrolling(_ identifier: String) throws {
        for _ in 0..<6 {
            if robot.element(identifier, in: app).exists { return }
            app.swipeUp()
        }
        _ = try robot.require(identifier, in: app)
    }

    private func controlAfterScrolling(_ identifier: String) throws -> XCUIElement {
        for _ in 0..<6 {
            let control = robot.control(identifier, in: app)
            if control.exists, control.isHittable { return control }
            app.swipeUp()
        }
        return robot.control(identifier, in: app)
    }

    private func returnToCatalog() throws {
        #if os(macOS)
        app.typeKey("[", modifierFlags: .command)
        #else
        try robot.activate(app.buttons["BackButton"])
        #endif
        _ = try robot.require("screen.services.root", in: app)
    }
}
