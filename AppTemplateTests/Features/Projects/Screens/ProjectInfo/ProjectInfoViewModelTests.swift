import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectInfoViewModelTests {
    @Test
    func projectInfoRetainsAnArbitraryStableProjectID() {
        let projectID = "project-from-deep-link"
        let viewModel = ProjectInfoViewModel(projectID: projectID)

        #expect(viewModel.projectID == projectID)
    }

    @Test
    func projectInfoCanBeConstructedAsStandaloneSheetContent() {
        _ = ProjectInfoView(projectID: "project-from-deep-link")
    }
}
