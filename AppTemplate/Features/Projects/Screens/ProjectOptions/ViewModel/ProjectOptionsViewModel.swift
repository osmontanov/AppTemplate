import Observation

@MainActor
@Observable
final class ProjectOptionsViewModel {
    private let router: any IRouter

    init(router: any IRouter) {
        self.router = router
    }

    func continueToReview() {
        router.push(ProjectOptionsRoute.review)
    }
}
