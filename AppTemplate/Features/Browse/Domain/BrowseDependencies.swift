nonisolated struct BrowseDependencies: Sendable {
    let repository: any BrowseRepository

    init(repository: any BrowseRepository) {
        self.repository = repository
    }
}
