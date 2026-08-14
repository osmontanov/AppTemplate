nonisolated
struct ProductCategory: Identifiable, Hashable, Sendable {
    let slug: String
    let name: String
    var id: String { slug }
}
