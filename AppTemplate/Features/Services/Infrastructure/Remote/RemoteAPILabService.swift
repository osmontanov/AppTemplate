nonisolated
struct RemoteAPILabService: IRemoteAPILabService {
    private let remote: any IRemoteService

    init(remote: any IRemoteService) {
        self.remote = remote
    }

    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO {
        try await remote.products(request)
    }

    func categories() async throws -> [ProductCategoryDTO] {
        try await remote.categories()
    }

    func product(id: Int) async throws -> ProductDTO {
        try await remote.product(id: id)
    }

    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO {
        try await remote.diagnostic(request)
    }
}
