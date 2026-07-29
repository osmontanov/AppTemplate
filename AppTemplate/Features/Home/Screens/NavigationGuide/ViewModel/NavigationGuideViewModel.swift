import Observation

@MainActor
@Observable
final class NavigationGuideViewModel {
    let title = "Navigation Guide"
    let items = [
        NavigationGuideItem(
            id: "screen-owned-routes",
            title: "Screen-owned routes",
            systemImage: "list.bullet.rectangle"
        ),
        NavigationGuideItem(
            id: "independent-flows",
            title: "Independent flows",
            systemImage: "square.3.layers.3d"
        ),
        NavigationGuideItem(
            id: "scene-restoration",
            title: "Scene restoration",
            systemImage: "arrow.clockwise"
        )
    ]

    private let router: any IFlowRouter

    init(router: any IFlowRouter) {
        self.router = router
    }

    func close() {
        router.pop()
    }
}
