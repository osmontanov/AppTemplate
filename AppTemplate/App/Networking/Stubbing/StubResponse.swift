import Foundation

nonisolated
struct StubResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]

    init(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }
}
