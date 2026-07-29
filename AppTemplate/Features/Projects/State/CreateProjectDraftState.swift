import Foundation
import Observation

@MainActor
@Observable
final class CreateProjectDraftState {
    var title = ""
    var summary = ""
    var colorName = "blue"

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
