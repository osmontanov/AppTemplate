import SwiftUI

@MainActor
enum PreviewFixtures {
    static func appComposition(
        state: AppState,
        isAuthenticated: Bool = false
    ) -> ContentView {
        ContentView(
            appFlowCoordinator: appFlowCoordinator(
                state: state,
                isAuthenticated: isAuthenticated
            ),
            settings: settingsDependencies()
        )
    }

    static func authenticationFlow() -> AuthenticationFlowView {
        let appFlowCoordinator = appFlowCoordinator(
            state: AppState(
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
                    hasCompletedOnboarding: false,
                    isMaintenanceEnabled: false
                )
            )
        )
    }

    static func homeFlow() -> HomeFlowView {
        HomeFlowView(
            router: flowRouter(state: mainState, isAuthenticated: true)
        )
    }

    static func browseFlow() -> BrowseFlowView {
        BrowseFlowView(
            router: flowRouter(state: mainState, isAuthenticated: true)
        )
    }

    static func projectsFlow() -> ProjectsFlowView {
        ProjectsFlowView(
            router: flowRouter(state: mainState, isAuthenticated: true)
        )
    }

    static func settingsFlow() -> SettingsFlowView {
        SettingsFlowView(
            router: flowRouter(state: mainState, isAuthenticated: true),
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
                isAuthenticated: true
            )
        )
    }

    static func createProjectFlow() -> CreateProjectFlowView {
        CreateProjectFlowView(
            appFlowCoordinator: appFlowCoordinator(
                state: mainState,
                isAuthenticated: true
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

    static func flowRouter(
        state: AppState,
        isAuthenticated: Bool = false
    ) -> FlowRouter {
        FlowRouter(
            appFlowCoordinator: appFlowCoordinator(
                state: state,
                isAuthenticated: isAuthenticated
            )
        )
    }

    static func appFlowCoordinator(
        state: AppState,
        isAuthenticated: Bool = false
    ) -> AppFlowCoordinator {
        let legacyAuthentication = LegacyAuthenticationState(
            isAuthenticated: isAuthenticated
        )
        let storage = InMemoryAppStateStorage(initialState: state)
        let store = AppStateStore(storage: storage)
        let appFlowRouter = AppFlowRouter(
            flow: AppFlowPolicy.resolve(
                store.state,
                legacyAuthentication: legacyAuthentication
            )
        )
        return AppFlowCoordinator(
            store: store,
            appFlowRouter: appFlowRouter,
            legacyAuthentication: legacyAuthentication
        )
    }

    private static var mainState: AppState {
        AppState(
            hasCompletedOnboarding: true,
            isMaintenanceEnabled: false
        )
    }
}
