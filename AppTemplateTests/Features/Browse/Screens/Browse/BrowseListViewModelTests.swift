import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct BrowseListViewModelTests {
    @Test
    func browseStateScaffoldCanBeConstructed() {
        _ = BrowseScreenState()
    }

    @Test
    func openingAnItemPushesTheBrowseScreenRoute() {
        let router = FlowRouter()
        let viewModel = BrowseListViewModel(router: router)

        viewModel.openItem(id: "swiftui")

        #expect(router.path.count == 1)
    }

    @Test
    func browseOwnsOptionsSheetState() {
        let viewModel = BrowseListViewModel(router: FlowRouter())

        viewModel.openOptions()
        #expect(viewModel.sheet == .options)
        viewModel.dismissSheet()
        #expect(viewModel.sheet == nil)
    }

    @Test
    func browseFlowAndScreenUseNavigationOnlyInitializers() {
        let router = FlowRouter()

        _ = BrowseFlowView(router: router)
        _ = BrowseView(router: router)
    }
}
