import Foundation
import Observation

@MainActor
@Observable
final class ProjectBasicsViewModel {
    let draft: CreateProjectDraftState
    private let router: any IRouter

    var validationMessage: String?

    init(
        draft: CreateProjectDraftState,
        router: any IRouter
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
