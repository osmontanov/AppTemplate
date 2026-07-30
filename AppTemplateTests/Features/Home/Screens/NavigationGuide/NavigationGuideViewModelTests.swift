import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct NavigationGuideViewModelTests {
    @Test
    func closePopsTheCurrentFlowRouter() {
        let router = FlowRouter()
        router.push(HomeRoute.navigationGuide)
        let guide = NavigationGuideViewModel(router: router)

        guide.close()

        #expect(router.path.isEmpty)
    }

    @Test
    func guidePushesItsOwnTopicRoute() {
        let router = FlowRouter()
        let viewModel = NavigationGuideViewModel(router: router)

        viewModel.openTopic(id: "screen-owned-routes")

        #expect(router.path.count == 1)
    }

    @Test
    func navigationGuideScreenCanBeConstructed() {
        _ = NavigationGuideView(router: FlowRouter())
    }
}
