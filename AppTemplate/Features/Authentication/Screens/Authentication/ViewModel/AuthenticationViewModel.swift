import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func continueToApp() {
        router.setFlow(.main)
    }

    func cancelAuthentication() {
        router.setFlow(.authentication)
    }

    func openHelp() {
        router.push(AuthenticationRoute.help)
    }
}
