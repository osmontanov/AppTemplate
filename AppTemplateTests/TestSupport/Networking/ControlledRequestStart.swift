import Foundation
@testable import AppTemplate

actor ControlledRequestStart {
    private var started = false
    private var permitted = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var permitWaiter: CheckedContinuation<Void, Never>?

    func markStartedAndWaitForPermission() async {
        started = true
        startWaiter?.resume()
        startWaiter = nil
        guard !permitted else { return }
        await withCheckedContinuation { permitWaiter = $0 }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func permitRequestToContinue() {
        permitted = true
        permitWaiter?.resume()
        permitWaiter = nil
    }
}

nonisolated
func controlledRequest<Target: NetworkTarget>(
    provider: NetworkProvider<Target>,
    target: Target,
    start: ControlledRequestStart
) -> Task<Result<NetworkResponse, any Error>, Never> {
    Task {
        await start.markStartedAndWaitForPermission()
        do {
            return .success(try await provider.request(target))
        } catch {
            return .failure(error)
        }
    }
}
