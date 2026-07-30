import SwiftUI

struct ProjectOptionsView: View {
    private let router: FlowRouter
    private let flowState: CreateProjectFlowState
    @State private var viewModel: ProjectOptionsViewModel

    init(
        router: FlowRouter,
        flowState: CreateProjectFlowState
    ) {
        self.router = router
        self.flowState = flowState
        _viewModel = State(
            initialValue: ProjectOptionsViewModel(router: router)
        )
    }

    var body: some View {
        Form {
            Section("Presentation Example") {
                Text("This screen demonstrates an intermediate route.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Continue") {
                    viewModel.continueToReview()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Options")
        .navigationDestination(for: ProjectOptionsRoute.self) { route in
            switch route {
            case .review:
                ProjectReviewView(flowState: flowState)
            }
        }
    }
}
