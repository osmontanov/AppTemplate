import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func continueOpensMainAndReplaysTheReceivingScene() {
        let coordinator = makeTestAppFlowCoordinator(
            visibleFlow: .authentication
        )
        let appFlowRouter = coordinator.appFlowRouter
        let viewModel = AuthenticationViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.continueToApp()

        #expect(appFlowRouter.flow == .main)
        #expect(appFlowRouter.transition.pendingIntentAction == .replay)
    }

    @Test
    func cancellationPublishesFreshAuthenticationDiscardTransition() {
        let coordinator = makeTestAppFlowCoordinator(
            visibleFlow: .authentication
        )
        let appFlowRouter = coordinator.appFlowRouter
        let flowRouter = FlowRouter(appFlowCoordinator: coordinator)
        let viewModel = AuthenticationViewModel(router: flowRouter)
        let previousID = appFlowRouter.transition.id

        viewModel.cancelAuthentication()

        #expect(appFlowRouter.flow == .authentication)
        #expect(appFlowRouter.transition.id != previousID)
        #expect(appFlowRouter.transition.pendingIntentAction == .discard)
    }

    @Test
    func authenticationHelpUsesAuthenticationFlowRouter() {
        let flowRouter = makeTestFlowRouter()
        let viewModel = AuthenticationViewModel(router: flowRouter)

        viewModel.openHelp()

        #expect(flowRouter.path.count == 1)
    }

    @Test
    func authenticationFlowAndScreenCanBeConstructed() {
        let coordinator = makeTestAppFlowCoordinator(
            visibleFlow: .authentication
        )
        let flowRouter = FlowRouter(appFlowCoordinator: coordinator)

        _ = AuthenticationView(router: flowRouter)
        _ = AuthenticationFlowView(router: flowRouter)
    }
}
