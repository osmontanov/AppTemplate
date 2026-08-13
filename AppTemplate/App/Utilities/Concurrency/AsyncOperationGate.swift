import Foundation

actor AsyncOperationGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct WaiterCountWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var hasOwner = false
    private var waiters: [Waiter] = []
    private var waiterCountWaiters: [WaiterCountWaiter] = []

    func withExclusiveAccess<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    func waitUntilWaiterCountForTesting(_ expectedCount: Int) async {
        precondition(expectedCount >= 0, "Waiter count cannot be negative")
        guard waiters.count != expectedCount else { return }
        await withCheckedContinuation { continuation in
            waiterCountWaiters.append(
                WaiterCountWaiter(
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    private func acquire() async throws {
        try Task.checkCancellation()
        guard hasOwner else {
            hasOwner = true
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, continuation: continuation))
                resumeSatisfiedWaiterCountWaiters()
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
        resumeSatisfiedWaiterCountWaiters()
    }

    private func release() {
        guard !waiters.isEmpty else {
            hasOwner = false
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume()
        resumeSatisfiedWaiterCountWaiters()
    }

    private func resumeSatisfiedWaiterCountWaiters() {
        let count = waiters.count
        let satisfied = waiterCountWaiters.filter { $0.expectedCount == count }
        waiterCountWaiters.removeAll { $0.expectedCount == count }
        for waiter in satisfied { waiter.continuation.resume() }
    }
}
