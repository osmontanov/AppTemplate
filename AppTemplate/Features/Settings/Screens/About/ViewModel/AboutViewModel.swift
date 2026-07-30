import Observation

@MainActor
@Observable
final class AboutViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func openPlatform(name: String) {
        router.push(AboutRoute.platform(name: name))
    }
}
