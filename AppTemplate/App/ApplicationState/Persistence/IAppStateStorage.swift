import Foundation

nonisolated
protocol IAppStateStorage: Sendable {
    func load() throws -> AppStateStorageLoadResult
    func save(_ data: Data) throws
    func remove() throws
}

nonisolated
enum AppStatePersistenceFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
    case encodingFailed
    case unsupportedFutureSchema(Int)
}

nonisolated
enum AppStatePersistenceStatus: Equatable, Sendable {
    case writable
    case readOnly(AppStatePersistenceFailure)
}

nonisolated
enum AppStateMutationResult: Equatable, Sendable {
    case unchanged
    case persisted
    case rejected(AppStatePersistenceFailure)
}
