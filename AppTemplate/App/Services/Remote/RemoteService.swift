import Foundation

actor RemoteService: IRemoteService {
    nonisolated static let defaultBaseURL = URL(
        string: "https://example.invalid"
    )!

    private let baseURL: URL
    private let provider: NetworkProvider<ExampleTarget>

    init(
        baseURL: URL = RemoteService.defaultBaseURL,
        provider: NetworkProvider<ExampleTarget> = NetworkProvider()
    ) {
        self.baseURL = baseURL
        self.provider = provider
    }

    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse {
        let response = try await provider.request(
            .fetch(baseURL: baseURL, request: request)
        )
        return try response.decode(ExampleResponse.self)
    }
}
