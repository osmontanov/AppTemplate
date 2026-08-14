nonisolated
enum ProtectedStoreAction: Hashable, Sendable {
    case favorite(Product.ID)
    case openFavorites
    case openAccount
}

nonisolated
enum ProtectedActionResolution: Equatable, Sendable {
    case execute(ProtectedStoreAction)
    case presentAuthentication
    case blocked(SessionUnavailableReason)
}
