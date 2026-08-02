import Observation

@MainActor
@Observable
final class BrowseListViewModel {
    var sheet: BrowseSheetRoute?
    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func openItem(id: BrowseItem.ID) {
        router.push(BrowseRoute.item(id: id))
    }

    func openOptions() {
        sheet = .options
    }

    func dismissSheet() {
        sheet = nil
    }
}
