nonisolated
struct ProductDetailModel: Equatable, Sendable {
    let product: Product
    let related: [Product]
}
