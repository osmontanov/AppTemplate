import SwiftUI
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

    @Test
    func projectInfoCanBeConstructedAsStandaloneSheetContent() {
        _ = ProjectInfoView(
            projectID: "project-1",
            store: ProjectsStore()
        )
        _ = ProjectInfoView(
            projectID: "missing",
            store: ProjectsStore(projects: [])
        )
    }
}
