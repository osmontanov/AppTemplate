import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    private let sessionStore: SessionStore
    private let router: AppRouter
    private let flowRouter: any IFlowRouter

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    var canRetryRestoration: Bool {
        sessionStore.failure == .restoration
    }

    init(
        sessionStore: SessionStore,
        router: AppRouter,
        flowRouter: any IFlowRouter
    ) {
        self.sessionStore = sessionStore
        self.router = router
        self.flowRouter = flowRouter
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

    func openHelp() {
        flowRouter.push(AuthenticationRoute.help)
    }
}
