import Testing
@testable import AppTemplate

@MainActor
struct SessionRecoveryViewModelTests {
    @Test
    func retryCallsOnlyRetryBootstrapAndStaysPresentedWhenUnavailable() async {
        let session = RecoverySessionSpy(state: .unavailable(.secureStorageReadFailed))
        var resolved = 0
        let viewModel = SessionRecoveryViewModel(
            reason: .secureStorageReadFailed,
            session: session,
            onResolved: { resolved += 1 }
        )

        await viewModel.retry()

        #expect(session.retryBootstrapCalls == 1)
        #expect(session.otherCalls == 0)
        #expect(resolved == 0)
        #expect(!viewModel.isRetrying)
        #expect(viewModel.reason == .secureStorageReadFailed)
    }

    @Test
    func onlyANonUnavailablePublicationDismissesRecovery() {
        let session = RecoverySessionSpy(state: .unavailable(.secureStorageCleanupFailed))
        var resolved = 0
        let viewModel = SessionRecoveryViewModel(
            reason: .secureStorageCleanupFailed,
            session: session,
            onResolved: { resolved += 1 }
        )

        viewModel.sessionDidChange(SessionStatusPresentation(
            session: SessionPresentation(state: .unavailable(.secureStorageReadFailed), revision: 2),
            expiry: nil
        ))
        #expect(resolved == 0)
        #expect(viewModel.reason == .secureStorageReadFailed)

        viewModel.sessionDidChange(SessionStatusPresentation(
            session: SessionPresentation(state: .guest, revision: 3),
            expiry: nil
        ))
        #expect(resolved == 1)
    }
}

@MainActor
private final class RecoverySessionSpy: ISessionActions {
    private(set) var status: SessionStatusPresentation
    var presentation: SessionPresentation { status.session }
    private(set) var retryBootstrapCalls = 0
    private(set) var otherCalls = 0

    init(state: SessionState) {
        status = SessionStatusPresentation(session: SessionPresentation(state: state, revision: 1), expiry: nil)
    }

    func bootstrap() async { otherCalls += 1 }
    func retryBootstrap() async { retryBootstrapCalls += 1 }
    func login(username: String, password: String) async -> SessionLoginResult { otherCalls += 1; return .cancelled }
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult { otherCalls += 1; return .cancelled }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async { otherCalls += 1 }
    func validateSession() async -> SessionValidationResult { otherCalls += 1; return .unchanged }
    func refreshSession() async -> SessionValidationResult { otherCalls += 1; return .unchanged }
    func signOut() async -> SessionSignOutResult { otherCalls += 1; return .cancelled }
}
