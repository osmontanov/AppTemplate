import Foundation

/// Callbacks are sequential and read-only and must return quickly; monitors
/// are responsible for internally enqueuing expensive telemetry.
nonisolated
protocol NetworkEventMonitor: Sendable {
    func willSend(
        context: NetworkRequestContext,
        target: any NetworkTarget
    ) async

    func didComplete(
        context: NetworkRequestContext,
        result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async
}

nonisolated
extension NetworkEventMonitor {
    func willSend(
        context: NetworkRequestContext,
        target: any NetworkTarget
    ) async {}

    func didComplete(
        context: NetworkRequestContext,
        result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async {}
}
