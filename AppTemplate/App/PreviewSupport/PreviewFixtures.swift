import SwiftUI

@MainActor
enum PreviewFixtures {
    static func appComposition(
        state: AppState,
        isLocalSessionBootstrapResolved: Bool = false
    ) -> ContentView {
        let dependencies = failClosedDependencies()
        return ContentView(
            appFlowCoordinator: appFlowCoordinator(
                state: state,
                isLocalSessionBootstrapResolved: isLocalSessionBootstrapResolved
            ),
            session: SessionPresentation(state: .guest, revision: 1),
            storeDependencies: dependencies.makeStoreDependencies(),
            storeUISupport: dependencies.storeUISupport
        )
    }

    static func authenticationFlow() -> AuthenticationFlowView {
        let appFlowCoordinator = appFlowCoordinator(
            state: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        )
        let router = FlowRouter(appFlowCoordinator: appFlowCoordinator)
        return AuthenticationFlowView(
            router: router,
            authenticationCancellation: PreviewAuthenticationCancellation(router: router)
        )
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
    private let router: FlowRouter

    init(router: FlowRouter) { self.router = router }

    func cancelAuthentication() { router.popToRoot() }
}
