import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct SettingsViewModelTests {
    @Test
    func settingsModelUsesInjectedAppMetadata() {
        let info = AppInfoService(
            displayName: "Preview App",
            version: "9.8.7"
        )
        let viewModel = SettingsViewModel(
            router: makeTestFlowRouter(),
            authenticationActions: AppFlowCoordinatorSpy(),
            appInfo: info
        )

        #expect(
            viewModel.model
                == SettingsModel(
                    displayName: "Preview App",
                    version: "9.8.7"
                )
        )
    }

    @Test
    func signOutAppliesSemanticSignOut() {
        let coordinator = makeTestAppFlowCoordinator(
            state: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            isAuthenticated: true
        )
        let viewModel = SettingsViewModel(
            router: makeTestFlowRouter(),
            authenticationActions: coordinator,
            appInfo: appInfo
        )

        viewModel.returnToAuthentication()

        #expect(coordinator.appFlowRouter.flow == .authentication)
    }

    @Test
    func openingAboutPushesTheSettingsScreenRoute() {
        let router = makeTestFlowRouter()
        let viewModel = SettingsViewModel(
            router: router,
            authenticationActions: router,
            appInfo: appInfo
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

        _ = SettingsFlowView(
            router: router,
            dependencies: settingsDependencies
        )
        _ = SettingsView(
            router: router,
            dependencies: settingsDependencies
        )
    }

    private func makeSettingsViewModel() -> SettingsViewModel {
        let router = makeTestFlowRouter()
        return SettingsViewModel(
            router: router,
            authenticationActions: router,
            appInfo: appInfo
        )
    }

    private let appInfo = AppInfoService(
        displayName: "AppTemplate",
        version: "1.0"
    )

    private var settingsDependencies: SettingsDependencies {
        SettingsDependencies(appInfo: appInfo)
    }
}
