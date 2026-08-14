import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func continueUsesDedicatedLegacyActionsWithoutChangingRoot() {
        let coordinator = makeTestAppFlowCoordinator()
        let cancellation = AuthenticationCancellationSpy()
        let actions = AuthenticationActionsSpy()
        let viewModel = AuthenticationViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator),
            authenticationActions: actions,
            authenticationCancellation: cancellation
        )

        viewModel.continueToApp()

        #expect(actions.signInCount == 1)
        #expect(coordinator.appFlowRouter.flow == .onboarding)
        #expect(cancellation.callCount == 0)
    }

    @Test
    func cancellationCallsOnlyTheSceneCollaborator() {
        let coordinator = AppFlowCoordinatorSpy()
        let cancellation = AuthenticationCancellationSpy()
        let router = FlowRouter(appFlowCoordinator: coordinator)
        router.push(AuthenticationRoute.help)
        let viewModel = AuthenticationViewModel(
            router: router,
            authenticationActions: DisabledLegacyAuthenticationActions(),
            authenticationCancellation: cancellation
        )

        viewModel.cancelAuthentication()

        #expect(cancellation.callCount == 1)
        #expect(coordinator.commands.isEmpty)
        #expect(router.path.count == 1)
    }

    @Test
    func authenticationHelpUsesAuthenticationFlowRouter() {
        let flowRouter = makeTestFlowRouter()
        let cancellation = AuthenticationCancellationSpy()
        let viewModel = AuthenticationViewModel(
            router: flowRouter,
            authenticationActions: DisabledLegacyAuthenticationActions(),
            authenticationCancellation: cancellation
        )

        viewModel.openHelp()

        #expect(flowRouter.path.count == 1)
    }

    @Test
    func authenticationFlowAndScreenCanBeConstructed() {
        let coordinator = makeTestAppFlowCoordinator(
            visibleFlow: .restoring
        )
        let flowRouter = FlowRouter(appFlowCoordinator: coordinator)

        let cancellation = AuthenticationCancellationSpy()
        _ = AuthenticationView(
            router: flowRouter,
            authenticationCancellation: cancellation
        )
        _ = AuthenticationFlowView(
            router: flowRouter,
            authenticationCancellation: cancellation
        )
    }
}

@MainActor
private final class AuthenticationActionsSpy: IAuthenticationActions {
    private(set) var signInCount = 0

    func signIn() -> AppFlowActionResult {
        signInCount += 1
        return .unchanged
    }

    func signOut() -> AppFlowActionResult { .unchanged }
}

@MainActor
private final class AuthenticationCancellationSpy:
    IAuthenticationCancellation
{
    private(set) var callCount = 0

    func cancelAuthentication() {
        callCount += 1
    }
}
