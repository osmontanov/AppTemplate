import Testing
@testable import AppTemplate

@MainActor
struct ProfileViewModelTests {
    @Test
    func profileLoadsPublicAppInfo() async {
        let viewModel = ProfileViewModel(
            router: StoreRouter(),
            session: ProfileSessionSpy(),
            appInfo: AppInfoService(displayName: "Mini Store", version: "2.0")
        )

        await viewModel.load()

        #expect(viewModel.model == ProfileModel(displayName: "Mini Store", version: "2.0"))
    }

    @Test
    func accountSelectionUsesRouterOwnedProtectedState() {
        let router = StoreRouter(path: [.profile])
        let viewModel = ProfileViewModel(router: router, session: ProfileSessionSpy(), appInfo: AppInfoService())

        #expect(viewModel.select(.account, session: .guest) == .presentAuthentication)
        #expect(viewModel.selectedSection == .overview)
        #expect(router.path == [.profile])
        #expect(router.pendingProtectedAction == .openAccount)
    }

    @Test
    func authenticatedAccountCachesPresentationInRouter() {
        let router = StoreRouter(path: [.profile])
        let session = authenticatedState(userID: 1)
        let viewModel = ProfileViewModel(router: router, session: ProfileSessionSpy(state: session), appInfo: AppInfoService())

        #expect(viewModel.select(.account, session: session) == nil)
        #expect(viewModel.selectedSection == .account)
        #expect(router.cachedAccountPresentation?.userID == 1)
    }

    @Test
    func failedSignOutKeepsAuthenticatedAccount() async {
        let router = StoreRouter(path: [.profile])
        let state = authenticatedState(userID: 1)
        _ = router.selectProfileSection(.account, session: state)
        router.cacheAccountPresentation(ProfileAccountPresentation(userID: 1, displayName: "User 1", availability: .online))
        let viewModel = ProfileViewModel(
            router: router,
            session: ProfileSessionSpy(state: state, signOutResult: .deletionFailed),
            appInfo: AppInfoService()
        )

        await viewModel.signOut()

        #expect(router.profileSection == .account)
        #expect(router.cachedAccountPresentation?.userID == 1)
        #expect(viewModel.error == .signOutDeletionFailed)
    }

    @Test
    func cancelledSignOutIsSilentAndGuestResultWaitsForPublication() async {
        for result in [SessionSignOutResult.cancelled, .guest] {
            let router = StoreRouter()
            let state = authenticatedState(userID: 3)
            _ = router.selectProfileSection(.account, session: state)
            let viewModel = ProfileViewModel(
                router: router,
                session: ProfileSessionSpy(state: state, signOutResult: result),
                appInfo: AppInfoService()
            )

            await viewModel.signOut()

            #expect(viewModel.error == nil)
            #expect(router.profileSection == .account)
        }
    }

    private func authenticatedState(userID: Int) -> SessionState {
        .authenticated(
            UserProfile(id: userID, username: "user", firstName: "User", lastName: "\(userID)", imageURL: nil),
            availability: .online
        )
    }
}

@MainActor
private final class ProfileSessionSpy: ISessionActions {
    private(set) var status: SessionStatusPresentation
    var presentation: SessionPresentation { status.session }
    private let signOutResult: SessionSignOutResult

    init(state: SessionState = .guest, signOutResult: SessionSignOutResult = .cancelled) {
        status = SessionStatusPresentation(session: SessionPresentation(state: state, revision: 1), expiry: nil)
        self.signOutResult = signOutResult
    }

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult { .cancelled }
    func retryPersistence(_ token: SessionPersistenceRetryToken) async -> SessionPersistenceRetryResult { .cancelled }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {}
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { signOutResult }
}
