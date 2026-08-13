import Foundation
import Testing
@testable import AppTemplate

struct AsyncOperationGateTests {
    @Test
    func uncontendedOperationReturnsItsValue() async throws {
        let gate = AsyncOperationGate()

        let value = try await gate.withExclusiveAccess { 42 }

        #expect(value == 42)
    }

    @Test
    func thrownOperationReleasesTheNextWaiter() async throws {
        let gate = AsyncOperationGate()

        await #expect(throws: GateTestError.failed) {
            try await gate.withExclusiveAccess { throw GateTestError.failed }
        }

        let value = try await gate.withExclusiveAccess { 7 }
        #expect(value == 7)
    }

    @Test
    func queuedWaitersAcquireInFIFOOrder() async throws {
        let gate = AsyncOperationGate()
        let blocker = GateBlocker()
        let recorder = GateRecorder()
        let owner = Task {
            try await gate.withExclusiveAccess {
                await blocker.markEnteredAndWait()
            }
        }
        await blocker.waitUntilEntered()

        let first = Task {
            try await gate.withExclusiveAccess {
                await recorder.append(1)
            }
        }
        await gate.waitUntilWaiterCountForTesting(1)
        let second = Task {
            try await gate.withExclusiveAccess {
                await recorder.append(2)
            }
        }
        await gate.waitUntilWaiterCountForTesting(2)

        await blocker.release()
        try await owner.value
        try await first.value
        try await second.value

        #expect(await recorder.values == [1, 2])
    }

    @Test
    func preCancelledWaiterNeverRunsItsOperation() async {
        let gate = AsyncOperationGate()
        let recorder = GateRecorder()

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await gate.withExclusiveAccess {
                await recorder.append(1)
            }
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await recorder.values.isEmpty)
    }

    @Test
    func cancellingMiddleWaiterDoesNotBlockItsSuccessor() async throws {
        let gate = AsyncOperationGate()
        let blocker = GateBlocker()
        let recorder = GateRecorder()
        let owner = Task {
            try await gate.withExclusiveAccess {
                await blocker.markEnteredAndWait()
            }
        }
        await blocker.waitUntilEntered()

        let first = Task {
            try await gate.withExclusiveAccess {
                await recorder.append(1)
            }
        }
        await gate.waitUntilWaiterCountForTesting(1)
        let cancelled = Task {
            try await gate.withExclusiveAccess {
                await recorder.append(2)
            }
        }
        await gate.waitUntilWaiterCountForTesting(2)
        let successor = Task {
            try await gate.withExclusiveAccess {
                await recorder.append(3)
            }
        }
        await gate.waitUntilWaiterCountForTesting(3)

        cancelled.cancel()
        await gate.waitUntilWaiterCountForTesting(2)
        await blocker.release()

        try await owner.value
        try await first.value
        await #expect(throws: CancellationError.self) {
            try await cancelled.value
        }
        try await successor.value
        #expect(await recorder.values == [1, 3])
    }
}

private enum GateTestError: Error {
    case failed
}

private actor GateRecorder {
    private(set) var values: [Int] = []

    func append(_ value: Int) {
        values.append(value)
    }
}

private actor GateBlocker {
    private var entered = false
    private var released = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markEnteredAndWait() async {
        entered = true
        let waiters = enteredWaiters
        enteredWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !released else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
}
