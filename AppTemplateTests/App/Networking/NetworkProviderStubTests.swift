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
        #expect(response.headers == ["X-Stub": "true"])
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
        #expect(response.headers == ["X-Sample": "1"])
        #expect(response.data == Data("sample-1".utf8))
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
