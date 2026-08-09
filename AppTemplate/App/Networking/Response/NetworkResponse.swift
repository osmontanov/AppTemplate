import Foundation

nonisolated
struct NetworkResponse: Sendable {
    let request: URLRequest
    let url: URL?
    let statusCode: Int
    let headers: HTTPHeaders
    let data: Data

    func decode<Value: Decodable>(
        _ type: Value.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decoding(
                underlying: error,
                response: self
            )
        }
    }
}
