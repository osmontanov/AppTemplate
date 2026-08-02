import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let router: any IFlowRouter
    private let authenticationActions: any IAuthenticationActions
    private let authenticationCancellation: any IAuthenticationCancellation

    init(
        router: any IFlowRouter,
        authenticationActions: any IAuthenticationActions,
        authenticationCancellation: any IAuthenticationCancellation
    ) {
        self.router = router
        self.authenticationActions = authenticationActions
        self.authenticationCancellation = authenticationCancellation
    }

    func continueToApp() {
        authenticationActions.signIn()
    }

    func cancelAuthentication() {
        authenticationCancellation.cancelAuthentication()
    }

    func openHelp() {
        router.push(AuthenticationRoute.help)
    }
}
