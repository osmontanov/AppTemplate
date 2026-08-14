nonisolated
struct ProductQuery: Equatable, Sendable {
    let mode: ProductQueryMode
    let sort: ProductSort?
    let limit: Int
    let skip: Int
}

nonisolated
struct ProductPage: Equatable, Sendable {
    let products: [Product]
    let total: Int
    let skip: Int
    let limit: Int
}
