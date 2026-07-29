nonisolated
enum ProjectDetailsRoute: NavigationRoute {
    case task(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    )
}
