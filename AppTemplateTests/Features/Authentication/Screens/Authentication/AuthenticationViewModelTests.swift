import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func continueRequestsSemanticSignIn() {
        let coordinator = AppFlowCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.continueToApp()

        #expect(coordinator.commands == [.signIn])
    }

    @Test
    func cancellationRemainsARawAuthenticationReset() {
        let coordinator = AppFlowCoordinatorSpy()
        let viewModel = AuthenticationViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.cancelAuthentication()

        #expect(coordinator.commands == [.setFlow(.authentication)])
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
