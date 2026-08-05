import Foundation

nonisolated
struct NetworkProvider<Target: NetworkTarget>: Sendable {
    private let transport: any NetworkTransport
    private let adapters: [any RequestAdapter]
    private let monitors: [any NetworkEventMonitor]
    private let requestBuilder: NetworkRequestBuilder
    private let stubBehavior: @Sendable (Target) -> StubBehavior
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        transport: any NetworkTransport = URLSessionTransport(),
        adapters: [any RequestAdapter] = [],
        monitors: [any NetworkEventMonitor] = [],
        jsonEncoderFactory: @escaping @Sendable () -> JSONEncoder = {
            JSONEncoder()
        },
        stubBehavior: @escaping @Sendable (Target) -> StubBehavior = { _ in
            .never
        },
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.transport = transport
        self.adapters = adapters
        self.monitors = monitors
        requestBuilder = NetworkRequestBuilder(
            jsonEncoderFactory: jsonEncoderFactory
        )
        self.stubBehavior = stubBehavior
        self.sleep = sleep
    }

    func request(_ target: Target) async throws -> NetworkResponse {
        var request = try requestBuilder.build(target)

        do {
            for adapter in adapters {
                request = try await adapter.adapt(request, target: target)
            }
        } catch {
            throw normalize(
                error,
                fallback: { .requestAdaptation(underlying: $0) }
            )
        }

        for monitor in monitors {
            await monitor.willSend(request, target: target)
        }

        let result = await result(for: request, target: target)

        for monitor in monitors {
            await monitor.didComplete(result, target: target)
        }

        return try result.get()
    }

    private func result(
        for request: URLRequest,
        target: Target
    ) async -> Result<NetworkResponse, NetworkError> {
        do {
            let response: NetworkResponse
            switch stubBehavior(target) {
            case .never:
                response = try await liveResponse(for: request)
            case .immediate:
                response = stubResponse(for: request, target: target)
            case let .delayed(duration):
                try await sleep(duration)
                response = stubResponse(for: request, target: target)
            }

            guard target.validation.accepts(response.statusCode) else {
                throw NetworkError.unacceptableStatus(response)
            }

            return .success(response)
        } catch {
            return .failure(
                normalize(
                    error,
                    fallback: { .transport(underlying: $0) }
                )
            )
        }
    }

    private func liveResponse(
        for request: URLRequest
    ) async throws -> NetworkResponse {
        let (data, urlResponse) = try await transport.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.nonHTTPResponse
        }

        return NetworkResponse(
            request: request,
            url: httpResponse.url,
            statusCode: httpResponse.statusCode,
            headers: stringHeaders(from: httpResponse),
            data: data
        )
    }

    private func stubResponse(
        for request: URLRequest,
        target: Target
    ) -> NetworkResponse {
        NetworkResponse(
            request: request,
            url: request.url,
            statusCode: target.sampleResponse.statusCode,
            headers: target.sampleResponse.headers,
            data: target.sampleResponse.data
        )
    }

    private func normalize(
        _ error: any Error,
        fallback: (any Error) -> NetworkError
    ) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .cancelled
        }
        return fallback(error)
    }

    private func stringHeaders(
        from response: HTTPURLResponse
    ) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, field in
            guard let name = field.key as? String else { return }
            headers[name] = String(describing: field.value)
        }
    }
}
