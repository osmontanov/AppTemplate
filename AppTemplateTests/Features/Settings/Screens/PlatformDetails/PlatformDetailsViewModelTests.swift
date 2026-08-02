import Testing
@testable import AppTemplate

@MainActor
struct PlatformDetailsViewModelTests {
    @Test
    func platformDetailsRetainsTheSelectedPlatform() {
        let viewModel = PlatformDetailsViewModel(platform: .iPadOS)

        #expect(viewModel.platform == .iPadOS)
    }

    @Test
    func platformDetailsScreenCanBeConstructed() {
        _ = PlatformDetailsView(platform: .iPadOS)
    }
}
