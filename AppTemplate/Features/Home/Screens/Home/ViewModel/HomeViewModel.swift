import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let router: any IRouter
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

    init(router: any IRouter) {
        self.router = router
    }

    func openDetails() {
        router.push(HomeRoute.details)
    }

    func openNavigationGuide() {
        router.push(HomeRoute.navigationGuide)
    }

    func openOnboarding() {
        router.restartOnboarding()
    }

    func openMaintenance() {
        router.setMaintenanceEnabled(true)
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
