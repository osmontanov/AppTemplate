import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct HomeDetailsViewModelTests {
    @Test
    func detailsPushTheirOwnRouteIntoTheParentFlow() {
        let router = FlowRouter()
        let details = HomeDetailsViewModel(router: router)

        details.openNavigationGuide()

        #expect(router.path.count == 1)
    }

    @Test
    func reusedDetailsOperateOnTheRouterThatOpenedThem() {
        let homeRouter = FlowRouter()
        let browseRouter = FlowRouter()
        let homeDetails = HomeDetailsViewModel(router: homeRouter)
        let reusedDetails = HomeDetailsViewModel(router: browseRouter)

        homeDetails.openNavigationGuide()

        #expect(homeRouter.path.count == 1)
        #expect(browseRouter.path.isEmpty)

        reusedDetails.openNavigationGuide()

        #expect(homeRouter.path.count == 1)
        #expect(browseRouter.path.count == 1)
    }

    @Test
    func homeDetailsScreenCanBeConstructed() {
        _ = HomeDetailsView(router: FlowRouter())
    }
}
