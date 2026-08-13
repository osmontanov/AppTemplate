import Foundation

nonisolated
protocol NetworkTarget: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: HTTPHeaders { get }
    var shouldHandleCookies: Bool { get }
    var validation: StatusCodeValidation { get }
    var sampleResponse: StubResponse { get }
    var diagnosticDescriptor: NetworkDiagnosticDescriptor? { get }
}

nonisolated
extension NetworkTarget {
    var task: NetworkTask { .plain }
    var headers: HTTPHeaders { [:] }
    var shouldHandleCookies: Bool { true }
    var validation: StatusCodeValidation { .successful }
    var sampleResponse: StubResponse { StubResponse() }
    var diagnosticDescriptor: NetworkDiagnosticDescriptor? { nil }
}
