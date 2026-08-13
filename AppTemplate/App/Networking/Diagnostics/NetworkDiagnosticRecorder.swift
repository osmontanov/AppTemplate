import Foundation

actor NetworkDiagnosticRecorder {
    private let capacity: Int
    private var storedEvents: [NetworkDiagnosticEvent] = []

    init(capacity: Int = 100) {
        self.capacity = max(0, capacity)
    }

    func record(_ event: NetworkDiagnosticEvent) {
        guard capacity > 0 else { return }
        storedEvents.append(event)
        if storedEvents.count > capacity {
            storedEvents.removeFirst(storedEvents.count - capacity)
        }
    }

    func annotate(
        operationID: UUID,
        summary: NetworkDiagnosticSummary
    ) {
        guard let index = storedEvents.firstIndex(where: {
            $0.operationID == operationID
        }) else { return }
        let event = storedEvents[index]
        storedEvents[index] = NetworkDiagnosticEvent(
            operationID: event.operationID,
            operation: event.operation,
            method: event.method,
            safePath: event.safePath,
            queryKeys: event.queryKeys,
            statusClass: event.statusClass,
            elapsed: event.elapsed,
            failure: event.failure,
            summary: summary
        )
    }

    func events() -> [NetworkDiagnosticEvent] {
        storedEvents
    }

    func clear() {
        storedEvents.removeAll(keepingCapacity: true)
    }
}
