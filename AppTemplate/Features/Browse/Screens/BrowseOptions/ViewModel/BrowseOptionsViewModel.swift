import Observation

@MainActor
@Observable
final class BrowseOptionsViewModel {
    private let preferences: BrowsePreferencesStore

    var sortOrder: BrowseSortOrder {
        get { preferences.sortOrder }
        set { preferences.sortOrder = newValue }
    }

    init(preferences: BrowsePreferencesStore) {
        self.preferences = preferences
    }
}
