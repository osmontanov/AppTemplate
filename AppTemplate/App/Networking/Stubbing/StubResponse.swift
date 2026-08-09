import Foundation

nonisolated
struct StubResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: HTTPHeaders

    init(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: HTTPHeaders = [:]
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
    }
}
