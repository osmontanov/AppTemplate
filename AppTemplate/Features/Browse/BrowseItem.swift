struct BrowseItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
}

protocol BrowseItemResolving: Sendable {
    func item(id: BrowseItem.ID) -> BrowseItem?
}

struct SampleBrowseCatalog: BrowseItemResolving {
    static let items = [
        BrowseItem(id: "swiftui", title: "SwiftUI", summary: "Adaptive native interfaces."),
        BrowseItem(id: "observation", title: "Observation", summary: "Focused state tracking."),
        BrowseItem(id: "routing", title: "Typed Routing", summary: "Navigation represented as data.")
    ]

    func item(id: BrowseItem.ID) -> BrowseItem? {
        Self.items.first { $0.id == id }
    }
}
