import Observation

@MainActor
@Observable
final class ProjectDetailsViewModel {
    let projectID: ProjectItem.ID
    let store: ProjectsStore
    private let router: any IRouter
    var sheet: ProjectDetailsSheetRoute?

    var project: ProjectItem? {
        store.project(id: projectID)
    }

    var tasks: [ProjectTaskItem] {
        project?.tasks ?? []
    }

    init(
        projectID: ProjectItem.ID,
        store: ProjectsStore,
        router: any IRouter
    ) {
        self.projectID = projectID
        self.store = store
        self.router = router
    }

    func openTask(id: ProjectTaskItem.ID) {
        router.push(
            ProjectDetailsRoute.task(
                projectID: projectID,
                taskID: id
            )
        )
    }

    func openProjectInfo() {
        sheet = .projectInfo(projectID: projectID)
    }

    func dismissSheet() {
        sheet = nil
    }
}
