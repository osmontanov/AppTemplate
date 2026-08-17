import Foundation

nonisolated
struct NetworkDiagnosticDescriptor: Equatable, Sendable {
    let operation: String
    let safePath: String
    let queryKeys: [String]
}

nonisolated
enum NetworkDiagnosticFailure: Equatable, Sendable {
    case cancelled
    case transport
    case invalidResponse
    case statusClass(Int)
}

nonisolated
enum NetworkDiagnosticSummary: Equatable, Sendable {
    case productPage(count: Int, total: Int)
    case product(id: Int)
    case categories(count: Int)
    case profile(id: Int)
    case tokenRefresh
    case http(status: Int)
}

nonisolated
struct NetworkDiagnosticEvent: Equatable, Sendable {
    let operationID: UUID
    let operation: String
    let method: HTTPMethod
    let safePath: String
    let queryKeys: [String]
    let statusClass: Int?
    let elapsed: Duration
    let failure: NetworkDiagnosticFailure?
    let summary: NetworkDiagnosticSummary?
}
