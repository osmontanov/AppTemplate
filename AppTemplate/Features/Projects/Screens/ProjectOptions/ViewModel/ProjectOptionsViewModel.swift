import Observation

@MainActor
@Observable
final class ProjectOptionsViewModel {
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func continueToReview() {
        router.push(ProjectOptionsRoute.review)
    }
}
