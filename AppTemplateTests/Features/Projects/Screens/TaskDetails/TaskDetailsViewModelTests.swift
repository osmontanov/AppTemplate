import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct TaskDetailsViewModelTests {
    @Test
    func taskDetailsRetainsArbitraryStableIDs() {
        let projectID = "project-from-deep-link"
        let taskID = "task-from-restored-navigation"
        let viewModel = TaskDetailsViewModel(
            projectID: projectID,
            taskID: taskID
        )

        #expect(viewModel.projectID == projectID)
        #expect(viewModel.taskID == taskID)
    }

    @Test
    func taskDetailsScreenCanBeConstructedWithStableIDs() {
        _ = TaskDetailsView(
            projectID: "project-from-deep-link",
            taskID: "task-from-restored-navigation"
        )
    }
}
