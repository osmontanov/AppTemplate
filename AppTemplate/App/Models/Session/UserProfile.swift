import Foundation

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    let id: Int
    let username: String
    let firstName: String
    let lastName: String
    let imageURL: URL?
}
