import Foundation

nonisolated
enum StoreModelValidationError: Error, Equatable, Sendable {
    case invalidProductID
    case invalidPrice
    case invalidUserID
    case invalidFavoriteIdentity
    case invalidCartIdentity
    case invalidRevision
    case invalidQuantity
    case duplicateCartProductID
}

nonisolated
struct ProductSnapshot: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let price: Decimal
    let thumbnailURL: URL?

    init(
        id: Int,
        title: String,
        price: Decimal,
        thumbnailURL: URL?
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.thumbnailURL = thumbnailURL
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        price = try container.decode(Decimal.self, forKey: .price)
        thumbnailURL = try container.decodeIfPresent(
            URL.self,
            forKey: .thumbnailURL
        )
        try validateStoreInvariants()
    }

    func validateStoreInvariants() throws {
        guard id > 0 else {
            throw StoreModelValidationError.invalidProductID
        }
        guard price.isFinite, price >= 0 else {
            throw StoreModelValidationError.invalidPrice
        }
    }
}
