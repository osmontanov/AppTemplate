import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AboutViewModelTests {
    @Test
    func aboutProvidesSupportedPlatformPresentation() {
        let viewModel = AboutViewModel(router: FlowRouter())

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
    func aboutPushesPlatformDetails() {
        let router = FlowRouter()
        let viewModel = AboutViewModel(router: router)

        viewModel.openPlatform(name: "iOS 26")

        #expect(router.path.count == 1)
    }

    @Test
    func aboutScreenCanBeConstructed() {
        _ = AboutView(router: FlowRouter())
    }
}
