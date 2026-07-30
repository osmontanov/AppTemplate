import SwiftUI
import Testing
@testable import AppTemplate

@MainActor
struct RelatedItemsViewModelTests {
    @Test
    func relatedItemsRetainTheirSourceIdentifier() {
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "swiftui",
            router: FlowRouter()
        )

        #expect(viewModel.sourceItemID == "swiftui")
    }

    @Test
    func openingAnItemPushesTheRelatedItemsRoute() {
        let router = FlowRouter()
        let viewModel = RelatedItemsViewModel(
            sourceItemID: "swiftui",
            router: router
        )

        viewModel.openItem(id: "observation")

        #expect(router.path.count == 1)
    }

    @Test
    func relatedItemsScreenUsesNavigationOnlyInitializer() {
        _ = RelatedItemsView(sourceItemID: "swiftui", router: FlowRouter())
    }
}
