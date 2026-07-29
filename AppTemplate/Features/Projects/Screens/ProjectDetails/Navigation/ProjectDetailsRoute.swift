nonisolated
enum ProjectDetailsRoute: NavigationRoute {
    case task(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    )
}

nonisolated
enum ProjectDetailsSheetRoute: Identifiable, Hashable, Sendable {
    case projectInfo(projectID: ProjectItem.ID)

    var id: Self { self }
}
