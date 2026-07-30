import Observation

@MainActor
@Observable
final class BrowseDetailViewModel {
    let id: BrowseItem.ID
    private let router: any IRouter

    init(id: BrowseItem.ID, router: any IRouter) {
        self.id = id
        self.router = router
    }

    func openRelatedItems() {
        router.push(BrowseDetailRoute.relatedItems(itemID: id))
    }
}
