import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let sessionStore: SessionStore
    private let router: any IFlowRouter
    var sheet: SettingsSheetRoute?

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

    func openSessionInfo() {
        sheet = .sessionInfo
    }

    func dismissSheet() {
        sheet = nil
    }

    func signOut() async {
        await sessionStore.signOut()
    }
}
