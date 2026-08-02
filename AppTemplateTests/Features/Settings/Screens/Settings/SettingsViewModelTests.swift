import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct SettingsViewModelTests {
    @Test
    func signOutAppliesSemanticSignOut() {
        let coordinator = makeTestAppFlowCoordinator(
            state: AppState(
                isAuthenticated: true,
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            )
        )
        let viewModel = SettingsViewModel(
            router: makeTestFlowRouter(),
            authenticationActions: coordinator
        )

        viewModel.returnToAuthentication()

        #expect(coordinator.appFlowRouter.flow == .authentication)
    }

    @Test
    func openingAboutPushesTheSettingsScreenRoute() {
        let router = makeTestFlowRouter()
        let viewModel = SettingsViewModel(
            router: router,
            authenticationActions: router
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
        let router = makeTestFlowRouter()

        _ = SettingsFlowView(router: router)
        _ = SettingsView(router: router)
    }

    private func makeSettingsViewModel() -> SettingsViewModel {
        let router = makeTestFlowRouter()
        return SettingsViewModel(
            router: router,
            authenticationActions: router
        )
    }
}
