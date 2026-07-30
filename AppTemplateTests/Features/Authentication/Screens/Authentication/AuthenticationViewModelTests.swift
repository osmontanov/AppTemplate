import SwiftUI
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
        let flowRouter = FlowRouter(
            appFlowRouter: AppFlowRouter(flow: .authentication)
        )
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: flowRouter
        )

        await viewModel.signIn()

        #expect(store.phase == .authenticated(session))
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func cancellationPublishesFreshAuthenticationDiscardTransition() {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let flowRouter = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: flowRouter
        )
        let previousID = appFlowRouter.transition.id

        viewModel.cancelAuthentication()

        #expect(appFlowRouter.flow == .authentication)
        #expect(appFlowRouter.transition.id != previousID)
        #expect(appFlowRouter.transition.pendingIntentAction == .discard)
    }

    @Test
    func authenticationHelpUsesAuthenticationFlowRouter() {
        let store = SessionStore(service: SessionService(initialSession: nil))
        let flowRouter = FlowRouter()
        let viewModel = AuthenticationViewModel(
            sessionStore: store,
            router: flowRouter
        )

        viewModel.openHelp()

        #expect(flowRouter.path.count == 1)
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
            router: FlowRouter()
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
            router: FlowRouter()
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
    func authenticationFlowAndScreenCanBeConstructed() {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)
        let appFlowRouter = AppFlowRouter(flow: .authentication)
        let flowRouter = FlowRouter(appFlowRouter: appFlowRouter)

        _ = AuthenticationView(
            sessionStore: store,
            router: flowRouter
        )
        _ = AuthenticationFlowView(
            router: flowRouter,
            sessionStore: store
        )
    }
}

private
nonisolated
enum AuthenticationTestError: Error {
    case restoration
}

private
nonisolated
struct AuthenticationSessionService: ISessionService {
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

private actor RetryingAuthenticationSessionService: ISessionService {
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
