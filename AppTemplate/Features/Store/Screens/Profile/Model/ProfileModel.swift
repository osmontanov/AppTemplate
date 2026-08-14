nonisolated
struct ProfileModel: Equatable, Sendable {
    let displayName: String
    let version: String
}

nonisolated
enum ProfileError: Equatable, Sendable {
    case signOutDeletionFailed
}

nonisolated
struct ProfileAccountPresentation: Equatable, Sendable {
    let userID: Int
    let displayName: String
    let availability: SessionAvailability
}
