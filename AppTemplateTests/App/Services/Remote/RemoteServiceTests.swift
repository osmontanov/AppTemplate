import Foundation
import Testing
@testable import AppTemplate

struct RemoteServiceTests {
    @Test
    func fetchExampleBuildsTargetQueryAndDecodesTransportResponse() async throws {
        let responseData = Data(
            #"{"id":"example-42","title":"Remote example"}"#.utf8
        )
        let transport = InMemoryNetworkTransport { request in
            let url = request.url ?? URL(string: "https://api.example.test")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (responseData, response)
        }
        let provider = NetworkProvider<ExampleTarget>(transport: transport)
        let service = RemoteService(
            baseURL: URL(string: "https://api.example.test/v1")!,
            provider: provider
        )

        let response = try await service.fetchExample(
            ExampleRequest(query: "swift moya", page: 2)
        )
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)
        let queryItems = URLComponents(
            url: try #require(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems

        #expect(
            response == ExampleResponse(
                id: "example-42",
                title: "Remote example"
            )
        )
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/v1/examples")
        #expect(queryItems?.first { $0.name == "query" }?.value == "swift moya")
        #expect(queryItems?.first { $0.name == "page" }?.value == "2")
    }

    @Test
    func fetchExampleSampleResponseDecodesWithoutTransport() async throws {
        let transport = unexpectedRemoteTransport()
        let provider = NetworkProvider<ExampleTarget>(
            transport: transport,
            stubBehavior: { _ in .immediate }
        )
        let service = RemoteService(
            baseURL: URL(string: "https://api.example.test")!,
            provider: provider
        )

        let response = try await service.fetchExample(
            ExampleRequest(query: "sample", page: 1)
        )
        let requests = await transport.recordedRequests()

        #expect(
            response == ExampleResponse(
                id: "sample-id",
                title: "Sample response"
            )
        )
        #expect(requests.isEmpty)
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
