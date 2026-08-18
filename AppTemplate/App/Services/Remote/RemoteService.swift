import Foundation

actor RemoteService: IRemoteService {
    nonisolated static let defaultDummyJSONBaseURL = RemoteOrigin.dummyJSON.baseURL!

    private let origin: RemoteOrigin
    private let dummyJSONBaseURL: URL
    private let dummyJSONProvider: NetworkProvider<DummyJSONTarget>
    private let authenticationProvider: NetworkProvider<DummyJSONTarget>
    nonisolated let diagnosticRecorder: NetworkDiagnosticRecorder?

    init(
        origin: RemoteOrigin = .dummyJSON,
        dummyJSONBaseURL: URL? = nil,
        dummyJSONProvider: NetworkProvider<DummyJSONTarget>? = nil,
        authenticationProvider: NetworkProvider<DummyJSONTarget>? = nil,
        diagnosticRecorder: NetworkDiagnosticRecorder? = nil
    ) {
        self.origin = origin
        self.dummyJSONBaseURL = dummyJSONBaseURL
            ?? origin.baseURL
            ?? RemoteService.defaultDummyJSONBaseURL
        self.diagnosticRecorder = diagnosticRecorder
        self.dummyJSONProvider = dummyJSONProvider ?? NetworkProvider(
            transport: URLSessionTransport.ephemeral(timeout: 15),
            diagnosticRecorder: diagnosticRecorder
        )
        self.authenticationProvider = authenticationProvider ?? NetworkProvider(
            transport: URLSessionTransport.cookieFree(timeout: 15),
            diagnosticRecorder: diagnosticRecorder
        )
    }

    func products(
        _ request: ProductPageRequest
    ) async throws -> ProductPageDTO {
        let response = try await requestMapped(
            .products(baseURL: trustedDummyJSONBaseURL(), request),
            using: dummyJSONProvider
        )
        let value: ProductPageDTO = try decode(response, iso8601Dates: true)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .productPage(
                count: value.products.count,
                total: value.total
            )
        )
        return value
    }

    func categories() async throws -> [ProductCategoryDTO] {
        let response = try await requestMapped(
            .categories(baseURL: trustedDummyJSONBaseURL()),
            using: dummyJSONProvider
        )
        let value: [ProductCategoryDTO] = try decode(response)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .categories(count: value.count)
        )
        return value
    }

    func product(id: Int) async throws -> ProductDTO {
        let response = try await requestMapped(
            .product(baseURL: trustedDummyJSONBaseURL(), id: id),
            using: dummyJSONProvider
        )
        let value: ProductDTO = try decode(response, iso8601Dates: true)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .product(id: value.id)
        )
        return value
    }

    func login(
        _ request: LoginRequestDTO
    ) async throws -> AuthSessionDTO {
        let normalized = LoginRequestDTO(
            username: request.username,
            password: request.password,
            expiresInMins: 30
        )
        let response = try await requestMapped(
            .login(baseURL: trustedDummyJSONBaseURL(), normalized),
            using: authenticationProvider,
            decodesAuthenticationError: true
        )
        let value: AuthSessionDTO = try decode(response)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .profile(id: value.id)
        )
        return value
    }

    func me(accessToken: String) async throws -> UserProfileDTO {
        let response = try await requestMapped(
            .me(
                baseURL: trustedDummyJSONBaseURL(),
                accessToken: accessToken
            ),
            using: authenticationProvider,
            decodesAuthenticationError: true
        )
        let value: UserProfileDTO = try decode(response)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .profile(id: value.id)
        )
        return value
    }

    func refresh(
        _ request: RefreshRequestDTO
    ) async throws -> AuthTokensDTO {
        let normalized = RefreshRequestDTO(
            refreshToken: request.refreshToken,
            expiresInMins: 30
        )
        let response = try await requestMapped(
            .refresh(baseURL: trustedDummyJSONBaseURL(), normalized),
            using: authenticationProvider,
            decodesAuthenticationError: true
        )
        let value: AuthTokensDTO = try decode(response)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .tokenRefresh
        )
        return value
    }

    func diagnostic(
        _ request: HTTPDiagnosticRequest
    ) async throws -> HTTPDiagnosticDTO {
        switch request {
        case let .delay(milliseconds):
            guard (0...5_000).contains(milliseconds) else {
                throw RemoteServiceError.invalidResponse
            }
        case let .status(code):
            guard (100...599).contains(code) else {
                throw RemoteServiceError.invalidResponse
            }
        }
        let response = try await requestMapped(
            .diagnostic(baseURL: trustedDummyJSONBaseURL(), request),
            using: dummyJSONProvider
        )
        let value = HTTPDiagnosticDTO(statusCode: response.statusCode)
        await diagnosticRecorder?.annotate(
            operationID: response.operationID,
            summary: .http(status: response.statusCode)
        )
        return value
    }

    private func trustedDummyJSONBaseURL() throws -> URL {
        guard origin.permits(dummyJSONBaseURL) else {
            throw RemoteServiceError.invalidResponse
        }
        return dummyJSONBaseURL
    }

    private func requestMapped(
        _ target: DummyJSONTarget,
        using provider: NetworkProvider<DummyJSONTarget>,
        decodesAuthenticationError: Bool = false
    ) async throws -> NetworkResponse {
        do {
            return try await provider.request(target)
        } catch let error as NetworkError {
            throw map(
                error,
                decodesAuthenticationError: decodesAuthenticationError
            )
        } catch {
            throw RemoteServiceError.invalidResponse
        }
    }

    private func decode<Value: Decodable>(
        _ response: NetworkResponse,
        iso8601Dates: Bool = false
    ) throws -> Value {
        let decoder = JSONDecoder()
        if iso8601Dates {
            decoder.dateDecodingStrategy = .iso8601
        }
        do {
            return try response.decode(Value.self, using: decoder)
        } catch {
            throw RemoteServiceError.invalidResponse
        }
    }

    private func map(
        _ error: NetworkError,
        decodesAuthenticationError: Bool
    ) -> RemoteServiceError {
        switch error {
        case .cancelled:
            .cancelled
        case .transport:
            .transport
        case let .unacceptableStatus(response):
            .status(
                code: response.statusCode,
                authenticationError: decodesAuthenticationError
                    ? try? JSONDecoder().decode(
                        AuthErrorDTO.self,
                        from: response.data
                    )
                    : nil
            )
        case .requestConstruction,
             .requestEncoding,
             .requestAdaptation,
             .nonHTTPResponse,
             .decoding:
            .invalidResponse
        }
    }
}
