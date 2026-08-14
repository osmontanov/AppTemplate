nonisolated
enum NavigationIntent: Equatable, Sendable {
    case openStoreRoot
    case openServicesRoot
}

nonisolated
enum DeepLinkError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unknownDestination
}
