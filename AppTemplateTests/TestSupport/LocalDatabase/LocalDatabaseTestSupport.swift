import Foundation
import SwiftData
import Synchronization
import Testing
@testable import AppTemplate

nonisolated
func makeInMemoryLocalDatabaseContainer() throws -> ModelContainer {
    try LocalDatabaseContainerFactories.inMemory()()
}

nonisolated
func makeInMemoryLocalStore(
    hooks: LocalDatabaseStoreHooks = .production
) throws -> SwiftDataLocalStore {
    SwiftDataLocalStore(
        modelContainer: try makeInMemoryLocalDatabaseContainer(),
        hooks: hooks
    )
}

nonisolated
func uniqueLocalDatabaseStoreURL(label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(
            path: "AppTemplate-SwiftData-\(label)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory.appending(
        path: "LocalDatabase.store",
        directoryHint: .notDirectory
    )
}

nonisolated
final class LocalDatabaseHookRecorder: Sendable {
    private struct State: Sendable {
        var checkpoints: [LocalDatabaseStoreCheckpoint] = []
        var saves: [LocalDatabaseWriteOperation] = []
        var rollbacks: [LocalDatabaseWriteOperation] = []
    }

    private let state = Mutex(State())
    private let failingCheckpoint: LocalDatabaseStoreCheckpoint?
    private let cancellingCheckpoint: LocalDatabaseStoreCheckpoint?

    init(
        failingCheckpoint: LocalDatabaseStoreCheckpoint? = nil,
        cancellingCheckpoint: LocalDatabaseStoreCheckpoint? = nil
    ) {
        self.failingCheckpoint = failingCheckpoint
        self.cancellingCheckpoint = cancellingCheckpoint
    }

    var checkpoints: [LocalDatabaseStoreCheckpoint] {
        state.withLock { $0.checkpoints }
    }

    var saves: [LocalDatabaseWriteOperation] {
        state.withLock { $0.saves }
    }

    var rollbacks: [LocalDatabaseWriteOperation] {
        state.withLock { $0.rollbacks }
    }

    func hooks() -> LocalDatabaseStoreHooks {
        LocalDatabaseStoreHooks(
            checkpoint: { [self] checkpoint in
                state.withLock { $0.checkpoints.append(checkpoint) }
                if checkpoint == cancellingCheckpoint {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
                if checkpoint == failingCheckpoint {
                    throw LocalDatabaseTestError.injectedFailure
                }
            },
            didSave: { [self] operation in
                state.withLock { $0.saves.append(operation) }
            },
            didRollback: { [self] operation in
                state.withLock { $0.rollbacks.append(operation) }
            }
        )
    }
}

nonisolated
enum LocalDatabaseTestError: Error, Equatable, Sendable {
    case injectedFailure
}
