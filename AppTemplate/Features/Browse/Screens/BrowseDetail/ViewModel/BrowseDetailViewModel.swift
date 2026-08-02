import Observation

@MainActor
@Observable
final class BrowseDetailViewModel {
    let id: BrowseItem.ID
    private let router: any IFlowRouter

    init(id: BrowseItem.ID, router: any IFlowRouter) {
        self.id = id
        self.router = router
    }

    func openRelatedItems() {
        router.push(BrowseDetailRoute.relatedItems(itemID: id))
    }
}
