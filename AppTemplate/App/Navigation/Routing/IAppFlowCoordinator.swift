@MainActor
protocol IAppFlowCoordinator: IAppFlowRouter {
    func completeOnboarding()
    func restartOnboarding()
    func signIn()
    func signOut()
    func setMaintenanceEnabled(_ isEnabled: Bool)
}
