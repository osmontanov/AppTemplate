nonisolated
enum HTTPDiagnosticRequest: Equatable, Sendable {
    case delay(milliseconds: Int)
    case status(code: Int)
}

nonisolated
struct HTTPDiagnosticDTO: Equatable, Sendable {
    let statusCode: Int
}
