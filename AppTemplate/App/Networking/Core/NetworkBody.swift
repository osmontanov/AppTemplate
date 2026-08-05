import Foundation

nonisolated
enum NetworkBody: Sendable {
    case json(any Encodable & Sendable)
    case data(Data, contentType: String?)
}
