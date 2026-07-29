import Observation

nonisolated
enum BrowseSortOrder: String, CaseIterable, Identifiable, Sendable {
    case titleAscending
    case titleDescending

    var id: Self { self }
}

@MainActor
@Observable
final class BrowsePreferencesStore {
    var sortOrder: BrowseSortOrder

    init(sortOrder: BrowseSortOrder = .titleAscending) {
        self.sortOrder = sortOrder
    }
}
