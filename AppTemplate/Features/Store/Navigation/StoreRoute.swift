import Foundation

nonisolated
enum StoreRoute: NavigationRoute {
    case product(Int)
    case reviews(Int)
    case favorites
    case cart
    case profile

    private enum CodingKeys: String, CodingKey {
        case tag
        case productID
    }

    private enum Tag: String, Codable {
        case product
        case reviews
        case favorites
        case cart
        case profile
    }

    init(from decoder: Decoder) throws {
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        let tagKey = DynamicCodingKey(stringValue: CodingKeys.tag.rawValue)!
        let tag = try dynamic.decode(Tag.self, forKey: tagKey)
        let allowed = tag == .product || tag == .reviews
            ? Set(["tag", "productID"])
            : Set(["tag"])
        try dynamic.rejectUnknownKeys(allowed: allowed)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch tag {
        case .product, .reviews:
            let productID = try container.decode(Int.self, forKey: .productID)
            guard productID > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .productID,
                    in: container,
                    debugDescription: "Product identifiers must be positive."
                )
            }
            self = tag == .product ? .product(productID) : .reviews(productID)
        case .favorites:
            self = .favorites
        case .cart:
            self = .cart
        case .profile:
            self = .profile
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .product(productID):
            try Self.validate(productID)
            try container.encode(Tag.product, forKey: .tag)
            try container.encode(productID, forKey: .productID)
        case let .reviews(productID):
            try Self.validate(productID)
            try container.encode(Tag.reviews, forKey: .tag)
            try container.encode(productID, forKey: .productID)
        case .favorites:
            try container.encode(Tag.favorites, forKey: .tag)
        case .cart:
            try container.encode(Tag.cart, forKey: .tag)
        case .profile:
            try container.encode(Tag.profile, forKey: .tag)
        }
    }

    private static func validate(_ productID: Int) throws {
        guard productID > 0 else {
            throw EncodingError.invalidValue(
                productID,
                .init(codingPath: [], debugDescription: "Product identifiers must be positive.")
            )
        }
    }
}

nonisolated
struct DynamicCodingKey: CodingKey, Hashable, Sendable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

nonisolated
extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func rejectUnknownKeys(allowed: Set<String>) throws {
        let unknown = allKeys.filter { !allowed.contains($0.stringValue) }
        guard let key = unknown.first else { return }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Unsupported key: \(key.stringValue)"
        )
    }
}
