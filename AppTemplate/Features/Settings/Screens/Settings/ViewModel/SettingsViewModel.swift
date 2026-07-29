import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let sessionStore: SessionStore
    private let router: any IFlowRouter

    var phase: SessionPhase {
        sessionStore.phase
    }

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    init(
        sessionStore: SessionStore,
        router: any IFlowRouter
    ) {
        self.sessionStore = sessionStore
        self.router = router
    }

    func openAbout() {
        router.push(SettingsRoute.about)
    }

    func signOut() async {
        await sessionStore.signOut()
    }
}
