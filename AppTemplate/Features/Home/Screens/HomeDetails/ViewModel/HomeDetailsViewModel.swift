import Observation

@MainActor
@Observable
final class HomeDetailsViewModel {
    let title = "Reusable Destination"
    let systemImage = "point.topleft.down.to.point.bottomright.curvepath"
    let message = "This screen uses the router of the flow that opened it."

    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func openNavigationGuide() {
        router.push(HomeDetailsRoute.navigationGuide)
    }
}
