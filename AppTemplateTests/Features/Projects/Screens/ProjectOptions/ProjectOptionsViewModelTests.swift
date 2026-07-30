import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectOptionsViewModelTests {
    @Test
    func optionsAlwaysPushesReview() {
        let router = ProjectOptionsRouterSpy()
        let viewModel = ProjectOptionsViewModel(router: router)

        viewModel.continueToReview()

        #expect(router.route == .review)
    }
}

@MainActor
private final class ProjectOptionsRouterSpy: LocalOnlyRouterSpy {
    private(set) var route: ProjectOptionsRoute?

    func push<Route: NavigationRoute>(_ route: Route) {
        self.route = route as? ProjectOptionsRoute
    }

    func pop() {}

    func popToRoot() {}
}
