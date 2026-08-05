import Foundation

nonisolated
enum ExampleTarget: NetworkTarget {
    case fetch(baseURL: URL, request: ExampleRequest)

    var baseURL: URL {
        switch self {
        case let .fetch(baseURL, _):
            baseURL
        }
    }

    var path: String { "/examples" }

    var method: HTTPMethod { .get }

    var task: NetworkTask {
        switch self {
        case let .fetch(_, request):
            .query([
                URLQueryItem(name: "query", value: request.query),
                URLQueryItem(name: "page", value: String(request.page))
            ])
        }
    }

    var sampleResponse: StubResponse {
        StubResponse(
            statusCode: 200,
            data: Data(
                #"{"id":"sample-id","title":"Sample response"}"#.utf8
            ),
            headers: ["Content-Type": "application/json"]
        )
    }
}
