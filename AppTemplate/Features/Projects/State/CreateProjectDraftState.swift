import Foundation
import Observation

@MainActor
@Observable
final class CreateProjectDraftState {
    var title = ""
    var summary = ""
    var colorName = "blue"
    private(set) var isComplete = false

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func complete() {
        isComplete = true
    }
}
