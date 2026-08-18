import SwiftUI

@MainActor
enum PreviewFixtures {
    static func appComposition(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool = false
    ) -> PreviewAppCompositionView {
        let dependencies = failClosedDependencies()
        let session = PreviewSessionActions()
        let graph = appFlowGraph(
            state: state,
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
        )
        let servicesDependencies = dependencies.makeServicesDependencies(
            appState: graph.inspector,
            appFlowCoordinator: graph.coordinator,
            sessionActions: session,
            appStateStatus: ServicesAppStateStatus()
        )
        return PreviewAppCompositionView(
            appFlowCoordinator: graph.coordinator,
            storeDependencies: dependencies.makeStoreDependencies(session: session),
            storeUISupport: dependencies.storeUISupport,
            servicesDependencies: servicesDependencies
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

    static func failClosedDependencies() -> AppDependencies {
        AppDependencies.preview(
            appInfo: AppInfoService(
                displayName: "AppTemplate Preview",
                version: "1.0"
            ),
            remoteService: FailClosedRemoteService(),
            diagnostics: NetworkDiagnosticRecorder(),
            images: ImageService.failClosed()
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
        appFlowGraph(
            state: state,
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
        ).coordinator
    }

    private static func appFlowGraph(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool
    ) -> (coordinator: AppFlowCoordinator, inspector: AppStateInspector) {
        let storage = InMemoryAppStateStorage(initialState: state)
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(
                store.state,
                isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
            )
        )
        let coordinator = AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter,
            isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
        )
        return (
            coordinator,
            AppStateInspector(store: store, router: appFlowRouter)
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
