nonisolated
struct ProductPageDTO: Codable, Equatable, Sendable {
    let products: [ProductDTO]
    let total: Int
    let skip: Int
    let limit: Int
}
