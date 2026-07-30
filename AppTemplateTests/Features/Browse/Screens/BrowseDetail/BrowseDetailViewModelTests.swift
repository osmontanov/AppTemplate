import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct BrowseDetailViewModelTests {
    @Test
    func browseDetailStateScaffoldCanBeConstructed() {
        _ = BrowseDetailScreenState()
    }

    @Test
    func detailRetainsItsStableIdentifier() {
        let viewModel = BrowseDetailViewModel(
            id: "swiftui",
            router: makeTestFlowRouter()
        )

        #expect(viewModel.id == "swiftui")
    }

    @Test
    func detailPushesItsOwnRelatedItemsRoute() {
        let router = makeTestFlowRouter()
        let viewModel = BrowseDetailViewModel(id: "swiftui", router: router)

        viewModel.openRelatedItems()

        #expect(router.path.count == 1)
    }

    @Test
    func browseDetailScreenUsesNavigationOnlyInitializer() {
        _ = BrowseDetailView(
            id: "swiftui",
            router: makeTestFlowRouter()
        )
    }
}
