nonisolated
enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case store
    case services

    var id: Self { self }
}
