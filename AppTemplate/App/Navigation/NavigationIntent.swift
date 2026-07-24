enum NavigationIntent: Equatable, Sendable {
    case selectSection(AppSection)
    case browseItem(id: BrowseItem.ID)
}

enum DeepLinkError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unknownDestination
}
