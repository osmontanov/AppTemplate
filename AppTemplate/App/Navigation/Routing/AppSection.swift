enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case home
    case browse
    case projects
    case settings

    var id: Self { self }
}
