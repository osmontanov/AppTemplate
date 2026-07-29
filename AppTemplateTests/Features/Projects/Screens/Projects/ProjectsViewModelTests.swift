import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectsViewModelTests {
    @Test
    func projectsAndDetailsPushScreenOwnedRoutes() {
        let router = FlowRouter()
        let store = ProjectsStore()
        let project = store.projects[0]
        let task = project.tasks[0]
        let projects = ProjectsViewModel(store: store, router: router)

        projects.openProject(id: project.id)

        #expect(router.path.count == 1)

        let details = ProjectDetailsViewModel(
            projectID: project.id,
            store: store,
            router: router
        )
        details.openTask(id: task.id)

        #expect(router.path.count == 2)
    }

    @Test
    func projectsScreenCanBeConstructedWithItsFlowRouterAndStore() {
        _ = ProjectsView(
            router: FlowRouter(),
            store: ProjectsStore()
        )
    }
}
