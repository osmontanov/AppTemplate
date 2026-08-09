import Foundation

nonisolated
struct NetworkRequestContext: Sendable {
    let id: UUID
    let request: URLRequest
}
