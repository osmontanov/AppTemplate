nonisolated
struct ProfileModel: Equatable, Sendable {
    let displayName: String
    let version: String
    let preferences: StorePreferences
}

nonisolated
struct ProfileAccountPresentation: Equatable, Sendable {
    let userID: Int
    let displayName: String
    let availability: SessionAvailability
}
