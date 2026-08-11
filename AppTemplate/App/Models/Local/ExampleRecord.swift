nonisolated
struct ExampleRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let payload: String
}
