import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AboutViewModelTests {
    @Test
    func aboutPushesPlatformDetails() {
        let router = makeTestFlowRouter()
        let viewModel = AboutViewModel(router: router)

        viewModel.openPlatform(.iPadOS)

        #expect(router.path.count == 1)
    }

    @Test
    func aboutScreenCanBeConstructed() {
        _ = AboutView(router: makeTestFlowRouter())
    }
}
