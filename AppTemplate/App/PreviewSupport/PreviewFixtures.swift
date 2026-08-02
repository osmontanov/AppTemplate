import SwiftUI

@MainActor
enum PreviewFixtures {
    static func appComposition(state: AppState) -> ContentView {
        ContentView(
            appFlowCoordinator: appFlowCoordinator(state: state),
            settings: settingsDependencies()
        )
    }

    static func authenticationFlow() -> AuthenticationFlowView {
        let appFlowCoordinator = appFlowCoordinator(
            state: AppState(
                isAuthenticated: false,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        )
        let router = AppRouter(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            appFlowCoordinator: appFlowCoordinator
        )
        return AuthenticationFlowView(
            router: router.authentication,
            authenticationCancellation: router
        )
    }

    static func onboardingFlow() -> OnboardingFlowView {
        OnboardingFlowView(
            router: flowRouter(
                state: AppState(
                    isAuthenticated: false,
                    hasCompletedOnboarding: false,
                    isMaintenanceEnabled: false
                )
            )
        )
    }

    static func homeFlow() -> HomeFlowView {
        HomeFlowView(router: flowRouter(state: mainState))
    }

    static func browseFlow() -> BrowseFlowView {
        BrowseFlowView(router: flowRouter(state: mainState))
    }

    static func projectsFlow() -> ProjectsFlowView {
        ProjectsFlowView(router: flowRouter(state: mainState))
    }

    static func settingsFlow() -> SettingsFlowView {
        SettingsFlowView(
            router: flowRouter(state: mainState),
            dependencies: settingsDependencies()
        )
    }

    static func maintenanceFlow() -> MaintenanceFlowView {
        MaintenanceFlowView(
            router: flowRouter(
                state: AppState(
                    isAuthenticated: true,
                    hasCompletedOnboarding: true,
                    isMaintenanceEnabled: true
                )
            )
        )
    }

    static func createProjectFlow() -> CreateProjectFlowView {
        CreateProjectFlowView(
            appFlowCoordinator: appFlowCoordinator(state: mainState)
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

    static func flowRouter(state: AppState) -> FlowRouter {
        FlowRouter(
            appFlowCoordinator: appFlowCoordinator(state: state)
        )
    }

    static func appFlowCoordinator(
        state: AppState
    ) -> AppFlowCoordinator {
        let storage = InMemoryAppStateStorage(initialState: state)
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(store.state)
        )
        return AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter
        )
    }

    private static var mainState: AppState {
        AppState(
            isAuthenticated: true,
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
    }
}
