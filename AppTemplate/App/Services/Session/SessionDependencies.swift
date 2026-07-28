nonisolated struct SessionDependencies: Sendable {
    let service: any ISessionService

    init(service: any ISessionService) {
        self.service = service
    }
}
