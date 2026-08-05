import Foundation
import Testing
@testable import AppTemplate

struct NetworkRequestBuilderTests {
    @Test
    func buildsJSONRequestWithEncodedQueryAndTargetHeaders() throws {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "https://api.example.test/v1")!,
            path: "/items",
            method: .post,
            task: .json(
                Payload(name: "Moya replacement"),
                queryItems: [
                    URLQueryItem(name: "q", value: "swift moya"),
                    URLQueryItem(name: "page", value: "2")
                ]
            ),
            headers: ["X-Client": "AppTemplate"]
        )

        let request = try NetworkRequestBuilder().build(target)
        let body = try #require(request.httpBody)
        let object = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(
            request.url?.absoluteString ==
                "https://api.example.test/v1/items?q=swift%20moya&page=2"
        )
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Client") == "AppTemplate")
        #expect(object == ["name": "Moya replacement"])
    }

    @Test
    func plainRequestHasNoBodyOrGeneratedContentType() throws {
        let request = try NetworkRequestBuilder().build(
            RequestBuilderTarget(task: .plain)
        )

        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test
    func preservesBaseQueryWhenAppendingTargetQuery() throws {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "https://api.example.test/v1?locale=en")!,
            path: "/items",
            task: .query([URLQueryItem(name: "page", value: "3")])
        )

        let request = try NetworkRequestBuilder().build(target)
        let queryItems = URLComponents(
            url: try #require(request.url),
            resolvingAgainstBaseURL: false
        )?.queryItems

        #expect(queryItems?.first { $0.name == "locale" }?.value == "en")
        #expect(queryItems?.first { $0.name == "page" }?.value == "3")
    }

    @Test
    func usesConfiguredJSONEncoderFactory() throws {
        let builder = NetworkRequestBuilder {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }
        let target = RequestBuilderTarget(
            task: .json(CamelCasePayload(itemName: "Configured"))
        )

        let request = try builder.build(target)
        let body = try #require(request.httpBody)
        let object = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(object == ["item_name": "Configured"])
    }

    @Test(arguments: [
        MethodExpectation(method: .get, rawValue: "GET"),
        MethodExpectation(method: .post, rawValue: "POST"),
        MethodExpectation(method: .put, rawValue: "PUT"),
        MethodExpectation(method: .patch, rawValue: "PATCH"),
        MethodExpectation(method: .delete, rawValue: "DELETE"),
        MethodExpectation(method: .head, rawValue: "HEAD")
    ])
    func writesEverySupportedHTTPMethod(_ expectation: MethodExpectation) throws {
        let target = RequestBuilderTarget(method: expectation.method)

        let request = try NetworkRequestBuilder().build(target)

        #expect(request.httpMethod == expectation.rawValue)
    }

    @Test
    func buildsRawBodyAndAllowsCaseInsensitiveContentTypeOverride() throws {
        let payload = Data([0x01, 0x02, 0x03])
        let target = RequestBuilderTarget(
            path: "/upload",
            method: .put,
            task: .data(payload, contentType: "application/octet-stream"),
            headers: ["content-type": "application/vnd.example.binary"]
        )

        let request = try NetworkRequestBuilder().build(target)

        #expect(request.httpBody == payload)
        #expect(
            request.value(forHTTPHeaderField: "Content-Type") ==
                "application/vnd.example.binary"
        )
    }

    @Test
    func rejectsRelativeBaseURL() {
        let target = RequestBuilderTarget(
            baseURL: URL(string: "relative-base")!
        )

        do {
            _ = try NetworkRequestBuilder().build(target)
            Issue.record("Expected request construction to fail")
        } catch NetworkError.requestConstruction {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func wrapsJSONEncodingFailure() {
        let target = RequestBuilderTarget(task: .json(ThrowingPayload()))

        do {
            _ = try NetworkRequestBuilder().build(target)
            Issue.record("Expected request encoding to fail")
        } catch let NetworkError.requestEncoding(underlying) {
            #expect(underlying is TestEncodingError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

nonisolated
struct MethodExpectation: Sendable, CustomTestStringConvertible {
    let method: HTTPMethod
    let rawValue: String

    var testDescription: String { rawValue }
}

nonisolated
private struct RequestBuilderTarget: NetworkTarget {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let task: NetworkTask
    let headers: [String: String]

    init(
        baseURL: URL = URL(string: "https://api.example.test")!,
        path: String = "/resource",
        method: HTTPMethod = .get,
        task: NetworkTask = .plain,
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.task = task
        self.headers = headers
    }
}

nonisolated
private struct Payload: Encodable, Sendable {
    let name: String
}

nonisolated
private struct CamelCasePayload: Encodable, Sendable {
    let itemName: String
}

nonisolated
private struct ThrowingPayload: Encodable, Sendable {
    func encode(to encoder: Encoder) throws {
        throw TestEncodingError.expected
    }
}

nonisolated
private enum TestEncodingError: Error {
    case expected
}
