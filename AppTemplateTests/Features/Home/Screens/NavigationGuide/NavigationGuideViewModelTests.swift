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
    func navigationGuideScreenCanBeConstructed() {
        _ = NavigationGuideView(router: FlowRouter())
    }
}
