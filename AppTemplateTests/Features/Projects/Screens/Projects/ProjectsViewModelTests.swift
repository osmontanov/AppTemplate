import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectsViewModelTests {
    @Test
    func projectsPushesAnArbitraryStableProjectID() {
        let router = ProjectsRouterSpy()
        let projectID = "project-from-restored-navigation"
        let viewModel = ProjectsViewModel(router: router)

        viewModel.openProject(id: projectID)

        #expect(router.projectRoute == .project(id: projectID))
    }

    @Test
    func projectsScreenCanBeConstructedWithItsFlowRouter() {
        _ = ProjectsView(router: FlowRouter())
    }

    @Test
    func projectsOwnsCreateProjectSheetState() {
        let viewModel = ProjectsViewModel(router: FlowRouter())

        viewModel.openCreateProject()

        #expect(viewModel.sheet == .createProject)

        viewModel.dismissSheet()

        #expect(viewModel.sheet == nil)
    }
}

@MainActor
private final class ProjectsRouterSpy: IRouter {
    private(set) var projectRoute: ProjectsRoute?

    func push<Route: NavigationRoute>(_ route: Route) {
        projectRoute = route as? ProjectsRoute
    }

    func pop() {}

    func popToRoot() {}

    func setFlow(_ flow: AppFlow) {}
}
