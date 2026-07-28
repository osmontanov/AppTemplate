import Foundation
import Testing
@testable import AppTemplate

struct ExampleRemoteModelTests {
    @Test
    func requestEncodesExpectedPayload() throws {
        let request = ExampleRequest(query: "swift", page: 2)

        let data = try JSONEncoder().encode(request)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object.count == 2)
        #expect(object["query"] as? String == "swift")
        #expect(object["page"] as? Int == 2)
    }

    @Test
    func responseDecodesIncomingPayload() throws {
        let data = Data(
            #"{"id":"example-42","title":"Remote example"}"#.utf8
        )

        let response = try JSONDecoder().decode(
            ExampleResponse.self,
            from: data
        )

        #expect(
            response == ExampleResponse(
                id: "example-42",
                title: "Remote example"
            )
        )
    }
}
