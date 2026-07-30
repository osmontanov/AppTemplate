import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func continueOpensMainAndReplaysTheReceivingScene() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let viewModel = AuthenticationViewModel(
            router: FlowRouter(appFlowRouter: appFlowRouter)
        )

        viewModel.continueToApp()

        #expect(appFlowRouter.flow == .main)
        #expect(appFlowRouter.transition.pendingIntentAction == .replay)
    }

    @Test
    func cancellationPublishesFreshAuthenticationDiscardTransition() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let flowRouter = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = AuthenticationViewModel(router: flowRouter)
        let previousID = appFlowRouter.transition.id

        viewModel.cancelAuthentication()

        #expect(appFlowRouter.flow == .authentication)
        #expect(appFlowRouter.transition.id != previousID)
        #expect(appFlowRouter.transition.pendingIntentAction == .discard)
    }

    @Test
    func authenticationHelpUsesAuthenticationFlowRouter() {
        let flowRouter = FlowRouter()
        let viewModel = AuthenticationViewModel(router: flowRouter)

        viewModel.openHelp()

        #expect(flowRouter.path.count == 1)
    }

    @Test
    func authenticationFlowAndScreenCanBeConstructed() {
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let flowRouter = FlowRouter(appFlowRouter: appFlowRouter)

        _ = AuthenticationView(router: flowRouter)
        _ = AuthenticationFlowView(router: flowRouter)
    }
}
