import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct OnboardingViewModelTests {
    @Test
    func finishingOnboardingOpensMain() {
        let coordinator = makeTestAppFlowCoordinator(visibleFlow: .onboarding)
        let appFlowRouter = coordinator.appFlowRouter
        let router = FlowRouter(appFlowCoordinator: coordinator)
        let viewModel = OnboardingViewModel(router: router)

        viewModel.finish()

        #expect(appFlowRouter.flow == .main)
        #expect(appFlowRouter.transition.historyAction == .reset)
    }

    @Test
    func onboardingFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = OnboardingFlowView(router: router)
        _ = OnboardingView(router: router)
    }
}
