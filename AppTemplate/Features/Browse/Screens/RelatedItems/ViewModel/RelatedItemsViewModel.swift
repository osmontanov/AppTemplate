import Observation

@MainActor
@Observable
final class RelatedItemsViewModel {
    let sourceItemID: BrowseItem.ID
    private let router: any IFlowRouter

    init(sourceItemID: BrowseItem.ID, router: any IFlowRouter) {
        self.sourceItemID = sourceItemID
        self.router = router
    }

    func openItem(id: BrowseItem.ID) {
        router.push(RelatedItemsRoute.item(id: id))
    }
}
