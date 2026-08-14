import XCTest

@MainActor
struct ServicesRobot {
    enum Destination: String, CaseIterable {
        case appState = "app-state"
        case appInfo = "app-info"
        case userDefaults = "user-defaults"
        case keychain = "keychain"
        case localDatabase = "local-database"
        case remoteAPI = "remote-api"
        case localNotifications = "local-notifications"
    }

    let app: XCUIApplication
    let appRobot: AppRobot

    func openServices() throws {
        try appRobot.openSection(
            "tab.services",
            expecting: "screen.services.root"
        )
    }

    func assertDestinationWiresAndOpen(_ destination: Destination) throws {
        for candidate in Destination.allCases {
            _ = try appRobot.require("route.services.\(candidate.rawValue)")
        }
        try appRobot.activate(
            appRobot.element("route.services.\(destination.rawValue)")
        )
        _ = try appRobot.require("screen.services.\(destination.rawValue)")
    }

    func scheduleImmediateAndRequireActual() throws {
        try appRobot.activate(
            appRobot.element("action.services.notifications.schedule-immediate")
        )
        _ = try XCTUnwrap(
            app.staticTexts["Scheduled a Services lab notification."]
                .waitForExistence(timeout: 5)
                ? app.staticTexts["Scheduled a Services lab notification."] : nil,
            "Actual did not report the scripted notification result"
        )
    }

    func resetDemoData() throws {
        try appRobot.activate(app.buttons["Reset Demo Data"])
        _ = try XCTUnwrap(
            app.staticTexts["Reset only Services lab categories and notifications."]
                .waitForExistence(timeout: 5)
                ? app.staticTexts["Reset only Services lab categories and notifications."] : nil,
            "Reset did not publish its documented scope"
        )
    }
}
