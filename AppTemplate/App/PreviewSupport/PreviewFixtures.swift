import SwiftUI

@MainActor
enum PreviewFixtures {
    static func appComposition(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool = false
    ) -> ContentView {
        let dependencies = failClosedDependencies()
        let session = PreviewSessionActions()
        return ContentView(
            appFlowCoordinator: appFlowCoordinator(
                state: state,
                isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
            ),
            session: session.presentation,
            storeDependencies: dependencies.makeStoreDependencies(session: session),
            storeUISupport: dependencies.storeUISupport
        )
    }

    static func authenticationFlow() -> AuthenticationFlowView {
        AuthenticationFlowView(dependencies: AuthenticationDependencies(
            session: PreviewSessionActions(),
            cancellation: PreviewAuthenticationCancellation()
        ))
    }

    static func onboardingFlow() -> OnboardingFlowView {
        OnboardingFlowView(
            router: flowRouter(
                state: AppState(
                    hasCompletedOnboarding: false,
                    isMaintenanceEnabled: false
                )
            )
        )
    }

    static func homeFlow() -> HomeFlowView {
        HomeFlowView(
            router: flowRouter(state: mainState, isLocalSessionBootstrapResolved: true)
        )
    }

    static func browseFlow() -> BrowseFlowView {
        BrowseFlowView(
            router: flowRouter(state: mainState, isLocalSessionBootstrapResolved: true)
        )
    }

    static func projectsFlow() -> ProjectsFlowView {
        ProjectsFlowView(
            router: flowRouter(state: mainState, isLocalSessionBootstrapResolved: true)
        )
    }

    static func settingsFlow() -> SettingsFlowView {
        SettingsFlowView(
            router: flowRouter(state: mainState, isLocalSessionBootstrapResolved: true),
            dependencies: settingsDependencies()
        )
    }

    static func maintenanceFlow() -> MaintenanceFlowView {
        MaintenanceFlowView(
            router: flowRouter(
                state: AppState(
                    hasCompletedOnboarding: true,
                    isMaintenanceEnabled: true
                ),
                isLocalSessionBootstrapResolved: true
            )
        )
    }

    static func createProjectFlow() -> CreateProjectFlowView {
        CreateProjectFlowView(
            appFlowCoordinator: appFlowCoordinator(
                state: mainState,
                isLocalSessionBootstrapResolved: true
            )
        )
    }

    static func settingsDependencies() -> SettingsDependencies {
        SettingsDependencies(
            appInfo: AppInfoService(
                displayName: "AppTemplate Preview",
                version: "1.0"
            )
        )
    }

    static func failClosedDependencies() -> AppDependencies {
        AppDependencies.preview(
            settings: settingsDependencies(),
            remoteService: FailClosedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            imageLoader: FailClosedImageLoader()
        )
    }

    static func flowRouter(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool = false
    ) -> FlowRouter {
        FlowRouter(
            appFlowCoordinator: appFlowCoordinator(
                state: state,
                isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
            )
        )
    }

    static func appFlowCoordinator(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool = false
    ) -> AppFlowCoordinator {
        let storage = InMemoryAppStateStorage(initialState: state)
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(
                store.state,
                isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
            )
        )
        return AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter,
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
        )
    }

    private static var mainState: AppState {
        AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
    }
}

@MainActor
private final class PreviewAuthenticationCancellation: IAuthenticationCancellation {
    func cancelAuthentication() {}
}

@MainActor
private final class PreviewSessionActions: ISessionActions {
    private(set) var status = SessionStatusPresentation(
        session: SessionPresentation(state: .guest, revision: 1),
        expiry: nil
    )
    var presentation: SessionPresentation { status.session }

    func bootstrap() async {}
    func retryBootstrap() async {}
    func login(username: String, password: String) async -> SessionLoginResult {
        _ = username
        _ = password
        return .failure(.responseInvalid)
    }
    func retryPersistence(
        _ token: SessionPersistenceRetryToken
    ) async -> SessionPersistenceRetryResult {
        _ = token
        return .invalidToken
    }
    func discardPersistenceRetry(_ token: SessionPersistenceRetryToken) async {
        _ = token
    }
    func validateSession() async -> SessionValidationResult { .unchanged }
    func refreshSession() async -> SessionValidationResult { .unchanged }
    func signOut() async -> SessionSignOutResult { .cancelled }
}
