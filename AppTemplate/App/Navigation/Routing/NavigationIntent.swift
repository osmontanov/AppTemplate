enum NavigationIntent: Equatable, Sendable {
    case selectSection(AppSection)
    case openSectionRoot(AppSection)
    case browseItem(id: BrowseItem.ID)
    case project(id: ProjectItem.ID)
    case projectTask(
        projectID: ProjectItem.ID,
        taskID: ProjectTaskItem.ID
    )
}

enum DeepLinkError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unknownDestination
}
