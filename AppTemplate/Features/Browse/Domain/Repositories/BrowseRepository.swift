nonisolated protocol BrowseRepository: Sendable {
    func items() async throws -> [BrowseItem]
    func item(id: BrowseItem.ID) async throws -> BrowseItem?
}
