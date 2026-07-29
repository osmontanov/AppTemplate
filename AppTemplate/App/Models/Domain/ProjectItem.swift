nonisolated
struct ProjectItem: Identifiable, Codable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var title: String
    var summary: String
    var colorName: String
    var tasks: [ProjectTaskItem]
}
