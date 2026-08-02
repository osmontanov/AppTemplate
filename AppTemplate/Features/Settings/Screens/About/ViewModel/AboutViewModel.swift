import Observation

@MainActor
@Observable
final class AboutViewModel {
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openPlatform(_ platform: AppPlatform) {
        router.push(AboutRoute.platform(platform))
    }
}
