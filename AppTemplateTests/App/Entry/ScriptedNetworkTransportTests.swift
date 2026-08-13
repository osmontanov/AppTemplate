import Foundation
import Testing
@testable import AppTemplate

struct ScriptedNetworkTransportTests {
    @Test
    func matchesNormalizedOriginCanonicalQueryHeadersCookieAndSemanticJSON() async throws {
        let step = ScriptedNetworkStep(
            origin: URL(string: "HTTPS://EXAMPLE.COM:443")!,
            method: .post,
            path: "/items",
            queryItems: [URLQueryItem(name: "b", value: "2"), URLQueryItem(name: "a", value: nil), URLQueryItem(name: "a", value: "")],
            headers: ["Authorization": "Bearer private"],
            shouldHandleCookies: false,
            body: .json(Data(#"{"b":2,"a":1}"#.utf8)),
            result: .response(statusCode: 201, headers: ["Content-Type": "application/json"], body: Data("ok".utf8))
        )
        let transport = ScriptedNetworkTransport(steps: [step])
        var request = URLRequest(url: URL(string: "https://example.com/items?a=&b=2&a")!)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("Bearer private", forHTTPHeaderField: "authorization")
        request.httpBody = Data(#"{"a":1,"b":2}"#.utf8)

        let (data, response) = try await transport.data(for: request)

        #expect(data == Data("ok".utf8))
        #expect((response as? HTTPURLResponse)?.statusCode == 201)
        try await transport.assertExhausted()
    }

    @Test
    func mismatchDoesNotConsumeExpectedStepAndDescriptionsRedactData() async throws {
        let expected = ScriptedNetworkStep(
            origin: URL(string: "https://example.com")!, method: .get,
            path: "/expected", queryItems: [], headers: ["X-Secret": "private"],
            shouldHandleCookies: nil, body: .none,
            result: .response(statusCode: 200, headers: [:], body: Data())
        )
        let transport = ScriptedNetworkTransport(steps: [expected])
        await #expect(throws: ScriptedNetworkTransportError.requestMismatch) {
            _ = try await transport.data(for: URLRequest(url: URL(string: "https://example.com/private")!))
        }
        await #expect(throws: ScriptedNetworkTransportError.unconsumedSteps(1)) {
            try await transport.assertExhausted()
        }
        #expect(!String(describing: ScriptedNetworkTransportError.requestMismatch).contains("private"))
    }

    @Test
    func emptyScriptAndScriptedFailuresFailClosed() async throws {
        let request = URLRequest(url: URL(string: "https://example.com/")!)
        let empty = ScriptedNetworkTransport(steps: [])
        await #expect(throws: ScriptedNetworkTransportError.unexpectedRequest) {
            _ = try await empty.data(for: request)
        }
        let failed = ScriptedNetworkTransport(steps: [
            ScriptedNetworkStep(origin: URL(string: "https://example.com")!, method: .get, path: "/", queryItems: [], headers: [:], shouldHandleCookies: nil, body: .none, result: .failure(.transport))
        ])
        await #expect(throws: ScriptedNetworkFailure.transport) {
            _ = try await failed.data(for: request)
        }
        try await failed.assertExhausted()
    }

    @Test
    func cancellationDoesNotConsumeOrFailTheSharedScript() async throws {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 1, imageSteps: 0)
        let transport = ScriptedNetworkTransport(steps: [
            ScriptedNetworkStep(
                origin: URL(string: "https://example.com")!, method: .get,
                path: "/", queryItems: [], headers: [:],
                shouldHandleCookies: nil, body: .none,
                result: .response(statusCode: 200, headers: [:], body: Data())
            )
        ], tracker: tracker)
        let request = URLRequest(url: URL(string: "https://example.com/")!)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.data(for: request)
        }

        await #expect(throws: ScriptedNetworkFailure.cancelled) {
            _ = try await task.value
        }
        await #expect(throws: ScriptedNetworkTransportError.unconsumedSteps(1)) {
            try await transport.assertExhausted()
        }
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .pending)
    }

    @Test
    func mismatchPermanentlyFailsTheSharedTracker() async {
        let tracker = UITestScriptConsumptionTracker(networkSteps: 1, imageSteps: 0)
        let transport = ScriptedNetworkTransport(steps: [
            ScriptedNetworkStep(
                origin: URL(string: "https://example.com")!, method: .get,
                path: "/expected", queryItems: [], headers: [:],
                shouldHandleCookies: nil, body: .none,
                result: .response(statusCode: 200, headers: [:], body: Data())
            )
        ], tracker: tracker)
        await #expect(throws: ScriptedNetworkTransportError.requestMismatch) {
            _ = try await transport.data(for: URLRequest(url: URL(string: "https://example.com/wrong")!))
        }
        var iterator = await tracker.updates().makeAsyncIterator()
        #expect(await iterator.next() == .failed)
    }
}
