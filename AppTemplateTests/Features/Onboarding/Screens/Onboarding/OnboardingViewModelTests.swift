import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct OnboardingViewModelTests {
    @Test
    func finishRequestsOnboardingCompletion() {
        let coordinator = AppFlowCoordinatorSpy()
        let viewModel = OnboardingViewModel(
            router: FlowRouter(appFlowCoordinator: coordinator)
        )

        viewModel.finish()

        #expect(coordinator.commands == [.completeOnboarding])
    }

    @Test
    func onboardingFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = OnboardingFlowView(router: router)
        _ = OnboardingView(router: router)
    }
}
