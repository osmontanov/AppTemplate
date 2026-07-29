nonisolated
enum BrowseRoute: NavigationRoute {
    case item(id: BrowseItem.ID)
}

nonisolated
enum BrowseSheetRoute: String, Identifiable, Hashable, Sendable {
    case options

    var id: Self { self }
}
