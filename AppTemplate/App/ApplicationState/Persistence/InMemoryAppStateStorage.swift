import Foundation

nonisolated
final class InMemoryAppStateStorage:
    IAppStateStorage,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var data: Data?

    init(initialData: Data? = nil) {
        data = initialData
    }

    convenience init(initialState: AppState) {
        guard let data = try? JSONEncoder().encode(initialState) else {
            preconditionFailure("Failed to encode initial app state")
        }
        self.init(initialData: data)
    }

    func load() throws -> AppStateStorageLoadResult {
        lock.withLock {
            data.map(AppStateStorageLoadResult.data) ?? .missing
        }
    }

    func save(_ data: Data) throws {
        lock.withLock {
            self.data = data
        }
    }

    func remove() throws {
        lock.withLock {
            data = nil
        }
    }
}
