import Foundation

nonisolated
protocol NetworkTarget: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String] { get }
    var validation: StatusCodeValidation { get }
    var sampleResponse: StubResponse { get }
}

nonisolated
extension NetworkTarget {
    var task: NetworkTask { .plain }
    var headers: [String: String] { [:] }
    var validation: StatusCodeValidation { .successful }
    var sampleResponse: StubResponse { StubResponse() }
}
