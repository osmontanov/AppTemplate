import Foundation

nonisolated enum UITestScriptComponent: Sendable {
    case network
    case image
}

nonisolated enum UITestScriptConsumptionPresentation: Equatable, Sendable {
    case pending
    case exhausted
    case failed
}

actor UITestScriptConsumptionTracker {
    private var networkSteps: Int
    private var imageSteps: Int
    private var hasFailed = false
    private var continuations: [UUID: AsyncStream<UITestScriptConsumptionPresentation>.Continuation] = [:]

    init(networkSteps: Int, imageSteps: Int) {
        precondition(networkSteps >= 0 && imageSteps >= 0)
        self.networkSteps = networkSteps
        self.imageSteps = imageSteps
    }

    func didConsume(_ component: UITestScriptComponent) {
        guard !hasFailed else {
            publish(.failed)
            return
        }
        switch component {
        case .network: networkSteps = max(0, networkSteps - 1)
        case .image: imageSteps = max(0, imageSteps - 1)
        }
        publish(currentPresentation)
    }

    func didFail(_ component: UITestScriptComponent) {
        _ = component
        hasFailed = true
        publish(.failed)
    }

    func updates() -> AsyncStream<UITestScriptConsumptionPresentation> {
        let id = UUID()
        let current = currentPresentation
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private var currentPresentation: UITestScriptConsumptionPresentation {
        if hasFailed { return .failed }
        return networkSteps == 0 && imageSteps == 0 ? .exhausted : .pending
    }

    private func publish(_ value: UITestScriptConsumptionPresentation) {
        for continuation in continuations.values { continuation.yield(value) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
