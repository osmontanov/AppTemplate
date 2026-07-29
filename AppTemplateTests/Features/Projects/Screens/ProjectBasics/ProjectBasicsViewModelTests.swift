import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectBasicsViewModelTests {
    @Test
    func basicsValidatesBeforePushingOptions() {
        let router = FlowRouter()
        let draft = CreateProjectDraftState()
        let viewModel = ProjectBasicsViewModel(draft: draft, router: router)

        viewModel.continueToOptions()

        #expect(viewModel.validationMessage == "Project name is required.")
        #expect(router.path.isEmpty)

        draft.title = "Template"
        viewModel.continueToOptions()

        #expect(viewModel.validationMessage == nil)
        #expect(router.path.count == 1)
    }
}
