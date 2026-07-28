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
        let viewModel = SettingsViewModel(sessionStore: store)

        #expect(viewModel.phase == .authenticated(session))

        await viewModel.signOut()

        #expect(viewModel.phase == .unauthenticated)
        #expect(viewModel.failureMessage == nil)
    }

    @Test
    func aboutProvidesSupportedPlatformPresentation() {
        let viewModel = AboutViewModel()

        #expect(viewModel.supportedPlatforms == [
            "iOS 26",
            "iPadOS 26",
            "macOS 26"
        ])
        #expect(
            viewModel.exampleDescription
                == "Home, Browse, and Settings are replaceable feature examples."
        )
    }

    @Test
    func failedSignOutExposesSafeFailureAndKeepsTheSession() async {
        let session = UserSession(id: "user", displayName: "User")
        let store = SessionStore(
            service: FailingSettingsSessionService(session: session)
        )
        await store.start()
        let viewModel = SettingsViewModel(sessionStore: store)

        await viewModel.signOut()

        #expect(viewModel.phase == .authenticated(session))
        #expect(
            viewModel.failureMessage
                == "Sign out could not be completed."
        )
    }

    @Test
    func everySettingsScreenCanBeConstructed() {
        let service = SessionService(initialSession: nil)
        let store = SessionStore(service: service)

        _ = SettingsNavigationView(
            router: SettingsRouter(),
            sessionStore: store
        )
        _ = AboutView()
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
