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
        try robot.activate(try controlAfterScrolling("action.service.try"))
        try requireAfterScrolling("result.actual.success")
        try robot.activate(try controlAfterScrolling("action.service.reset"))
        try returnToCatalog()
    }

    func runLocalDatabasePaginationLab() throws {
        try openServices()
        try open(.localDatabase)
        try robot.activate(try controlAfterScrolling("action.service.try"))
        try requireAfterScrolling("result.actual.success")
        #if os(macOS)
        let loadMore = robot.control("action.services.local-database.load-more", in: app)
        XCTAssertTrue(loadMore.exists, "Expected the Local Database Load More action")
        app.typeKey(.tab, modifierFlags: [])
        loadMore.typeKey(.space, modifierFlags: [])
        #else
        try robot.activate(try controlAfterScrolling("action.services.local-database.load-more"))
        #endif
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
        if robot.element("screen.services.root", in: app).exists {
            return
        }
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
        let screen = destination.rawValue.replacingOccurrences(of: "service.", with: "screen.services.")
        let source = app.buttons.matching(identifier: destination.rawValue)
        XCTAssertEqual(source.count, 1, "Expected exactly one Services catalog destination")
        guard source.count == 1 else { return }
        XCTAssertTrue(source.firstMatch.isHittable, "Expected an actionable Services catalog destination")
        try robot.activate(source.firstMatch)
        _ = try robot.require(screen, in: app)
    }

    private func requireAfterScrolling(_ identifier: String) throws {
        for _ in 0..<6 {
            if robot.element(identifier, in: app).exists { return }
            scrollTowardLaterContent()
        }
        _ = try robot.require(identifier, in: app)
    }

    private func controlAfterScrolling(_ identifier: String) throws -> XCUIElement {
        #if os(macOS)
        for _ in 0..<12 {
            let control = robot.control(identifier, in: app)
            if control.exists, control.isHittable { return control }
            app.typeKey(.tab, modifierFlags: [])
        }
        let control = robot.control(identifier, in: app)
        XCTAssertTrue(
            control.exists && control.isHittable,
            "Expected keyboard traversal to reveal a hittable \(identifier) control"
        )
        return control
        #else
        for _ in 0..<6 {
            let control = robot.control(identifier, in: app)
            if control.exists, control.isHittable { return control }
            scrollTowardLaterContent()
        }
        return robot.control(identifier, in: app)
        #endif
    }

    private func scrollTowardLaterContent() {
        #if os(macOS)
        let windows = app.windows
        XCTAssertEqual(windows.count, 1, "Expected exactly one Services window")
        guard windows.count == 1 else { return }
        let anchors = app.descendants(matching: .any)
            .matching(identifier: "result.actual.success")
        XCTAssertEqual(anchors.count, 1, "Expected exactly one visible Services result anchor")
        guard anchors.count == 1 else { return }
        XCTAssertTrue(anchors.firstMatch.isHittable, "Expected a hittable Services result anchor")
        guard anchors.firstMatch.isHittable else { return }
        app.typeKey(.pageDown, modifierFlags: [])
        #else
        app.swipeUp()
        #endif
    }

    private func returnToCatalog() throws {
        #if os(macOS)
        let backActions = app.buttons.matching(
            NSPredicate(
                format: "identifier IN %@",
                ["BackButton", "chevron.backward"]
            )
        )
        XCTAssertEqual(
            backActions.count,
            1,
            "Expected exactly one semantic Services back action"
        )
        try robot.activate(backActions.firstMatch)
        #else
        try robot.activate(app.buttons["BackButton"])
        #endif
        _ = try robot.require("screen.services.root", in: app)
        #if os(macOS)
        let remainingBackActions = app.buttons.matching(
            NSPredicate(
                format: "identifier IN %@",
                ["BackButton", "chevron.backward"]
            )
        )
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in remainingBackActions.count == 0 },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settled], timeout: 5),
            .completed,
            "Expected the Services pop transition to remove its back action"
        )
        #endif
    }
}
