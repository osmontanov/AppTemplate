import Observation

@MainActor
@Observable
final class HomeDetailsViewModel {
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openNavigationGuide() {
        router.push(HomeDetailsRoute.navigationGuide)
    }
}
