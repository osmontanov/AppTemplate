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
            throw adaptationError(from: error)
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
        let response: NetworkResponse
        switch stubBehavior(target) {
        case .never:
            switch await liveResult(for: request) {
            case let .success(liveResponse):
                response = liveResponse
            case let .failure(error):
                return .failure(error)
            }
        case .immediate:
            response = stubResponse(for: request, target: target)
        case let .delayed(duration):
            do {
                try await sleep(duration)
            } catch {
                return .failure(executionError(from: error))
            }
            response = stubResponse(for: request, target: target)
        }

        guard target.validation.accepts(response.statusCode) else {
            return .failure(.unacceptableStatus(response))
        }

        return .success(response)
    }

    private func liveResult(
        for request: URLRequest
    ) async -> Result<NetworkResponse, NetworkError> {
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await transport.data(for: request)
        } catch {
            return .failure(executionError(from: error))
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            return .failure(.nonHTTPResponse)
        }

        return .success(
            NetworkResponse(
                request: request,
                url: httpResponse.url,
                statusCode: httpResponse.statusCode,
                headers: stringHeaders(from: httpResponse),
                data: data
            )
        )
    }

    private func stubResponse(
        for request: URLRequest,
        target: Target
    ) -> NetworkResponse {
        let sample = target.sampleResponse
        return NetworkResponse(
            request: request,
            url: request.url,
            statusCode: sample.statusCode,
            headers: sample.headers,
            data: sample.data
        )
    }

    private func adaptationError(from error: any Error) -> NetworkError {
        if let cancellation = cancellationError(from: error) {
            return cancellation
        }
        if
            let networkError = error as? NetworkError,
            case .requestAdaptation = networkError
        {
            return networkError
        }
        return .requestAdaptation(underlying: error)
    }

    private func executionError(from error: any Error) -> NetworkError {
        if let cancellation = cancellationError(from: error) {
            return cancellation
        }
        if
            let networkError = error as? NetworkError,
            case .transport = networkError
        {
            return networkError
        }
        return .transport(underlying: error)
    }

    private func cancellationError(
        from error: any Error
    ) -> NetworkError? {
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return .cancelled
        }
        if
            let networkError = error as? NetworkError,
            case .cancelled = networkError
        {
            return .cancelled
        }
        return nil
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
