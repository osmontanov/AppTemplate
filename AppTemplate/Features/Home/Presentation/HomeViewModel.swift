import Observation

@MainActor
@Observable
final class HomeViewModel {
    let router: HomeRouter

    var isResetAlertPresented: Bool {
        get { router.alert != nil }
        set {
            if !newValue {
                router.alert = nil
            }
        }
    }

    init(router: HomeRouter) {
        self.router = router
    }

    func openDetails() {
        router.push(.details)
    }

    func openNavigationGuide() {
        router.sheet = .navigationGuide
    }

    func requestNavigationReset() {
        router.alert = .resetNavigation
    }

    func confirmNavigationReset() {
        router.popToRoot()
        router.alert = nil
    }

    func cancelNavigationReset() {
        router.alert = nil
    }
}
