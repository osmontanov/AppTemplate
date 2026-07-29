import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectOptionsViewModelTests {
    @Test
    func optionsKeepsTheSameDraftAndPushesReview() {
        let router = FlowRouter()
        let draft = CreateProjectDraftState()
        draft.title = "Template"
        let viewModel = ProjectOptionsViewModel(draft: draft, router: router)

        #expect(viewModel.draft === draft)

        viewModel.continueToReview()

        #expect(router.path.count == 1)
    }
}
