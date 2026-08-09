import Foundation
import Testing
@testable import AppTemplate

struct NetworkProviderStubTests {
    @Test
    func immediateStubRunsAdapterAndMonitorButBypassesTransport() async throws {
        let data = Data(#"{\"source\":\"sample\"}"#.utf8)
        let transport = unexpectedTransport()
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: transport,
            adapters: [StubHeaderAdapter()],
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ],
            stubBehavior: { _ in .immediate }
        )
        let target = StubTarget(
            sampleResponse: StubResponse(
                statusCode: 201,
                data: data,
                headers: ["X-Stub": "true"]
            )
        )

        let response = try await provider.request(target)
        let requests = await transport.recordedRequests()
        let events = await recorder.recordedEvents()

        #expect(response.statusCode == 201)
        #expect(response.data == data)
        #expect(response.headers["x-stub"] == "true")
        #expect(response.request.value(forHTTPHeaderField: "X-Stub-Adapter") == "applied")
        #expect(requests.isEmpty)
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(
                monitor: "observer",
                outcome: .success(statusCode: 201)
            )
        ])
    }

    @Test
    func stubLifecycleContextContainsFinalAdaptedRequestAndOneID() async throws {
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            adapters: [StubHeaderAdapter()],
            monitors: [RecordingNetworkEventMonitor(name: "stub", recorder: recorder)],
            stubBehavior: { _ in .immediate }
        )
        _ = try await provider.request(StubTarget())

        let events = (await recorder.recordedContextEvents()).filter { $0.monitor == "stub" }
        try #require(events.count == 2)
        #expect(events.map(\.phase) == [.willSend, .didComplete])
        #expect(events[0].requestID == events[1].requestID)
        #expect(events[0].request.value(forHTTPHeaderField: "X-Stub-Adapter") == "applied")
        #expect(events[1].request == events[0].request)
    }

    @Test
    func delayedStubUsesInjectedSleepWithoutWallClockWaiting() async throws {
        let sleepRecorder = SleepRecorder()
        let transport = unexpectedTransport()
        let provider = NetworkProvider<StubTarget>(
            transport: transport,
            stubBehavior: { _ in .delayed(.seconds(2)) },
            sleep: { duration in
                await sleepRecorder.record(duration)
            }
        )

        let response = try await provider.request(StubTarget())
        let durations = await sleepRecorder.recordedDurations()
        let requests = await transport.recordedRequests()

        #expect(response.statusCode == 200)
        #expect(durations == [.seconds(2)])
        #expect(requests.isEmpty)
    }

    @Test
    func cancellationDuringDelayedStubIsNormalizedAndMonitored() async {
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ],
            stubBehavior: { _ in .delayed(.seconds(10)) },
            sleep: { _ in throw CancellationError() }
        )

        do {
            _ = try await provider.request(StubTarget())
            Issue.record("Expected delayed stub cancellation")
        } catch NetworkError.cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }

    @Test
    func stubResponseStillUsesTargetStatusValidation() async {
        let body = Data(#"{\"error\":\"unavailable\"}"#.utf8)
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            stubBehavior: { _ in .immediate }
        )
        let target = StubTarget(
            sampleResponse: StubResponse(statusCode: 503, data: body)
        )

        do {
            _ = try await provider.request(target)
            Issue.record("Expected stub validation to fail")
        } catch let NetworkError.unacceptableStatus(response) {
            #expect(response.statusCode == 503)
            #expect(response.data == body)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func wrapsMismatchedSleepNetworkErrorAtExecutionBoundary() async {
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [
                RecordingNetworkEventMonitor(name: "observer", recorder: recorder)
            ],
            stubBehavior: { _ in .delayed(.seconds(1)) },
            sleep: { _ in
                throw NetworkError.requestAdaptation(
                    underlying: StubFixtureError.mismatchedPhase
                )
            }
        )

        do {
            _ = try await provider.request(StubTarget())
            Issue.record("Expected transport failure")
        } catch let NetworkError.transport(underlying) {
            guard case let NetworkError.requestAdaptation(nested) = underlying else {
                Issue.record("Expected mismatched adaptation error to be retained")
                return
            }
            #expect((nested as? StubFixtureError) == .mismatchedPhase)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .transportFailure)
        ])
    }

    @Test
    func immediateStubCapturesComputedSampleResponseOnce() async throws {
        let sampleRecorder = SampleResponseRecorder()
        let provider = NetworkProvider<SnapshotStubTarget>(
            transport: unexpectedTransport(),
            stubBehavior: { _ in .immediate }
        )

        let response = try await provider.request(
            SnapshotStubTarget(sampleRecorder: sampleRecorder)
        )

        #expect(sampleRecorder.readCount == 1)
        #expect(response.statusCode == 201)
        #expect(response.headers["x-sample"] == "1")
        #expect(response.data == Data("sample-1".utf8))
    }

    @Test
    func preCancelledImmediateStubReturnsCancelledWithoutSampleSuccess() async {
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
            stubBehavior: { _ in .immediate }
        )
        let target = StubTarget(sampleResponse: StubResponse(statusCode: 299, data: Data("sample".utf8)))
        let start = ControlledRequestStart()
        let child = controlledRequest(provider: provider, target: target, start: start)

        await start.waitUntilStarted()
        child.cancel()
        await start.permitRequestToContinue()
        let result = await child.value

        guard case let .failure(error) = result, case NetworkError.cancelled = error else {
            Issue.record("Expected cancelled immediate stub")
            return
        }
        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }

    @Test
    func preCancelledDelayedStubSkipsSleepAndSampleSuccess() async {
        let sleepCalls = SleepCallRecorder()
        let recorder = NetworkEventRecorder()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
            stubBehavior: { _ in .delayed(.seconds(1)) },
            sleep: { _ in await sleepCalls.record() }
        )
        let start = ControlledRequestStart()
        let child = controlledRequest(provider: provider, target: StubTarget(), start: start)

        await start.waitUntilStarted()
        child.cancel()
        await start.permitRequestToContinue()
        let result = await child.value

        guard case let .failure(error) = result, case NetworkError.cancelled = error else {
            Issue.record("Expected cancelled delayed stub")
            return
        }
        let sleepCount = await sleepCalls.count
        let events = await recorder.recordedEvents()
        #expect(sleepCount == 0)
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }

    @Test
    func cancellationAfterNoncooperativeDelayedSleepReturnsCancelled() async {
        let recorder = NetworkEventRecorder()
        let sleepStart = ControlledRequestStart()
        let provider = NetworkProvider<StubTarget>(
            transport: unexpectedTransport(),
            monitors: [RecordingNetworkEventMonitor(name: "observer", recorder: recorder)],
            stubBehavior: { _ in .delayed(.seconds(1)) },
            sleep: { _ in await sleepStart.markStartedAndWaitForPermission() }
        )

        let child = Task { () -> Result<NetworkResponse, any Error> in
            do {
                return .success(try await provider.request(StubTarget()))
            } catch {
                return .failure(error)
            }
        }
        await sleepStart.waitUntilStarted()
        child.cancel()
        await sleepStart.permitRequestToContinue()
        let result = await child.value

        guard case let .failure(error) = result, case NetworkError.cancelled = error else {
            Issue.record("Expected cancellation after noncooperative sleep")
            return
        }
        let events = await recorder.recordedEvents()
        #expect(events == [
            .willSend(monitor: "observer"),
            .didComplete(monitor: "observer", outcome: .cancelled)
        ])
    }
}

