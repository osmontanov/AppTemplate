actor AsyncOneShotSignal<Value: Sendable> {
    private enum State {
        case unresolved
        case resolved(Value)
    }

    private var state = State.unresolved
    private var waiters: [CheckedContinuation<Value, Never>] = []

    init() {}

    func wait() async -> Value {
        if case let .resolved(value) = state { return value }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    @discardableResult
    func resolve(_ value: Value) -> Bool {
        guard case .unresolved = state else { return false }
        state = .resolved(value)
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume(returning: value)
        }
        return true
    }
}
