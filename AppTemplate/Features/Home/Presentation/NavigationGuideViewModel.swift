import Observation

nonisolated struct NavigationGuideItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
}

@MainActor
@Observable
final class NavigationGuideViewModel {
    let title = "Navigation Guide"
    let items = [
        NavigationGuideItem(
            id: "typed-paths",
            title: "Typed paths",
            systemImage: "list.bullet.rectangle"
        ),
        NavigationGuideItem(
            id: "independent-tabs",
            title: "Independent tabs",
            systemImage: "square.3.layers.3d"
        ),
        NavigationGuideItem(
            id: "scene-restoration",
            title: "Scene restoration",
            systemImage: "arrow.clockwise"
        )
    ]
}
