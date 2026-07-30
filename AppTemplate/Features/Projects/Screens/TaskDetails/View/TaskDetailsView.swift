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
                LabeledContent(
                    "Project Identifier",
                    value: viewModel.projectID
                )
                LabeledContent(
                    "Work Item Identifier",
                    value: viewModel.taskID
                )
            }
        }
        .navigationTitle("Work Item Details")
    }
}
