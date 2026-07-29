import Testing
@testable import AppTemplate

@MainActor
struct BrowseOptionsViewModelTests {
    @Test
    func optionsWritesThroughToSharedPreferences() {
        let preferences = BrowsePreferencesStore()
        let viewModel = BrowseOptionsViewModel(preferences: preferences)

        viewModel.sortOrder = .titleDescending

        #expect(preferences.sortOrder == .titleDescending)
    }
}
