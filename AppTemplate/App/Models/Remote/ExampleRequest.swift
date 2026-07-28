nonisolated struct ExampleRequest: Encodable, Equatable, Sendable {
    let query: String
    let page: Int
}
