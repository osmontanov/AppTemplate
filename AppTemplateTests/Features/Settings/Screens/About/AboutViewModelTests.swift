import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AboutViewModelTests {
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
