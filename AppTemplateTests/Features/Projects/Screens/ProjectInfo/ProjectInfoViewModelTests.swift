import Testing
@testable import AppTemplate

@MainActor
struct ProjectInfoViewModelTests {
    @Test
    func projectInfoHandlesUnknownProject() {
        let viewModel = ProjectInfoViewModel(
            projectID: "missing",
            store: ProjectsStore(projects: [])
        )

        #expect(viewModel.project == nil)
    }
}
