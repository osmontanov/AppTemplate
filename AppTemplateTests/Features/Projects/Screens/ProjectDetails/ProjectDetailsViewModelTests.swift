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
}
