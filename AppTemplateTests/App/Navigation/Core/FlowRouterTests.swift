import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct FlowRouterTests {
    @Test
    func oneRouterStoresDifferentScreenRouteTypes() {
        let router = makeTestFlowRouter()

        router.push(FirstTestRoute.details)
        router.push(SecondTestRoute.guide)

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func popAndPopToRootAreSafe() {
        let router = makeTestFlowRouter()

        router.pop()
        #expect(router.path.isEmpty)

        router.push(FirstTestRoute.details)
        router.push(SecondTestRoute.guide)
        router.pop()
        #expect(router.path.count == 1)

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test
    func routersKeepIndependentHistories() {
        let first = makeTestFlowRouter()
        let second = makeTestFlowRouter()

        first.push(FirstTestRoute.details)

        #expect(first.path.count == 1)
        #expect(second.path.isEmpty)
    }

    @Test
    func existentialContractCanPushAConcreteScreenRoute() {
        let concrete = makeTestFlowRouter()
        let router: any IFlowRouter = concrete

        router.push(FirstTestRoute.details)

        #expect(concrete.path.count == 1)
    }

    @Test
    func flowRouterDelegatesEveryGlobalCommand() {
        let coordinator = AppFlowCoordinatorSpy()
        let router = FlowRouter(appFlowCoordinator: coordinator)

        router.setFlow(.authentication)
        router.completeOnboarding()
        router.restartOnboarding()
        router.signIn()
        router.signOut()
        router.setMaintenanceEnabled(true)
        router.setMaintenanceEnabled(false)

        #expect(coordinator.commands == [
            .setFlow(.authentication),
            .completeOnboarding,
            .restartOnboarding,
            .signIn,
            .signOut,
            .setMaintenanceEnabled(true),
            .setMaintenanceEnabled(false)
        ])
    }

    @Test
    func compositeContractSupportsLocalAndGlobalNavigation() {
        let coordinator = AppFlowCoordinatorSpy()
        let concrete = FlowRouter(appFlowCoordinator: coordinator)
        let router: any IRouter = concrete

        router.push(TestRoute.first)
        router.setFlow(.main)

        #expect(concrete.path.count == 1)
        #expect(coordinator.commands == [.setFlow(.main)])
    }
}

nonisolated
private enum TestRoute: String, NavigationRoute {
    case first
}

nonisolated
private enum FirstTestRoute: String, NavigationRoute {
    case details
}

nonisolated
private enum SecondTestRoute: String, NavigationRoute {
    case guide
}
