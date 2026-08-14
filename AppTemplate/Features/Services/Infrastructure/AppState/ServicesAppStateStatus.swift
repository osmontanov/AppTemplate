import Observation

@MainActor
@Observable
final class ServicesAppStateStatus {
    private(set) var lastResult: ServiceLabResult

    init(lastResult: ServiceLabResult = .idle) {
        self.lastResult = lastResult
    }

    func record(_ result: ServiceLabResult) {
        lastResult = result
    }
}
