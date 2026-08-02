import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let router: any IFlowRouter
    private let onboardingActions: any IOnboardingActions
    private let maintenanceActions: any IMaintenanceActions
    var alert: HomeAlertRoute?
    var sheet: HomeSheetRoute?

    var isResetAlertPresented: Bool {
        get { alert != nil }
        set {
            if !newValue {
                alert = nil
            }
        }
    }

    init(
        router: any IFlowRouter,
        onboardingActions: any IOnboardingActions,
        maintenanceActions: any IMaintenanceActions
    ) {
        self.router = router
        self.onboardingActions = onboardingActions
        self.maintenanceActions = maintenanceActions
    }

    func openDetails() {
        router.push(HomeRoute.details)
    }

    func openNavigationGuide() {
        router.push(HomeRoute.navigationGuide)
    }

    func openOnboarding() {
        onboardingActions.restartOnboarding()
    }

    func openMaintenance() {
        maintenanceActions.setMaintenanceEnabled(true)
    }

    func requestNavigationReset() {
        alert = .resetNavigation
    }

    func confirmNavigationReset() {
        router.popToRoot()
        alert = nil
    }

    func cancelNavigationReset() {
        alert = nil
    }

    func openQuickStart() {
        sheet = .quickStart
    }

    func dismissSheet() {
        sheet = nil
    }
}
