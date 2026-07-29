import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct TaskDetailsViewModelTests {
    @Test
    func taskDetailsScreenCanBeConstructedWithItsStore() {
        _ = TaskDetailsView(
            projectID: "project-1",
            taskID: "task-1",
            store: ProjectsStore()
        )
    }
}
