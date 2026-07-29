import Observation

@MainActor
@Observable
final class ProjectInfoViewModel {
    let projectID: ProjectItem.ID
    private let store: ProjectsStore

    var project: ProjectItem? {
        store.project(id: projectID)
    }

    init(
        projectID: ProjectItem.ID,
        store: ProjectsStore
    ) {
        self.projectID = projectID
        self.store = store
    }
}
