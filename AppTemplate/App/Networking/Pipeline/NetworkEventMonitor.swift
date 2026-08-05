import Foundation

nonisolated
protocol NetworkEventMonitor: Sendable {
    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async
}

nonisolated
extension NetworkEventMonitor {
    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async {}

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async {}
}
