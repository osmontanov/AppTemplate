import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct OnboardingViewModelTests {
    @Test
    func finishAppliesOnboardingCompletion() {
        let coordinator = makeTestAppFlowCoordinator(
            state: AppState(
                hasCompletedOnboarding: false,
                isMaintenanceEnabled: false
            ),
            isLocalSessionBootstrapResolved: true
        )
        let viewModel = OnboardingViewModel(
            onboardingActions: coordinator
        )

        viewModel.finish()

        #expect(coordinator.appFlowRouter.flow == .main)
    }

    @Test
    func onboardingFlowAndScreenCanBeConstructed() {
        let router = makeTestFlowRouter()

        _ = OnboardingFlowView(router: router)
        _ = OnboardingView(router: router)
    }
}
