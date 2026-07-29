import Foundation
import Testing
@testable import AppTemplate

struct ProjectItemTests {
    @Test
    func projectRoundTripsItsTaskThroughCodableRepresentation() throws {
        let project = ProjectItem(
            id: "project-1",
            title: "Template",
            summary: "Navigation work",
            colorName: "blue",
            tasks: [
                ProjectTaskItem(
                    id: "task-1",
                    title: "Ship",
                    isComplete: false
                )
            ]
        )

        let decoded = try JSONDecoder().decode(
            ProjectItem.self,
            from: JSONEncoder().encode(project)
        )

        #expect(decoded == project)
    }
}
