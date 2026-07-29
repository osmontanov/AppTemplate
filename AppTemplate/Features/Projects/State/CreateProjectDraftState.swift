import Foundation
import Observation

@MainActor
@Observable
final class CreateProjectDraftState {
    var title = ""
    var summary = ""
    var colorName = "blue"
    private(set) var isComplete = false
    private(set) var completedProject: ProjectItem?

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func complete(with project: ProjectItem) {
        completedProject = project
        isComplete = true
    }
}
