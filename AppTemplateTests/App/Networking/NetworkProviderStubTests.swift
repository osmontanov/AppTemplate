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
private enum StubFixtureError: Error {
    case unexpectedTransport
}

private func unexpectedTransport() -> InMemoryNetworkTransport {
    InMemoryNetworkTransport { _ in
        throw StubFixtureError.unexpectedTransport
    }
}
