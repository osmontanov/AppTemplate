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
}

private nonisolated enum FirstTestRoute: String, NavigationRoute {
    case details
}

private nonisolated enum SecondTestRoute: String, NavigationRoute {
    case guide
}
