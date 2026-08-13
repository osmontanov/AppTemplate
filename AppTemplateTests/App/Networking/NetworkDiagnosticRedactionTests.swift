import Foundation
import Testing
@testable import AppTemplate

struct NetworkDiagnosticRedactionTests {
    @Test
    func recorderBoundsEventsAndAnnotatesInPlace() async throws {
        let recorder = NetworkDiagnosticRecorder(capacity: 2)
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        await recorder.record(event(id: firstID, operation: "first"))
        await recorder.record(event(id: secondID, operation: "second"))
        await recorder.record(event(id: thirdID, operation: "third"))
        await recorder.annotate(
            operationID: thirdID,
            summary: .productPage(count: 2, total: 17)
        )
        await recorder.annotate(
            operationID: firstID,
            summary: .product(id: 1)
        )

        let events = await recorder.events()
        #expect(events.map(\.operationID) == [secondID, thirdID])
        #expect(events[0].summary == nil)
        #expect(events[1].summary == .productPage(count: 2, total: 17))

        await recorder.clear()
        #expect(await recorder.events().isEmpty)
    }

    @Test
    func diagnosticsCannotContainSentinelsFromRequestsTargetsResponsesOrErrors() async {
        let secrets = [
            "url-secret", "header-secret", "password-secret", "body-secret",
            "target-secret", "success-secret", "error-bytes-secret",
            "nested-error-secret"
        ]
        let recorder = NetworkDiagnosticRecorder()
        let successProvider = NetworkProvider<SecretDiagnosticTarget>(
            transport: InMemoryNetworkTransport { request in
                let url = request.url!
                return (
                    Data(#"{"value":"success-secret"}"#.utf8),
                    HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["X-Response": "header-secret"]
                    )!
                )
            },
            diagnosticRecorder: recorder
        )
        let statusProvider = NetworkProvider<SecretDiagnosticTarget>(
            transport: InMemoryNetworkTransport { request in
                (
                    Data("error-bytes-secret".utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 503,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            },
            diagnosticRecorder: recorder
        )
        let failureProvider = NetworkProvider<SecretDiagnosticTarget>(
            transport: InMemoryNetworkTransport { _ in
                throw SecretNestedError(value: "nested-error-secret")
            },
            diagnosticRecorder: recorder
        )

        _ = try? await successProvider.request(.sentinel("target-secret"))
        _ = try? await statusProvider.request(.sentinel("target-secret"))
        _ = try? await failureProvider.request(.sentinel("target-secret"))

        let events = await recorder.events()
        let rendered = String(reflecting: events)
        for secret in secrets {
            #expect(rendered.contains(secret) == false)
        }
        #expect(rendered.contains("secret-operation"))
        #expect(rendered.contains("/safe/<value>"))
        #expect(rendered.contains("query"))
        #expect(events.map(\.statusClass) == [2, 5, nil])
        #expect(events.map(\.failure) == [
            nil, .statusClass(5), .transport
        ])
        #expect(Set(events.map(\.operationID)).count == 3)
    }

    private func event(id: UUID, operation: String) -> NetworkDiagnosticEvent {
        NetworkDiagnosticEvent(
            operationID: id,
            operation: operation,
            method: .get,
            safePath: "/safe",
            queryKeys: [],
            statusClass: 2,
            elapsed: .milliseconds(1),
            failure: nil,
            summary: nil
        )
    }
}

nonisolated
private enum SecretDiagnosticTarget: NetworkTarget {
    case sentinel(String)

    var baseURL: URL {
        URL(string: "https://dummyjson.com/?existing=url-secret")!
    }

    var path: String { "/unsafe/password-secret/\(targetValue)" }
    var method: HTTPMethod { .post }
    var task: NetworkTask {
        .data(
            Data("body-secret".utf8),
            queryItems: [URLQueryItem(name: "query", value: "url-secret")]
        )
    }
    var headers: HTTPHeaders { ["Authorization": "Bearer header-secret"] }
    var diagnosticDescriptor: NetworkDiagnosticDescriptor? {
        NetworkDiagnosticDescriptor(
            operation: "secret-operation",
            safePath: "/safe/<value>",
            queryKeys: ["query"]
        )
    }

    private var targetValue: String {
        switch self {
        case let .sentinel(value): value
        }
    }
}

nonisolated
private struct SecretNestedError: Error {
    let value: String
}
