nonisolated
protocol IRemoteAPILabService: Sendable {
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO
    func categories() async throws -> [ProductCategoryDTO]
    func product(id: Int) async throws -> ProductDTO
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO
}
