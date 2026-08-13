nonisolated
protocol IRemoteService: Sendable {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO
    func categories() async throws -> [ProductCategoryDTO]
    func product(id: Int) async throws -> ProductDTO
    func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO
    func me(accessToken: String) async throws -> UserProfileDTO
    func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO
    func diagnostic(
        _ request: HTTPDiagnosticRequest
    ) async throws -> HTTPDiagnosticDTO
}
