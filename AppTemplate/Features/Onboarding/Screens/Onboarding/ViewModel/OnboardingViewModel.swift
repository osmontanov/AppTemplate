import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func finish() {
        router.completeOnboarding()
    }
}
