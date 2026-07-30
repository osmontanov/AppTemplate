import Observation

@MainActor
@Observable
final class ProjectReviewViewModel {
    private let flowState: CreateProjectFlowState

    init(flowState: CreateProjectFlowState) {
        self.flowState = flowState
    }

    func finish() {
        flowState.isFinished = true
    }
}
