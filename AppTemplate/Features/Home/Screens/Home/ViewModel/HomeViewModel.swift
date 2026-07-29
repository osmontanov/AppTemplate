import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let router: any IFlowRouter
    var alert: HomeAlertRoute?

    var isResetAlertPresented: Bool {
        get { alert != nil }
        set {
            if !newValue {
                alert = nil
            }
        }
    }

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openDetails() {
        router.push(HomeRoute.details)
    }

    func openNavigationGuide() {
        router.push(HomeRoute.navigationGuide)
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
}
