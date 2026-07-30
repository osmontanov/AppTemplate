import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct OnboardingViewModelTests {
    @Test
    func finishingOnboardingOpensMain() {
        let appFlowRouter = AppFlowRouter(flow: .onboarding)
        let router = FlowRouter(appFlowRouter: appFlowRouter)
        let viewModel = OnboardingViewModel(router: router)

        viewModel.finish()

        #expect(appFlowRouter.flow == .main)
        #expect(appFlowRouter.transition.historyAction == .reset)
    }

    @Test
    func onboardingFlowAndScreenCanBeConstructed() {
        let router = FlowRouter()

        _ = OnboardingFlowView(router: router)
        _ = OnboardingView(router: router)
    }
}
