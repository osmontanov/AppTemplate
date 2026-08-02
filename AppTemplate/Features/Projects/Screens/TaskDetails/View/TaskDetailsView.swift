import SwiftUI

struct TaskDetailsView: View {
    @State private var viewModel: TaskDetailsViewModel

    init(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    ) {
        _viewModel = State(
            initialValue: TaskDetailsViewModel(
                projectID: projectID,
                taskID: taskID
            )
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
                LabeledContent {
                    Text(verbatim: viewModel.taskID)
                } label: {
                    Text("Work Item Identifier")
                }
            }
        }
        .navigationTitle("Work Item Details")
    }
}
