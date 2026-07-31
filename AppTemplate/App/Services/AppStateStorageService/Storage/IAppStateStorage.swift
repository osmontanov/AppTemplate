import Foundation

nonisolated
protocol IAppStateStorage: Sendable {
    func load() -> AppStateStorageLoadResult
    func save(_ data: Data)
    func remove()
}
