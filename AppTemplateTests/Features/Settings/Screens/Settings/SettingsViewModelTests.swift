import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct SettingsViewModelTests {
    @Test
    func returnToAuthenticationReplacesTheRoot() {
        let coordinator = makeTestAppFlowCoordinator(visibleFlow: .main)
        let appFlowRouter = coordinator.appFlowRouter
        let viewModel = SettingsViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.returnToAuthentication()

        #expect(appFlowRouter.flow == .authentication)
        #expect(appFlowRouter.transition.pendingIntentAction == .discard)
    }

    @Test
    func openingAboutPushesTheSettingsScreenRoute() {
        let router = makeTestFlowRouter()
        let viewModel = SettingsViewModel(router: router)

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
        SettingsViewModel(router: makeTestFlowRouter())
    }
}
