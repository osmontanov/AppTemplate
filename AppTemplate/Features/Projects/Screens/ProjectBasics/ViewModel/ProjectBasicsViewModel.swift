import Observation

@MainActor
@Observable
final class ProjectBasicsViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func continueToOptions() {
        router.push(ProjectBasicsRoute.options)
    }
}
