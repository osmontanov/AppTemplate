import Foundation

nonisolated struct SessionPersistenceRetryToken: Hashable, Sendable {
    private let id: UUID

    init() {
        id = UUID()
    }
}
