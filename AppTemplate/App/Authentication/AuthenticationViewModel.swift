import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let sessionStore: SessionStore
    private let router: AppRouter

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    var canRetryRestoration: Bool {
        sessionStore.failure == .restoration
    }

    init(
        sessionStore: SessionStore,
        router: AppRouter
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
        _ = router.completeAuthentication(succeeded: false)
    }
}
