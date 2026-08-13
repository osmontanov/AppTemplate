import Foundation

nonisolated
struct LoginRequestDTO: Codable, Equatable, Sendable {
    let username: String
    let password: String
    let expiresInMins: Int
}

nonisolated
struct UserProfileDTO: Codable, Equatable, Sendable {
    let id: Int
    let username: String
    let firstName: String
    let lastName: String
    let email: String
    let image: URL?
}

nonisolated
struct AuthSessionDTO: Codable, Equatable, Sendable {
    let id: Int
    let username: String
    let firstName: String
    let lastName: String
    let email: String
    let image: URL?
    let accessToken: String
    let refreshToken: String
}

nonisolated
struct RefreshRequestDTO: Codable, Equatable, Sendable {
    let refreshToken: String
    let expiresInMins: Int
}

nonisolated
struct AuthTokensDTO: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}

nonisolated
struct AuthErrorDTO: Codable, Equatable, Sendable {
    let message: String
}
