import Testing
@testable import AppTemplate

@MainActor
struct AuthenticationViewModelTests {
    @Test
    func signInUpdatesTheSharedSessionStore() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: AuthenticationSessionService(
                restoredSession: nil,
                signedInSession: session,
                restorationFails: false
            )
        )
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .authentication)
        )

        await viewModel.signIn()

        #expect(store.phase == .authenticated(session))
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func cancellationClearsTheScenePendingIntent() {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )
        let router = AppRouter(flow: .authentication)
        _ = router.handle(.browseItem(id: "swiftui"))
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: router
        )

        viewModel.cancelAuthentication()

        #expect(router.pendingIntent == nil)
        #expect(router.flow == .authentication)
    }

    @Test
    func restorationFailureIsDisplaySafeAndRetryable() async {
        let store = SessionStore(
            service: AuthenticationSessionService(
                restoredSession: nil,
                signedInSession: UserSession(
                    id: "user",
                    displayName: "User"
                ),
                restorationFails: true
            )
        )
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .launching)
        )

        await store.start()

        #expect(viewModel.canRetryRestoration)
        #expect(
            viewModel.failureMessage
                == "The previous session could not be restored."
        )
    }

    @Test
    func retryRestorationDelegatesToTheSharedSessionStore() async {
        let service = RetryingAuthenticationSessionService()
        let store = SessionStore(service: service)
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: AppRouter(flow: .launching)
        )
        await store.start()
        #expect(store.failure == .restoration)

        await viewModel.retryRestoration()
        let attempts = await service.restorationAttempts()

        #expect(attempts == 2)
        #expect(store.phase == .unauthenticated)
        #expect(store.failure == nil)
    }

    @Test
    func authenticationScreenCanBeConstructed() {
        let store = SessionStore(
            service: InMemorySessionService(initialSession: nil)
        )

        _ = AuthenticationView(
            sessionStore: store,
            router: AppRouter(flow: .authentication)
        )
    }
}

private nonisolated enum AuthenticationTestError: Error {
    case restoration
}

private nonisolated struct AuthenticationSessionService: SessionService {
    let restoredSession: UserSession?
    let signedInSession: UserSession
    let restorationFails: Bool

    func currentSession() throws -> UserSession? {
        if restorationFails {
            throw AuthenticationTestError.restoration
        }
        return restoredSession
    }

    func signIn() -> UserSession {
        signedInSession
    }

    func signOut() {
    }
}

private actor RetryingAuthenticationSessionService: SessionService {
    private var attempts = 0

    func currentSession() throws -> UserSession? {
        attempts += 1
        if attempts == 1 {
            throw AuthenticationTestError.restoration
        }
        return nil
    }

    func signIn() -> UserSession {
        UserSession(id: "user", displayName: "User")
    }

    func signOut() {
    }

    func restorationAttempts() -> Int {
        attempts
    }
}
