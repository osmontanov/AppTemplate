nonisolated
enum NavigationIntent: Equatable, Sendable {
    case openStoreRoot
    case openProduct(Product.ID)
    case openFavorites
    case openProfile
    case openServicesRoot
    case openService(ServicesRoute)
}

nonisolated
enum DeepLinkError: Error, Equatable, Sendable {
    case invalidScheme
    case credentialsNotAllowed
    case portNotAllowed
    case queryNotAllowed
    case fragmentNotAllowed
    case unsupportedHost
    case invalidSegments
    case invalidProductID
}
