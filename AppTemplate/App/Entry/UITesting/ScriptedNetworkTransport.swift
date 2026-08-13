import Foundation

nonisolated enum ScriptedNetworkTransportError: Error, Equatable, Sendable {
    case unexpectedRequest
    case requestMismatch
    case unconsumedSteps(Int)
}

actor ScriptedNetworkTransport: NetworkTransport {
    private var remaining: [ScriptedNetworkStep]
    private let tracker: UITestScriptConsumptionTracker?

    init(steps: [ScriptedNetworkStep], tracker: UITestScriptConsumptionTracker? = nil) {
        remaining = steps
        self.tracker = tracker
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard !Task.isCancelled else { throw ScriptedNetworkFailure.cancelled }
        guard let step = remaining.first else {
            await tracker?.didFail(.network)
            throw ScriptedNetworkTransportError.unexpectedRequest
        }
        guard step.matches(request) else {
            await tracker?.didFail(.network)
            throw ScriptedNetworkTransportError.requestMismatch
        }
        guard !Task.isCancelled else { throw ScriptedNetworkFailure.cancelled }
        let matched = remaining.removeFirst()
        await tracker?.didConsume(.network)
        return try matched.response(for: request)
    }

    func assertExhausted() throws {
        guard remaining.isEmpty else {
            throw ScriptedNetworkTransportError.unconsumedSteps(remaining.count)
        }
    }
}
