nonisolated
struct CartLine: Codable, Equatable, Sendable {
    let product: ProductSnapshot
    var quantity: Int

    init(product: ProductSnapshot, quantity: Int) {
        self.product = product
        self.quantity = quantity
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        product = try container.decode(ProductSnapshot.self, forKey: .product)
        quantity = try container.decode(Int.self, forKey: .quantity)
        try validateStoreInvariants()
    }

    func validateStoreInvariants() throws {
        try product.validateStoreInvariants()
        guard quantity > 0 else {
            throw StoreModelValidationError.invalidQuantity
        }
    }
}
