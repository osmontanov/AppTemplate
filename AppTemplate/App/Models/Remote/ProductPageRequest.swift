nonisolated
enum ProductQueryMode: Equatable, Sendable {
    case all
    case search(String)
    case category(String)
}

nonisolated
enum ProductSort: String, CaseIterable, Codable, Equatable, Sendable {
    case titleAscending
    case titleDescending
    case priceAscending
    case priceDescending
}

nonisolated
struct ProductPageRequest: Equatable, Sendable {
    let mode: ProductQueryMode
    let sort: ProductSort?
    let limit: Int
    let skip: Int
}
