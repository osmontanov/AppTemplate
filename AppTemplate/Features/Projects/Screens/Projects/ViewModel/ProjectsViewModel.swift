import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    let store: ProjectsStore
    private let router: any IRouter
    var sheet: ProjectsSheetRoute?

    var projects: [ProjectItem] {
        store.projects
    }

    init(
        store: ProjectsStore,
        router: any IRouter
    ) {
        self.store = store
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
