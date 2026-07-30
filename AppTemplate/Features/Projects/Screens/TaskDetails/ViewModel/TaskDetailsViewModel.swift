import Observation

@MainActor
@Observable
final class TaskDetailsViewModel {
    let projectID: ProjectItem.ID
    let taskID: ProjectTaskItem.ID

    init(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    ) {
        self.projectID = projectID
        self.taskID = taskID
    }
}
