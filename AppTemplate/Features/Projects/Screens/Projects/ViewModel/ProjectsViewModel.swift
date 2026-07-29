import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    let store: ProjectsStore
    private let router: any IFlowRouter

    var projects: [ProjectItem] {
        store.projects
    }

    init(
        store: ProjectsStore,
        router: any IFlowRouter
    ) {
        self.store = store
        self.router = router
    }

    func openProject(id: ProjectItem.ID) {
        router.push(ProjectsRoute.project(id: id))
    }
}
