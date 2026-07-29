import Observation

@MainActor
@Observable
final class NavigationGuideViewModel {
    let title = "Navigation Guide"

    var items: [NavigationGuideItem] {
        NavigationGuideModel.items
    }

    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func close() {
        router.pop()
    }

    func openTopic(id: NavigationGuideItem.ID) {
        router.push(NavigationGuideRoute.topic(id: id))
    }
}
