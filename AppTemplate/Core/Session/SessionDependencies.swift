nonisolated struct SessionDependencies: Sendable {
    let service: any SessionService

    init(service: any SessionService) {
        self.service = service
    }
}
