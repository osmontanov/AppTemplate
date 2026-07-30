import Observation

@MainActor
@Observable
final class MaintenanceViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func returnToApp() {
        router.setFlow(.main)
    }
}
