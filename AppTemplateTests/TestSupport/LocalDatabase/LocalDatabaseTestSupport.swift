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

nonisolated
final class LocalDatabaseContainerFactoryRecorder: Sendable {
    private let callCounter = Mutex(0)
    private let make: @Sendable (Int) throws -> ModelContainer

    init(
        make: @escaping @Sendable (Int) throws -> ModelContainer
    ) {
        self.make = make
    }

    var callCount: Int {
        callCounter.withLock { $0 }
    }

    var factory: LocalDatabaseContainerFactory {
        { [self] in
            let invocation = callCounter.withLock {
                $0 += 1
                return $0
            }
            return try make(invocation)
        }
    }

    func configuration(
        registry: LocalDatabaseModelRegistry = .production
    ) -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: factory,
            modelRegistry: registry
        )
    }
}

nonisolated
enum LocalDatabasePreCancelledInvocation:
    CaseIterable,
    CustomTestStringConvertible,
    Sendable
{
    case fetchOne
    case fetchMany
    case upsertOne
    case upsertBatch
    case deleteOne
    case deleteAll

    var testDescription: String { String(describing: self) }

    func invoke(on service: any ILocalDatabaseService) async throws {
        switch self {
        case .fetchOne:
            _ = try await service.fetchRecord(id: "record-1")
        case .fetchMany:
            _ = try await service.fetchRecords(matching: ExampleQuery())
        case .upsertOne:
            try await service.upsert(
                ExampleRecord(id: "record-1", payload: "value")
            )
        case .upsertBatch:
            try await service.upsert([
                ExampleRecord(id: "record-1", payload: "value")
            ])
        case .deleteOne:
            _ = try await service.deleteRecord(id: "record-1")
        case .deleteAll:
            _ = try await service.deleteAllRecords()
        }
    }
}

private actor ControlledLocalDatabaseOperationStart {
    private var didStart = false
    private var isReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func suspendBeforeOperation() async {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !isReleased else { return }
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        isReleased = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

nonisolated
func resultOfPreCancelledChildTask<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> Result<Value, any Error> {
    let gate = ControlledLocalDatabaseOperationStart()
    let child = Task {
        await gate.suspendBeforeOperation()
        do {
            return Result<Value, any Error>.success(try await operation())
        } catch {
            return Result<Value, any Error>.failure(error)
        }
    }

    await gate.waitUntilStarted()
    child.cancel()
    await gate.release()
    return await child.value
}
