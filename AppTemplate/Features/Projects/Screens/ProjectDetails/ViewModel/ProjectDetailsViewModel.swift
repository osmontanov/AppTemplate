import Observation

@MainActor
@Observable
final class ProjectDetailsViewModel {
    let projectID: ProjectItem.ID
    private let router: any IRouter
    var sheet: ProjectDetailsSheetRoute?

    init(
        projectID: ProjectItem.ID,
        router: any IRouter
    ) {
        self.projectID = projectID
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
