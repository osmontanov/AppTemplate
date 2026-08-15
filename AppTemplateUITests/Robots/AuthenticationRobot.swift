import XCTest

@MainActor
struct AuthenticationRobot {
    let app: XCUIApplication
    private let robot = AppRobot()

    func requireReady() throws {
        _ = try robot.require("authentication.username", in: app)
        _ = try robot.require("authentication.password", in: app)
    }

    func submitDemoAccount() throws {
        try robot.activate(robot.control("action.authentication.demo-credentials", in: app))
        try robot.activate(robot.control("action.authentication.sign-in", in: app))
    }

    func submitInvalidAccount() throws {
        let username = try robot.require("authentication.username", in: app)
        try robot.activate(username)
        username.typeText("24680")
        XCTAssertEqual(username.value as? String, "24680")
        let password = try robot.require("authentication.password", in: app)
        try robot.activate(password)
        password.typeText("13579")
        XCTAssertEqual((password.value as? String)?.count, 5)
        try robot.activate(robot.control("action.authentication.sign-in", in: app))
        _ = try robot.require("result.actual.failure", in: app)
        try requireReady()
    }

    func cancel() throws {
        try robot.activate(robot.control("action.cancel", in: app))
    }
}
