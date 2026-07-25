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
    func startupWithoutSessionBecomesUnauthenticated() async {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        await store.start()

        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func signInAndSignOutUpdatePhase() async {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

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

private actor CountingSessionService: SessionService {
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

private actor FailingSessionService: SessionService {
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

private actor RecoveringSessionService: SessionService {
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

private actor SignOutFailingSessionService: SessionService {
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
