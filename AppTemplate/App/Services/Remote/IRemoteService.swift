nonisolated
protocol IRemoteService: Sendable {
    func fetchExample(
        _ request: ExampleRequest
    ) async throws -> ExampleResponse
}
