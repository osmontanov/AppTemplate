import Foundation
import Testing
@testable import AppTemplate

struct NetworkResponseTests {
    @Test
    func decodesModelFromRawData() throws {
        let response = makeResponse(
            data: Data(#"{"id":"example-42","title":"Remote example"}"#.utf8)
        )

        let value = try response.decode(ExampleResponse.self)

        #expect(
            value == ExampleResponse(
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
            let _: ExampleResponse = try response.decode(ExampleResponse.self)
            Issue.record("Expected decoding to fail")
        } catch let NetworkError.decoding(underlying, retainedResponse) {
            #expect(underlying is DecodingError)
            #expect(retainedResponse.statusCode == 200)
            #expect(retainedResponse.data == response.data)
            #expect(retainedResponse.request.url == response.request.url)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func makeResponse(data: Data) -> NetworkResponse {
    let url = URL(string: "https://api.example.test/examples")!
    return NetworkResponse(
        request: URLRequest(url: url),
        url: url,
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        data: data
    )
}
