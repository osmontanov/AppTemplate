import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let sessionStore: SessionStore
    private let router: any IRouter

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    var canRetryRestoration: Bool {
        sessionStore.failure == .restoration
    }

    init(
        sessionStore: SessionStore,
        router: any IRouter
    ) {
        self.sessionStore = sessionStore
        self.router = router
    }

    func signIn() async {
        await sessionStore.signIn()
    }

    func retryRestoration() async {
        await sessionStore.retryStart()
    }

    func cancelAuthentication() {
        router.setFlow(.authentication)
    }

    func openHelp() {
        router.push(AuthenticationRoute.help)
    }
}
