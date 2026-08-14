nonisolated
struct AuthenticationModel:
    Equatable,
    Sendable,
    CustomStringConvertible {
    var username: String
    var password: String

    var description: String {
        "AuthenticationModel(username: \(username), password: <redacted>)"
    }
}
