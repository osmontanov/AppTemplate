import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let onboardingActions: any IOnboardingActions

    init(onboardingActions: any IOnboardingActions) {
        self.onboardingActions = onboardingActions
    }

    func finish() {
        onboardingActions.completeOnboarding()
    }
}
