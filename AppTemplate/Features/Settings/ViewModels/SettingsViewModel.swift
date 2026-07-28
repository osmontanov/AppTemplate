import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let sessionStore: SessionStore

    var phase: SessionPhase {
        sessionStore.phase
    }

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func signOut() async {
        await sessionStore.signOut()
    }
}
