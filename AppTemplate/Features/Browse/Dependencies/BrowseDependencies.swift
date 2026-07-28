nonisolated struct BrowseDependencies: Sendable {
    let service: any IBrowseService

    init(service: any IBrowseService) {
        self.service = service
    }
}
