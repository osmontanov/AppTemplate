import Testing
@testable import AppTemplate

@MainActor
struct ProjectReviewViewModelTests {
    @Test
    func finishMarksTheCreateProjectFlowForDismissal() {
        let flowState = CreateProjectFlowState()
        let viewModel = ProjectReviewViewModel(flowState: flowState)

        viewModel.finish()

        #expect(flowState.isFinished)
    }
}
