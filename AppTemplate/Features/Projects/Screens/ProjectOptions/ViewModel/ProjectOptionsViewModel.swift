import Observation

@MainActor
@Observable
final class ProjectOptionsViewModel {
    let draft: CreateProjectDraftState
    private let router: any IFlowRouter

    init(
        draft: CreateProjectDraftState,
        router: any IFlowRouter
    ) {
        self.draft = draft
        self.router = router
    }

    func continueToReview() {
        router.push(ProjectOptionsRoute.review)
    }
}
