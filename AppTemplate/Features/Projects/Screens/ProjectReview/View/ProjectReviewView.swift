import SwiftUI

struct ProjectReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var viewModel: ProjectReviewViewModel

    init(
        draft: CreateProjectDraftState,
        store: ProjectsStore
    ) {
        _viewModel = State(
            initialValue: ProjectReviewViewModel(
                draft: draft,
                store: store
            )
        )
    }

    var body: some View {
        Form {
            Section("Project") {
                LabeledContent("Name", value: viewModel.draft.title)
                LabeledContent("Summary", value: viewModel.draft.summary)
                LabeledContent("Color", value: viewModel.draft.colorName)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Section {
                Button("Save Project") {
                    do {
                        _ = try viewModel.save()
                        dismiss()
                    } catch {
                        errorMessage = "Unable to save the project."
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Review")
    }
}
