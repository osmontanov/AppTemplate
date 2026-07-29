import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct NavigationGuideViewModelTests {
    @Test
    func guideExposesPresentationItems() {
        let guide = NavigationGuideViewModel(router: FlowRouter())

        #expect(guide.items.map(\.title) == [
            "Screen-owned routes",
            "Independent flows",
            "Scene restoration"
        ])
    }

    @Test
    func closePopsTheCurrentFlowRouter() {
        let router = FlowRouter()
        router.push(HomeRoute.navigationGuide)
        let guide = NavigationGuideViewModel(router: router)

        guide.close()

        #expect(router.path.isEmpty)
    }

    @Test
    func guidePushesItsOwnTopicRoute() throws {
        let router = FlowRouter()
        let viewModel = NavigationGuideViewModel(router: router)
        let item = try #require(viewModel.items.first)

        viewModel.openTopic(id: item.id)

        #expect(router.path.count == 1)
    }

    @Test
    func navigationGuideScreenCanBeConstructed() {
        _ = NavigationGuideView(router: FlowRouter())
    }
}
