import SwiftUI

struct TaskDetailsView: View {
    @State private var viewModel: TaskDetailsViewModel

    init(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID,
        store: ProjectsStore
    ) {
        _viewModel = State(
            initialValue: TaskDetailsViewModel(
                projectID: projectID,
                taskID: taskID,
                store: store
            )
        )
    }

    var body: some View {
        Group {
            if let task = viewModel.task {
                Form {
                    LabeledContent("Identifier", value: task.id)
                    LabeledContent(
                        "Status",
                        value: task.isComplete ? "Complete" : "Incomplete"
                    )
                }
                .navigationTitle(task.title)
            } else {
                EmptyStateView(
                    title: "Task Unavailable",
                    systemImage: "questionmark.folder",
                    message: "This task no longer exists."
                )
                .navigationTitle("Task")
            }
        }
    }
}
