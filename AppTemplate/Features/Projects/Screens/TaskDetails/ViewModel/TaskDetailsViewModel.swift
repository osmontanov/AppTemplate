import Observation

@MainActor
@Observable
final class TaskDetailsViewModel {
    let projectID: ProjectItem.ID
    let taskID: ProjectTaskItem.ID
    private let store: ProjectsStore

    var task: ProjectTaskItem? {
        store.task(
            projectID: projectID,
            taskID: taskID
        )
    }

    init(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID,
        store: ProjectsStore
    ) {
        self.projectID = projectID
        self.taskID = taskID
        self.store = store
    }
}
