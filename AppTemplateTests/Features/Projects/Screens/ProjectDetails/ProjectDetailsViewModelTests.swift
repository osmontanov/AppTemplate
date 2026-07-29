import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectDetailsViewModelTests {
    @Test
    func missingProjectAndTaskResolveToUnavailableContent() {
        let store = ProjectsStore(projects: [])

        #expect(
            ProjectDetailsViewModel(
                projectID: "missing",
                store: store,
                router: FlowRouter()
            ).project == nil
        )
        #expect(
            TaskDetailsViewModel(
                projectID: "missing",
                taskID: "missing",
                store: store
            ).task == nil
        )
    }

    @Test
    func projectDetailsScreenCanBeConstructedWithItsFlowRouterAndStore() {
        _ = ProjectDetailsView(
            projectID: "project-1",
            router: FlowRouter(),
            store: ProjectsStore()
        )
    }

    @Test
    func projectDetailsOwnsProjectInfoSheetState() {
        let store = ProjectsStore()
        let projectID = store.projects[0].id
        let viewModel = ProjectDetailsViewModel(
            projectID: projectID,
            store: store,
            router: FlowRouter()
        )

        viewModel.openProjectInfo()

        #expect(viewModel.sheet == .projectInfo(projectID: projectID))

        viewModel.dismissSheet()

        #expect(viewModel.sheet == nil)
    }
}
