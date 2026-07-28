import Testing
@testable import AppTemplate

@MainActor
struct SessionStoreTests {
    @Test
    func startupRestoresExistingSessionOnlyOnce() async {
        let session = UserSession(id: "one", displayName: "One")
        let service = CountingSessionService(session: session)
        let store = SessionStore(service: service)

        await store.start()
        await store.start()

        let restoreCount = await service.restoreCount
        #expect(store.phase == .authenticated(session))
        #expect(restoreCount == 1)
    }

    @Test
    func cancellingFirstStartupWaiterDoesNotCancelSharedRestoration() async {
        let session = UserSession(id: "shared", displayName: "Shared")
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let first = Task { await store.start() }
        await service.waitForCalls(restores: 1)

        let secondEntry = MainActorEntryBarrier()
        let second = Task { @MainActor in
            secondEntry.enter()
            await store.start()
        }
        await secondEntry.wait()
        first.cancel()
        await service.resumeRestore(at: 0, returning: session)

        await first.value
        await second.value
        let restoreCount = await service.restoreCount

        #expect(store.phase == .authenticated(session))
        #expect(store.failure == nil)
        #expect(restoreCount == 1)
    }

    @Test
    func staleStartupRestorationCannotOverwriteNewerSignIn() async {
        let restored = UserSession(id: "restored", displayName: "Restored")
        let signedIn = UserSession(id: "signed-in", displayName: "Signed In")
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let startup = Task { await store.start() }
        await service.waitForCalls(restores: 1)

        let signIn = Task { await store.signIn() }
        await service.waitForCalls(signIns: 1)
        await service.resumeSignIn(at: 0, returning: signedIn)
        await signIn.value

        await service.resumeRestore(at: 0, returning: restored)
        await startup.value

        #expect(store.phase == .authenticated(signedIn))
        #expect(store.failure == nil)
    }

    @Test
    func startupWithoutSessionBecomesUnauthenticated() async {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)

        await store.start()

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func signInAndSignOutUpdatePhase() async {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)

        await store.signIn()
        #expect(store.phase == .authenticated(
            UserSession(id: "template-user", displayName: "Template User")
        ))

        await store.signOut()
        #expect(store.phase == .unauthenticated)
    }

    @Test
    func signInFailureUsesSafePresentationError() async {
        let store = SessionStore(service: FailingSessionService())

        await store.signIn()

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == .signIn)
        #expect(store.failure?.message == "Sign in could not be completed.")
    }

    @Test
    func retryStartRunsRestorationAgainAfterFailure() async {
        let service = RecoveringSessionService()
        let store = SessionStore(service: service)

        await store.start()
        #expect(store.failure == .restoration)

        await store.retryStart()
        let restoreCount = await service.restoreCount

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
        #expect(restoreCount == 2)
    }

    @Test
    func concurrentRetryCallersJoinActiveRestoration() async {
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let startup = Task { await store.start() }
        await service.waitForCalls(restores: 1)
        await service.failRestore(at: 0)
        await startup.value

        let firstRetry = Task { await store.retryStart() }
        await service.waitForCalls(restores: 2)
        let secondEntry = MainActorEntryBarrier()
        let secondRetry = Task { @MainActor in
            secondEntry.enter()
            await store.retryStart()
        }
        await secondEntry.wait()

        await service.resumeRestore(at: 1, returning: nil)
        await firstRetry.value
        await secondRetry.value
        let restoreCount = await service.restoreCount

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
        #expect(restoreCount == 2)
    }

    @Test
    func staleRetryCannotOverwriteNewerSignIn() async {
        let signedIn = UserSession(id: "signed-in", displayName: "Signed In")
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let startup = Task { await store.start() }
        await service.waitForCalls(restores: 1)
        await service.failRestore(at: 0)
        await startup.value

        let retry = Task { await store.retryStart() }
        await service.waitForCalls(restores: 2)

        let signIn = Task { await store.signIn() }
        await service.waitForCalls(signIns: 1)
        await service.resumeSignIn(at: 0, returning: signedIn)
        await signIn.value

        await service.resumeRestore(at: 1, returning: nil)
        await retry.value

        #expect(store.phase == .authenticated(signedIn))
        #expect(store.failure == nil)
    }

    @Test
    func staleRetryCannotOverwriteNewerSignOut() async {
        let existing = UserSession(id: "existing", displayName: "Existing")
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let startup = Task { await store.start() }
        await service.waitForCalls(restores: 1)
        await service.resumeRestore(at: 0, returning: existing)
        await startup.value

        let retry = Task { await store.retryStart() }
        await service.waitForCalls(restores: 2)

        let signOut = Task { await store.signOut() }
        await service.waitForCalls(signOuts: 1)
        await service.resumeSignOut(at: 0)
        await signOut.value

        await service.resumeRestore(at: 1, returning: existing)
        await retry.value

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func staleSignOutFailureCannotOverwriteNewerSignIn() async {
        let existing = UserSession(id: "existing", displayName: "Existing")
        let signedIn = UserSession(id: "new", displayName: "New")
        let service = ControlledSessionService()
        let store = SessionStore(service: service)

        let startup = Task { await store.start() }
        await service.waitForCalls(restores: 1)
        await service.resumeRestore(at: 0, returning: existing)
        await startup.value

        let signOut = Task { await store.signOut() }
        await service.waitForCalls(signOuts: 1)

        let signIn = Task { await store.signIn() }
        await service.waitForCalls(signIns: 1)
        await service.resumeSignIn(at: 0, returning: signedIn)
        await signIn.value

        await service.failSignOut(at: 0)
        await signOut.value

        #expect(store.phase == .authenticated(signedIn))
        #expect(store.failure == nil)
    }

    @Test
    func failedSignOutRetainsAuthenticatedSession() async {
        let session = UserSession(id: "one", displayName: "One")
        let store = SessionStore(
            service: SignOutFailingSessionService(session: session)
        )

        await store.start()
        await store.signOut()

        #expect(store.phase == .authenticated(session))
        #expect(store.failure == .signOut)
    }
}

