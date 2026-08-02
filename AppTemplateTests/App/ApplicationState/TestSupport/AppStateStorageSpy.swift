import Foundation
@testable import AppTemplate

nonisolated
final class AppStateStorageSpy:
    IAppStateStorage,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var value: AppStateStorageLoadResult
    private let loadError: (any Error)?
    private let saveError: (any Error)?
    private var loadCount = 0
    private var savedValues: [Data] = []
    private var removeCount = 0

    init(
        loadResult: AppStateStorageLoadResult = .missing,
        loadError: (any Error)? = nil,
        saveError: (any Error)? = nil
    ) {
        value = loadResult
        self.loadError = loadError
        self.saveError = saveError
    }

    func load() throws -> AppStateStorageLoadResult {
        try lock.withLock {
            loadCount += 1
            if let loadError {
                throw loadError
            }
            return value
        }
    }

    func save(_ data: Data) throws {
        try lock.withLock {
            if let saveError {
                throw saveError
            }
            value = .data(data)
            savedValues.append(data)
        }
    }

    func remove() throws {
        lock.withLock {
            value = .missing
            removeCount += 1
        }
    }

    var loadCallCount: Int {
        lock.withLock { loadCount }
    }

    var savedData: [Data] {
        lock.withLock { savedValues }
    }

    var currentData: Data? {
        lock.withLock {
            guard case let .data(data) = value else {
                return nil
            }
            return data
        }
    }

    var removeCallCount: Int {
        lock.withLock { removeCount }
    }
}
