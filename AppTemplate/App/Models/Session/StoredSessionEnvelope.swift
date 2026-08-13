import Foundation

nonisolated struct StoredSessionEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let profile: UserProfile
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: Date?
    let refreshExpiresAt: Date?
}
