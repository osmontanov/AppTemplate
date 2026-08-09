import Foundation
@testable import AppTemplate

nonisolated
enum RecordedNetworkOutcome: Equatable, Sendable {
    case success(statusCode: Int)
    case unacceptableStatus(statusCode: Int)
    case cancelled
    case nonHTTPResponse
    case transportFailure
    case otherFailure
}

nonisolated
enum RecordedNetworkEvent: Equatable, Sendable {
    case willSend(monitor: String)
    case didComplete(monitor: String, outcome: RecordedNetworkOutcome)
}

nonisolated
enum RecordedNetworkPhase: Equatable, Sendable {
    case willSend
    case didComplete
}

nonisolated
struct RecordedNetworkContextEvent: Sendable {
    let monitor: String
    let phase: RecordedNetworkPhase
    let requestID: UUID
    let request: URLRequest
}

actor NetworkEventRecorder {
    private var events: [RecordedNetworkEvent] = []
    private var contextEvents: [RecordedNetworkContextEvent] = []

    func append(
        _ event: RecordedNetworkEvent,
        monitor: String,
        phase: RecordedNetworkPhase,
        context: NetworkRequestContext
    ) {
        events.append(event)
        contextEvents.append(.init(
            monitor: monitor,
            phase: phase,
            requestID: context.id,
            request: context.request
        ))
    }

    func recordedEvents() -> [RecordedNetworkEvent] { events }
    func recordedContextEvents() -> [RecordedNetworkContextEvent] { contextEvents }
}

nonisolated
struct RecordingNetworkEventMonitor: NetworkEventMonitor {
    let name: String
    let recorder: NetworkEventRecorder

    func willSend(
        context: NetworkRequestContext,
        target: any NetworkTarget
    ) async {
        await recorder.append(
            .willSend(monitor: name),
            monitor: name,
            phase: .willSend,
            context: context
        )
    }

    func didComplete(
        context: NetworkRequestContext,
        result: Result<NetworkResponse, NetworkError>,
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
        case .failure(.nonHTTPResponse):
            outcome = .nonHTTPResponse
        case .failure(.transport):
            outcome = .transportFailure
        case .failure:
            outcome = .otherFailure
        }

        await recorder.append(
            .didComplete(monitor: name, outcome: outcome),
            monitor: name,
            phase: .didComplete,
            context: context
        )
    }
}
