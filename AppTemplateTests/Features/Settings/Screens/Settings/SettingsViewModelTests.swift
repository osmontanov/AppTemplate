import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct SettingsViewModelTests {
    @Test
    func settingsReflectsAndMutatesTheSharedSession() async {
        let session = UserSession(id: "user", displayName: "User")
        let service = SessionService(initialSession: session)
        let store = SessionStore(service: service)
        await store.start()
        let viewModel = SettingsViewModel(
            sessionStore: store,
            router: FlowRouter()
        )

        #expect(viewModel.phase == .authenticated(session))

        await viewModel.signOut()

        #expect(viewModel.phase == .unauthenticated)
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func failedSignOutExposesSafeFailureAndKeepsTheSession() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: FailingSettingsSessionService(session: session)
        )
        await store.start()
        let viewModel = SettingsViewModel(
            sessionStore: store,
            router: FlowRouter()
        )

        await viewModel.signOut()

        #expect(viewModel.phase == .authenticated(session))
        #expect(
            viewModel.failureMessage
                == "Sign out could not be completed."
        )
    }

    @Test
    func openingAboutPushesTheSettingsScreenRoute() {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)
        let router = FlowRouter()
        let viewModel = SettingsViewModel(
            sessionStore: store,
            router: router
        )

        viewModel.openAbout()

        #expect(router.path.count == 1)
    }

    @Test
    func settingsOwnsSessionInfoSheet() {
        let viewModel = makeSettingsViewModel()

        viewModel.openSessionInfo()

        #expect(viewModel.sheet == .sessionInfo)

        viewModel.dismissSheet()

        #expect(viewModel.sheet == nil)
    }

    @Test
    func settingsFlowAndScreenCanBeConstructed() {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)
        let router = FlowRouter()

        _ = SettingsFlowView(
            router: router,
            sessionStore: store
        )
        _ = SettingsView(router: router, sessionStore: store)
    }

    private func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            sessionStore: SessionStore(
                service: SessionService(initialSession: nil)
            ),
            router: FlowRouter()
        )
    }
}

private nonisolated enum SettingsViewModelTestError: Error {
    case signOut
}

private nonisolated struct FailingSettingsSessionService: ISessionService {
    let session: UserSession

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        session
    }

    func signOut() throws {
        throw SettingsViewModelTestError.signOut
    }
}
