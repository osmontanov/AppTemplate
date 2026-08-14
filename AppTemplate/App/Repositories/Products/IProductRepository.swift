nonisolated
protocol IProductRepository: Sendable {
    func categories() async throws -> [ProductCategory]
    func page(_ query: ProductQuery) async throws -> ProductPage
    func product(id: Product.ID) async throws -> Product
    func related(to product: Product, limit: Int) async throws -> [Product]
}
