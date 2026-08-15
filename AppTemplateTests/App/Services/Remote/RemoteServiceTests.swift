import Foundation
import Testing
@testable import AppTemplate

struct RemoteServiceTests {
    @Test
    func defaultBoundaryUsesTheTrustedDummyJSONCategoriesEndpoint() async throws {
        let responseData = Data(#"[]"#.utf8)
        let transport = InMemoryNetworkTransport { request in
            let url = request.url ?? URL(string: "https://dummyjson.com")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (responseData, response)
        }
        let recorder = NetworkDiagnosticRecorder()
        let dummyProvider = NetworkProvider<DummyJSONTarget>(
            transport: transport,
            diagnosticRecorder: recorder
        )
        let service = RemoteService(
            dummyJSONProvider: dummyProvider,
            authenticationProvider: NetworkProvider(
                transport: unexpectedRemoteTransport()
            ),
            diagnosticRecorder: recorder
        )

        let categories = try await service.categories()
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)

        #expect(categories.isEmpty)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://dummyjson.com/products/categories")
    }
}

nonisolated
private enum RemoteFixtureError: Error {
    case unexpectedTransport
}

private func unexpectedRemoteTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw RemoteFixtureError.unexpectedTransport
    }
}
