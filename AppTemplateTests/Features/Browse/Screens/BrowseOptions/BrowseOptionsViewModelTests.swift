import Testing
@testable import AppTemplate

@MainActor
struct BrowseOptionsViewModelTests {
    @Test
    func optionsScreenHasAnEmptyViewModelScaffold() {
        _ = BrowseOptionsViewModel()
        _ = BrowseOptionsView()
    }
}