@MainActor
private final class MainActorEntryBarrier {
    // A resumed waiter cannot run until the current MainActor job reaches its
    // next suspension. Tests call enter() immediately before the store call,
    // so wait() returns only after that call has reached its shared-task await.
    private var hasEntered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func enter() {
        hasEntered = true
        let waiters = waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func wait() async {
        guard !hasEntered else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private actor ControlledSessionService: ISessionService {
    private(set) var restoreCount = 0
    private(set) var signInCount = 0
    private(set) var signOutCount = 0

    private var restoreContinuations:
        [Int: CheckedContinuation<UserSession?, any Error>] = [:]
    private var signInContinuations:
        [Int: CheckedContinuation<UserSession, any Error>] = [:]
    private var signOutContinuations:
        [Int: CheckedContinuation<Void, any Error>] = [:]
    private var callWaiters: [CheckedContinuation<Void, Never>] = []

    func currentSession() async throws -> UserSession? {
        let index = restoreCount
        restoreCount += 1
        notifyCallWaiters()

        let session = try await withCheckedThrowingContinuation { continuation in
            restoreContinuations[index] = continuation
        }
        try Task.checkCancellation()
        return session
    }

    func signIn() async throws -> UserSession {
        let index = signInCount
        signInCount += 1
        notifyCallWaiters()

        let session = try await withCheckedThrowingContinuation { continuation in
            signInContinuations[index] = continuation
        }
        try Task.checkCancellation()
        return session
    }

    func signOut() async throws {
        let index = signOutCount
        signOutCount += 1
        notifyCallWaiters()

        try await withCheckedThrowingContinuation { continuation in
            signOutContinuations[index] = continuation
        }
        try Task.checkCancellation()
    }

    func waitForCalls(
        restores: Int = 0,
        signIns: Int = 0,
        signOuts: Int = 0
    ) async {
        while restoreCount < restores
            || signInCount < signIns
            || signOutCount < signOuts {
            await withCheckedContinuation { continuation in
                callWaiters.append(continuation)
            }
        }
    }

    func resumeRestore(
        at index: Int,
        returning session: UserSession?
    ) {
        restoreContinuations.removeValue(forKey: index)?.resume(
            returning: session
        )
    }

    func failRestore(at index: Int) {
        restoreContinuations.removeValue(forKey: index)?.resume(
            throwing: SessionServiceTestError.failed
        )
    }

    func resumeSignIn(
        at index: Int,
        returning session: UserSession
    ) {
        signInContinuations.removeValue(forKey: index)?.resume(
            returning: session
        )
    }

    func resumeSignOut(at index: Int) {
        signOutContinuations.removeValue(forKey: index)?.resume()
    }

    func failSignOut(at index: Int) {
        signOutContinuations.removeValue(forKey: index)?.resume(
            throwing: SessionServiceTestError.failed
        )
    }

    private func notifyCallWaiters() {
        let waiters = callWaiters
        callWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor CountingSessionService: ISessionService {
    private(set) var restoreCount = 0
    private var session: UserSession?

    init(session: UserSession?) {
        self.session = session
    }

    func currentSession() -> UserSession? {
        restoreCount += 1
        return session
    }

    func signIn() -> UserSession {
        let session = UserSession(id: "one", displayName: "One")
        self.session = session
        return session
    }

    func signOut() {
        session = nil
    }
}

private actor FailingSessionService: ISessionService {
    func currentSession() throws -> UserSession? {
        throw SessionServiceTestError.failed
    }

    func signIn() throws -> UserSession {
        throw SessionServiceTestError.failed
    }

    func signOut() throws {
        throw SessionServiceTestError.failed
    }
}

private actor RecoveringSessionService: ISessionService {
    private(set) var restoreCount = 0

    func currentSession() throws -> UserSession? {
        restoreCount += 1
        if restoreCount == 1 {
            throw SessionServiceTestError.failed
        }
        return nil
    }

    func signIn() -> UserSession {
        UserSession(id: "recovered", displayName: "Recovered")
    }

    func signOut() {
    }
}

private actor SignOutFailingSessionService: ISessionService {
    private let session: UserSession

    init(session: UserSession) {
        self.session = session
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        session
    }

    func signOut() throws {
        throw SessionServiceTestError.failed
    }
}

private nonisolated enum SessionServiceTestError: Error {
    case failed
}
