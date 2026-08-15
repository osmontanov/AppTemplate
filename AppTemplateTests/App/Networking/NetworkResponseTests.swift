import Foundation
import Testing
@testable import AppTemplate

struct NetworkResponseTests {
    fileprivate static let operationID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000042"
    )!

    @Test
    func decodesModelFromRawData() throws {
        let response = makeResponse(
            data: Data(#"{"id":"example-42","title":"Remote example"}"#.utf8)
        )

        let value = try response.decode(NetworkResponseFixture.self)

        #expect(
            value == NetworkResponseFixture(
                id: "example-42",
                title: "Remote example"
            )
        )
        #expect(response.headers["content-type"] == "application/json")
    }

    @Test
    func decodingFailureRetainsOriginalResponse() {
        let response = makeResponse(data: Data(#"{"id":42}"#.utf8))

        do {
            let _: NetworkResponseFixture = try response.decode(NetworkResponseFixture.self)
            Issue.record("Expected decoding to fail")
        } catch let NetworkError.decoding(underlying, retainedResponse) {
            #expect(underlying is DecodingError)
            #expect(retainedResponse.statusCode == 200)
            #expect(retainedResponse.data == response.data)
            #expect(retainedResponse.request.url == response.request.url)
            #expect(retainedResponse.operationID == Self.operationID)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct NetworkResponseFixture: Decodable, Equatable {
    let id: String
    let title: String
}

private func makeResponse(data: Data) -> NetworkResponse {
    let url = URL(string: "https://api.example.test/examples")!
    return NetworkResponse(
        operationID: NetworkResponseTests.operationID,
        request: URLRequest(url: url),
        url: url,
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        data: data
    )
}
