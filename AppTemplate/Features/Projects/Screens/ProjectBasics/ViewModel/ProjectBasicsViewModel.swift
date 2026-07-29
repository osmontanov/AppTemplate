import Foundation
import Observation

@MainActor
@Observable
final class ProjectBasicsViewModel {
    let draft: CreateProjectDraftState
    private let router: any IFlowRouter

    var validationMessage: String?

    init(
        draft: CreateProjectDraftState,
        router: any IFlowRouter
    ) {
        self.draft = draft
        self.router = router
    }

    func continueToOptions() {
        guard !draft.trimmedTitle.isEmpty else {
            validationMessage = "Project name is required."
            return
        }

        validationMessage = nil
        router.push(ProjectBasicsRoute.options)
    }
}
