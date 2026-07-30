import SwiftUI

struct ProjectReviewView: View {
    @State private var viewModel: ProjectReviewViewModel

    init(flowState: CreateProjectFlowState) {
        _viewModel = State(
            initialValue: ProjectReviewViewModel(flowState: flowState)
        )
    }

    var body: some View {
        Form {
            Section("Presentation Example") {
                Text("Finishing this step dismisses the containing sheet.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Finish") {
                    viewModel.finish()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Review")
    }
}
