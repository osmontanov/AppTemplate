import Foundation
@testable import AppTemplate

nonisolated
enum RecordedNetworkOutcome: Equatable, Sendable {
    case success(statusCode: Int)
    case unacceptableStatus(statusCode: Int)
    case cancelled
    case otherFailure
}

nonisolated
enum RecordedNetworkEvent: Equatable, Sendable {
    case willSend(monitor: String)
    case didComplete(monitor: String, outcome: RecordedNetworkOutcome)
}

actor NetworkEventRecorder {
    private var events: [RecordedNetworkEvent] = []

    func append(_ event: RecordedNetworkEvent) {
        events.append(event)
    }

    func recordedEvents() -> [RecordedNetworkEvent] {
        events
    }
}

nonisolated
struct RecordingNetworkEventMonitor: NetworkEventMonitor {
    let name: String
    let recorder: NetworkEventRecorder

    func willSend(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async {
        await recorder.append(.willSend(monitor: name))
    }

    func didComplete(
        _ result: Result<NetworkResponse, NetworkError>,
        target: any NetworkTarget
    ) async {
        let outcome: RecordedNetworkOutcome
        switch result {
        case let .success(response):
            outcome = .success(statusCode: response.statusCode)
        case let .failure(.unacceptableStatus(response)):
            outcome = .unacceptableStatus(statusCode: response.statusCode)
        case .failure(.cancelled):
            outcome = .cancelled
        case .failure:
            outcome = .otherFailure
        }

        await recorder.append(
            .didComplete(monitor: name, outcome: outcome)
        )
    }
}
