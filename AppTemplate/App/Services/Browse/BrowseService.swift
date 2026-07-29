actor BrowseService: IBrowseService {
    private var orderedIDs: [BrowseItem.ID]
    private var itemsByID: [BrowseItem.ID: BrowseItem]

    init(items: [BrowseItem]) {
        orderedIDs = items.map(\.id)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    func items() -> [BrowseItem] {
        orderedIDs.compactMap { itemsByID[$0] }
    }

    func item(id: BrowseItem.ID) -> BrowseItem? {
        itemsByID[id]
    }

    nonisolated
    static func live() -> BrowseService {
        BrowseService(items: [
            BrowseItem(id: "swiftui", title: "SwiftUI", summary: "Adaptive native interfaces."),
            BrowseItem(id: "observation", title: "Observation", summary: "Focused state tracking."),
            BrowseItem(id: "routing", title: "Typed Routing", summary: "Navigation represented as data.")
        ])
    }
}
