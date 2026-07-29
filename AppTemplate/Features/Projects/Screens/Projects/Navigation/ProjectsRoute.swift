nonisolated
enum ProjectsRoute: NavigationRoute {
    case project(id: ProjectItem.ID)
}

nonisolated
enum ProjectsSheetRoute: String, Identifiable, Hashable, Sendable {
    case createProject

    var id: Self { self }
}
