import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectDetailsViewModelTests {
    @Test
    func projectDetailsRetainsProjectIDAndPushesAnArbitraryStableTaskID() {
        let router = ProjectDetailsRouterSpy()
        let projectID = "project-from-deep-link"
        let taskID = "task-from-restored-navigation"
        let viewModel = ProjectDetailsViewModel(
            projectID: projectID,
            router: router
        )

        viewModel.openTask(id: taskID)

        #expect(viewModel.projectID == projectID)
        #expect(
            router.taskRoute == .task(
                projectID: projectID,
                taskID: taskID
            )
        )
    }

    @Test
    func projectDetailsScreenCanBeConstructedWithItsFlowRouter() {
        _ = ProjectDetailsView(
            projectID: "project-from-deep-link",
            router: makeTestFlowRouter()
        )
    }

    @Test
    func projectDetailsOwnsProjectInfoSheetState() {
        let projectID = "project-from-deep-link"
        let viewModel = ProjectDetailsViewModel(
            projectID: projectID,
            router: makeTestFlowRouter()
        )

        viewModel.openProjectInfo()

        #expect(viewModel.sheet == .projectInfo(projectID: projectID))

        viewModel.dismissSheet()

        #expect(viewModel.sheet == nil)
    }
}

@MainActor
private final class ProjectDetailsRouterSpy: LocalOnlyRouterSpy {
    private(set) var taskRoute: ProjectDetailsRoute?

    func push<Route: NavigationRoute>(_ route: Route) {
        taskRoute = route as? ProjectDetailsRoute
    }

    func pop() {}

    func popToRoot() {}
}
