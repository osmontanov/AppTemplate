import Foundation

nonisolated
struct NetworkTask: Sendable {
    let queryItems: [URLQueryItem]
    let body: NetworkBody?

    static let plain = NetworkTask(queryItems: [], body: nil)

    static func query(_ queryItems: [URLQueryItem]) -> NetworkTask {
        NetworkTask(queryItems: queryItems, body: nil)
    }

    static func json<Payload: Encodable & Sendable>(
        _ payload: Payload,
        queryItems: [URLQueryItem] = []
    ) -> NetworkTask {
        NetworkTask(queryItems: queryItems, body: .json(payload))
    }

    static func data(
        _ data: Data,
        contentType: String? = nil,
        queryItems: [URLQueryItem] = []
    ) -> NetworkTask {
        NetworkTask(
            queryItems: queryItems,
            body: .data(data, contentType: contentType)
        )
    }
}
