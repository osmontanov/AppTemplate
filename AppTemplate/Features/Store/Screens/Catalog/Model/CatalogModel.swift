nonisolated
struct CatalogModel: Equatable, Sendable {
    var products: [Product]
    var categories: [ProductCategory]
    var preferences: StorePreferences
    var mode: ProductQueryMode
    var total: Int

    static let empty = CatalogModel(
        products: [], categories: [], preferences: .defaults, mode: .all, total: 0
    )
}

nonisolated
extension StoreCatalogSort {
    var productSort: ProductSort? {
        switch self {
        case .featured: nil
        case .titleAscending: .titleAscending
        case .titleDescending: .titleDescending
        case .priceAscending: .priceAscending
        case .priceDescending: .priceDescending
        }
    }
}
