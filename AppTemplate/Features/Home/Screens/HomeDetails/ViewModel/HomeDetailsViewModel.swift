import Observation

@MainActor
@Observable
final class HomeDetailsViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func openNavigationGuide() {
        router.push(HomeDetailsRoute.navigationGuide)
    }
}
