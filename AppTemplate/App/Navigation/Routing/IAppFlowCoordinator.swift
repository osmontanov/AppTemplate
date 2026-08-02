@MainActor
protocol IAppFlowCoordinator:
    IAuthenticationActions,
    IOnboardingActions,
    IMaintenanceActions {}
