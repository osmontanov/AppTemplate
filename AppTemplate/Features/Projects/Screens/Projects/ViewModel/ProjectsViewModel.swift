import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    private let router: any IFlowRouter
    var sheet: ProjectsSheetRoute?

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openProject(id: ProjectItem.ID) {
        router.push(ProjectsRoute.project(id: id))
    }

    func openCreateProject() {
        sheet = .createProject
    }

    func dismissSheet() {
        sheet = nil
    }
}
