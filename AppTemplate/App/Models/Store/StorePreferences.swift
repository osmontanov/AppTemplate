nonisolated enum StoreCatalogLayout: String, CaseIterable, Codable, Equatable, Sendable {
    case grid, list
}

nonisolated enum StoreCatalogSort: String, CaseIterable, Codable, Equatable, Sendable {
    case featured, titleAscending, titleDescending, priceAscending, priceDescending
}

nonisolated struct StorePreferences: Equatable, Sendable {
    let layout: StoreCatalogLayout
    let sort: StoreCatalogSort
    let preferredRemotePageSize: Int

    static let defaults = StorePreferences(
        layout: .grid,
        sort: .featured,
        preferredRemotePageSize: 20
    )
}
