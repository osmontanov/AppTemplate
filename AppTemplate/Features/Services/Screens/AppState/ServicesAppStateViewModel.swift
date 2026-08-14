import Observation

@MainActor
@Observable
final class ServicesAppStateViewModel {
    private let appState: any IAppStateInspecting
    private let appFlowCoordinator: any IAppFlowCoordinator
    private let sessionActions: any ISessionActions
    private let status: ServicesAppStateStatus
    private let sceneNavigation: any ISceneNavigationActions

    init(
        appState: any IAppStateInspecting,
        appFlowCoordinator: any IAppFlowCoordinator,
        sessionActions: any ISessionActions,
        status: ServicesAppStateStatus,
        sceneNavigation: any ISceneNavigationActions
    ) {
        self.appState = appState
        self.appFlowCoordinator = appFlowCoordinator
        self.sessionActions = sessionActions
        self.status = status
        self.sceneNavigation = sceneNavigation
    }

    var application: AppStateInspection { appState.inspection }
    var session: SessionStatusPresentation { sessionActions.status }
    var scene: SceneNavigationPresentation { sceneNavigation.presentation() }
    var lastResult: ServiceLabResult { status.lastResult }

    func resetNavigationInCurrentScene() {
        sceneNavigation.resetNavigationInCurrentScene()
        status.record(.success("Current window navigation reset."))
    }

    func restartOnboarding() {
        status.record(map(appFlowCoordinator.restartOnboarding()))
    }

    func handleSampleIntent(_ intent: NavigationIntent) {
        sceneNavigation.handleSampleIntent(intent)
        status.record(.success("Sample link handled in this window."))
    }

    func setMaintenanceEnabled(_ enabled: Bool) {
        status.record(map(appFlowCoordinator.setMaintenanceEnabled(enabled)))
    }

    func signOut() async {
        status.record(.running)
        let result = await sessionActions.signOut()
        status.record(map(result))
    }

    private func map(_ result: AppFlowActionResult) -> ServiceLabResult {
        switch result {
        case .unchanged:
            .success("App state was already set.")
        case let .applied(_, didTransition):
            didTransition
                ? .success("App flow updated.")
                : .success("App state updated.")
        case .rejected:
            .failure("App state could not be saved.")
        }
    }

    private func map(_ result: SessionSignOutResult) -> ServiceLabResult {
        switch result {
        case .guest:
            .success("Signed out.")
        case .deletionFailed:
            .failure("Sign out could not clear secure session data.")
        case .cancelled:
            .failure("Sign out was cancelled.")
        }
    }
}
