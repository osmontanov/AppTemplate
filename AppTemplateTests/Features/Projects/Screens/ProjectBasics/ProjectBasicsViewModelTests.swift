import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct ProjectBasicsViewModelTests {
    @Test
    func basicsAlwaysPushesOptions() {
        let router = ProjectBasicsRouterSpy()
        let viewModel = ProjectBasicsViewModel(router: router)

        viewModel.continueToOptions()

        #expect(router.route == .options)
    }
}

@MainActor
private final class ProjectBasicsRouterSpy: LocalOnlyRouterSpy {
    private(set) var route: ProjectBasicsRoute?

    func push<Route: NavigationRoute>(_ route: Route) {
        self.route = route as? ProjectBasicsRoute
    }

    func pop() {}

    func popToRoot() {}
}
