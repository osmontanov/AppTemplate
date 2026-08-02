import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct AboutViewModelTests {
    @Test
    func aboutPushesPlatformDetails() {
        let router = AboutRouterSpy()
        let viewModel = AboutViewModel(router: router)

        viewModel.openPlatform(.iPadOS)

        #expect(router.route == .platform(.iPadOS))
    }

    @Test
    func aboutScreenCanBeConstructed() {
        _ = AboutView(router: makeTestFlowRouter())
    }
}

@MainActor
private final class AboutRouterSpy: LocalOnlyRouterSpy {
    private(set) var route: AboutRoute?

    func push<Route: NavigationRoute>(_ route: Route) {
        self.route = route as? AboutRoute
    }

    func pop() {}

    func popToRoot() {}
}
