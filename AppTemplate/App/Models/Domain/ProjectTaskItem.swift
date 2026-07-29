nonisolated
struct ProjectTaskItem: Identifiable, Codable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var title: String
    var isComplete: Bool
}
