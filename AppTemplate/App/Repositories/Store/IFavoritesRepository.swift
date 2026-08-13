nonisolated protocol IFavoritesRepository: Sendable {
    func favorites(userID: Int) async throws -> [FavoriteProductSnapshot]
    func contains(userID: Int, productID: Int) async throws -> Bool
    @discardableResult func ensureFavorite(_ product: ProductSnapshot, userID: Int) async throws -> Bool
    @discardableResult func removeFavorite(userID: Int, productID: Int) async throws -> Bool
    @discardableResult func toggle(_ product: ProductSnapshot, userID: Int) async throws -> Bool
}
