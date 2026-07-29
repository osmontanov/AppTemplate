nonisolated
struct NavigationGuideModel:
    Equatable,
    Sendable {
    static let items = [
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
}
