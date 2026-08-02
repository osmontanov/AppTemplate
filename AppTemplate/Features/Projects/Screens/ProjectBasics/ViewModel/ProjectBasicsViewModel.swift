import Observation

@MainActor
@Observable
final class ProjectBasicsViewModel {
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func continueToOptions() {
        router.push(ProjectBasicsRoute.options)
    }
}