nonisolated
private struct StubTarget: NetworkTarget {
    let baseURL = URL(string: "https://api.example.test")!
    let path = "/stubbed"
    let method = HTTPMethod.get
    let sampleResponse: StubResponse

    init(sampleResponse: StubResponse = StubResponse()) {
        self.sampleResponse = sampleResponse
    }
}

nonisolated
private struct StubHeaderAdapter: RequestAdapter {
    func adapt(
        _ request: URLRequest,
        target: any NetworkTarget
    ) async throws -> URLRequest {
        var request = request
        request.setValue("applied", forHTTPHeaderField: "X-Stub-Adapter")
        return request
    }
}

nonisolated
private struct SnapshotStubTarget: NetworkTarget {
    let baseURL = URL(string: "https://api.example.test")!
    let path = "/snapshot"
    let method = HTTPMethod.get
    let sampleRecorder: SampleResponseRecorder

    var sampleResponse: StubResponse {
        sampleRecorder.nextResponse()
    }
}

nonisolated
private final class SampleResponseRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var reads = 0

    var readCount: Int {
        lock.withLock { reads }
    }

    func nextResponse() -> StubResponse {
        lock.withLock {
            reads += 1
            return StubResponse(
                statusCode: 200 + reads,
                data: Data("sample-\(reads)".utf8),
                headers: ["X-Sample": String(reads)]
            )
        }
    }
}

private actor SleepRecorder {
    private var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }

    func recordedDurations() -> [Duration] {
        durations
    }
}

private actor SleepCallRecorder {
    private var calls = 0
    func record() { calls += 1 }
    var count: Int { calls }
}

nonisolated
private enum StubFixtureError: Error, Equatable {
    case unexpectedTransport
    case mismatchedPhase
}

private func unexpectedTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw StubFixtureError.unexpectedTransport
    }
}
