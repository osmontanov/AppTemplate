import Testing
@testable import AppTemplate

@MainActor
struct SessionInfoViewModelTests {
    @Test
    func sessionInfoDisplaysEverySessionPhaseSafely() async {
        let pendingService = PendingSessionInfoService()
        let pendingStore = SessionStore(service: pendingService)
        let pendingViewModel = SessionInfoViewModel(sessionStore: pendingStore)

        #expect(pendingViewModel.status == "Session has not started")
        #expect(pendingViewModel.displayName == nil)

        let restoring = Task { await pendingStore.start() }
        await pendingService.waitForRestoration()

        #expect(pendingViewModel.status == "Restoring session")
        #expect(pendingViewModel.displayName == nil)

        await pendingService.resumeRestoration(returning: nil)
        await restoring.value

        #expect(pendingViewModel.status == "Not signed in")
        #expect(pendingViewModel.displayName == nil)

        let session = UserSession(id: "member", displayName: "Member")
        let authenticatedStore = SessionStore(
            service: SessionService(initialSession: session)
        )
        let authenticatedViewModel = SessionInfoViewModel(
            sessionStore: authenticatedStore
        )
        await authenticatedStore.start()

        #expect(authenticatedViewModel.status == "Signed in")
        #expect(authenticatedViewModel.displayName == "Member")
    }

    @Test
    func sessionInfoExposesTheCurrentFailureMessage() async {
        let store = SessionStore(service: FailingSessionInfoService())
        let viewModel = SessionInfoViewModel(sessionStore: store)

        await store.start()

        #expect(viewModel.status == "Not signed in")
        #expect(
            viewModel.failureMessage
                == "The previous session could not be restored."
        )
    }

    @Test
    func sessionInfoScreenCanBeConstructedAsStandaloneSheetContent() {
        _ = SessionInfoView(
            sessionStore: SessionStore(
                service: SessionService(initialSession: nil)
            )
        )
    }
}

private actor PendingSessionInfoService: ISessionService {
    private var continuation: CheckedContinuation<UserSession?, any Error>?
    private var restorationWaiters: [CheckedContinuation<Void, Never>] = []

    func currentSession() async throws -> UserSession? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let waiters = restorationWaiters
            restorationWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func signIn() -> UserSession {
        UserSession(id: "member", displayName: "Member")
    }

    func signOut() {
    }

    func waitForRestoration() async {
        guard continuation == nil else {
            return
        }

        await withCheckedContinuation { continuation in
            restorationWaiters.append(continuation)
        }
    }

    func resumeRestoration(returning session: UserSession?) {
        continuation?.resume(returning: session)
        continuation = nil
    }
}

private actor FailingSessionInfoService: ISessionService {
    func currentSession() throws -> UserSession? {
        throw SessionInfoServiceError.failed
    }

    func signIn() -> UserSession {
        UserSession(id: "member", displayName: "Member")
    }

    func signOut() {
    }
}

private
nonisolated
enum SessionInfoServiceError: Error {
    case failed
}
