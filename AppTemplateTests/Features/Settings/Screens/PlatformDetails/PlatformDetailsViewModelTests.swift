import Testing
@testable import AppTemplate

@MainActor
struct PlatformDetailsViewModelTests {
    @Test
    func platformDetailsRetainsTheSelectedPlatformName() {
        let viewModel = PlatformDetailsViewModel(name: "iPadOS 26")

        #expect(viewModel.name == "iPadOS 26")
    }

    @Test
    func platformDetailsScreenCanBeConstructed() {
        _ = PlatformDetailsView(name: "iPadOS 26")
    }
}
