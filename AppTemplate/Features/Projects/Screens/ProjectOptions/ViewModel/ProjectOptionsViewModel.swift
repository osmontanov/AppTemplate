import Observation

@MainActor
@Observable
final class ProjectOptionsViewModel {
    let draft: CreateProjectDraftState
    private let router: any IRouter

    init(
        draft: CreateProjectDraftState,
        router: any IRouter
    ) {
        self.draft = draft
        self.router = router
    }

    func continueToReview() {
        router.push(ProjectOptionsRoute.review)
    }
}
