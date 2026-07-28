import Testing
@testable import AppTemplate

@MainActor
struct AboutViewModelTests {
    @Test
    func aboutProvidesSupportedPlatformPresentation() {
        let viewModel = AboutViewModel()

        #expect(viewModel.supportedPlatforms == [
            "iOS 26",
            "iPadOS 26",
            "macOS 26"
        ])
        #expect(
            viewModel.exampleDescription
                == "Home, Browse, and Settings are replaceable feature examples."
        )
    }

    @Test
    func aboutScreenCanBeConstructed() {
        _ = AboutView()
    }
}
