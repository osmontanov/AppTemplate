import Observation

@MainActor
@Observable
final class SessionInfoViewModel {
    private let sessionStore: SessionStore

    var status: String {
        switch sessionStore.phase {
        case .idle:
            "Session has not started"
        case .loading:
            "Restoring session"
        case .unauthenticated:
            "Not signed in"
        case .authenticated:
            "Signed in"
        }
    }

    var displayName: String? {
        guard case let .authenticated(session) = sessionStore.phase else {
            return nil
        }

        return session.displayName
    }

    var failureMessage: String? {
        sessionStore.failure?.message
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }
}
