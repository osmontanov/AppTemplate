import SwiftUI

struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProjectInfoViewModel

    init(projectID: ProjectItem.ID) {
        _viewModel = State(
            initialValue: ProjectInfoViewModel(projectID: projectID)
        )
    }

    var body: some View {
        Form {
            Section("Destination") {
                LabeledContent(
                    "Project Identifier",
                    value: viewModel.projectID
                )
            }

            Section {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
