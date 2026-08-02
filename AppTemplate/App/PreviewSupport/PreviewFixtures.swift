import SwiftUI

@MainActor
enum PreviewFixtures {
    static func authenticationFlow() -> AuthenticationFlowView {
        let appFlowCoordinator = makeAppFlowCoordinator(
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
            router: makeFlowRouter(
                state: AppState(
                    isAuthenticated: false,
                    hasCompletedOnboarding: false,
                    isMaintenanceEnabled: false
                )
            )
        )
    }

    static func maintenanceFlow() -> MaintenanceFlowView {
        MaintenanceFlowView(
            router: makeFlowRouter(
                state: AppState(
                    isAuthenticated: true,
                    hasCompletedOnboarding: true,
                    isMaintenanceEnabled: true
                )
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

    private static func makeFlowRouter(state: AppState) -> FlowRouter {
        FlowRouter(
            appFlowCoordinator: makeAppFlowCoordinator(state: state)
        )
    }

    private static func makeAppFlowCoordinator(
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
}
