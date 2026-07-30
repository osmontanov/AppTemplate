import Foundation
@testable import AppTemplate

nonisolated
final class AppStateStorageSpy:
    IAppStateStorage,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var value: AppStateStorageLoadResult
    private var loadCount = 0
    private var savedValues: [Data] = []
    private var removeCount = 0

    init(loadResult: AppStateStorageLoadResult = .missing) {
        value = loadResult
    }

    func load() -> AppStateStorageLoadResult {
        lock.withLock {
            loadCount += 1
            return value
        }
    }

    func save(_ data: Data) {
        lock.withLock {
            value = .data(data)
            savedValues.append(data)
        }
    }

    func remove() {
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

    var removeCallCount: Int {
        lock.withLock { removeCount }
    }
}
