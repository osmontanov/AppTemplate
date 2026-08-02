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
                LabeledContent {
                    Text(verbatim: viewModel.projectID)
                } label: {
                    Text("Project Identifier")
                }
            }

            Section {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
