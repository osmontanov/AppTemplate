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
    func flowRouterDelegatesEverySemanticCommandAndResult() {
        let coordinator = AppFlowCoordinatorSpy()
        coordinator.completeOnboardingResult = .applied(
            flow: .authentication,
            didTransition: false
        )
        coordinator.restartOnboardingResult = .applied(
            flow: .onboarding,
            didTransition: true
        )
        coordinator.signInResult = .rejected(.saveFailed)
        coordinator.signOutResult = .applied(
            flow: .authentication,
            didTransition: true
        )
        coordinator.setMaintenanceEnabledResult = .applied(
            flow: .maintenance,
            didTransition: true
        )
        let router = FlowRouter(appFlowCoordinator: coordinator)

        #expect(
            router.completeOnboarding()
                == .applied(flow: .authentication, didTransition: false)
        )
        #expect(
            router.restartOnboarding()
                == .applied(flow: .onboarding, didTransition: true)
        )
        #expect(router.signIn() == .rejected(.saveFailed))
        #expect(
            router.signOut()
                == .applied(flow: .authentication, didTransition: true)
        )
        #expect(
            router.setMaintenanceEnabled(true)
                == .applied(flow: .maintenance, didTransition: true)
        )

        #expect(coordinator.commands == [
            .completeOnboarding,
            .restartOnboarding,
            .signIn,
            .signOut,
            .setMaintenanceEnabled(true)
        ])
    }
}

nonisolated
private enum FirstTestRoute: String, NavigationRoute {
    case details
}

nonisolated
private enum SecondTestRoute: String, NavigationRoute {
    case guide
}
