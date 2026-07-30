import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct FlowRouterTests {
    @Test
    func oneRouterStoresDifferentScreenRouteTypes() {
        let router = FlowRouter()

        router.push(FirstTestRoute.details)
        router.push(SecondTestRoute.guide)

        #expect(router.path.count == 2)
        #expect(router.path.codable != nil)
    }

    @Test
    func popAndPopToRootAreSafe() {
        let router = FlowRouter()

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
        let first = FlowRouter()
        let second = FlowRouter()

        first.push(FirstTestRoute.details)

        #expect(first.path.count == 1)
        #expect(second.path.isEmpty)
    }

    @Test
    func existentialContractCanPushAConcreteScreenRoute() {
        let concrete = FlowRouter()
        let router: any IFlowRouter = concrete

        router.push(FirstTestRoute.details)

        #expect(concrete.path.count == 1)
    }

    @Test
    func flowRouterDelegatesGlobalFlowChanges() {
        let appFlowRouter = AppFlowRouterSpy()
        let router = FlowRouter(appFlowRouter: appFlowRouter)

        router.setFlow(.authentication)

        #expect(appFlowRouter.receivedFlows == [.authentication])
    }

    @Test
    func compositeContractSupportsLocalAndGlobalNavigation() {
        let appFlowRouter = AppFlowRouterSpy()
        let concrete = FlowRouter(appFlowRouter: appFlowRouter)
        let router: any IRouter = concrete

        router.push(TestRoute.first)
        router.setFlow(.main)

        #expect(concrete.path.count == 1)
        #expect(appFlowRouter.receivedFlows == [.main])
    }
}

@MainActor
private final class AppFlowRouterSpy: IAppFlowRouter {
    private(set) var receivedFlows: [AppFlow] = []

    func setFlow(_ flow: AppFlow) {
        receivedFlows.append(flow)
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
