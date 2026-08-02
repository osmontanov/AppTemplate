@MainActor
protocol IOnboardingActions: AnyObject {
    @discardableResult
    func completeOnboarding() -> AppFlowActionResult

    @discardableResult
    func restartOnboarding() -> AppFlowActionResult
}
