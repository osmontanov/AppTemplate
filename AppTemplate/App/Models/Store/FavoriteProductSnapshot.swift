nonisolated
struct FavoriteProductQuery: Equatable, Sendable {
    let userID: Int
}

nonisolated
struct FavoriteProductSnapshot:
    LocalDatabaseModel,
    Codable,
    Equatable,
    Sendable
{
    typealias ID = String
    typealias Query = FavoriteProductQuery
    typealias Persistence = FavoriteProductSnapshotAdapter

    let canonicalID: String
    let userID: Int
    let product: ProductSnapshot

    var id: String { canonicalID }

    static func canonicalID(userID: Int, productID: Int) -> String {
        "user:\(userID)|product:\(productID)"
    }

    init(
        canonicalID: String,
        userID: Int,
        product: ProductSnapshot
    ) {
        self.canonicalID = canonicalID
        self.userID = userID
        self.product = product
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canonicalID = try container.decode(String.self, forKey: .canonicalID)
        userID = try container.decode(Int.self, forKey: .userID)
        product = try container.decode(ProductSnapshot.self, forKey: .product)
        try validateStoreInvariants()
    }

    func validateStoreInvariants() throws {
        guard userID > 0 else {
            throw StoreModelValidationError.invalidUserID
        }
        try product.validateStoreInvariants()
        guard canonicalID == Self.canonicalID(
            userID: userID,
            productID: product.id
        ) else {
            throw StoreModelValidationError.invalidFavoriteIdentity
        }
    }
}
