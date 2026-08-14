import Observation

@MainActor
@Observable
final class SessionRecoveryViewModel {
    private let session: any ISessionActions
    private let onResolved: () -> Void
    private(set) var isRetrying = false
    private(set) var reason: SessionUnavailableReason

    init(
        reason: SessionUnavailableReason,
        session: any ISessionActions,
        onResolved: @escaping () -> Void
    ) {
        self.reason = reason
        self.session = session
        self.onResolved = onResolved
    }

    func retry() async {
        guard !isRetrying else { return }
        isRetrying = true
        await session.retryBootstrap()
        isRetrying = false
        sessionDidChange(session.status)
    }

    func sessionDidChange(_ status: SessionStatusPresentation) {
        if case let .unavailable(reason) = status.session.state {
            self.reason = reason
            return
        }
        onResolved()
    }
}
