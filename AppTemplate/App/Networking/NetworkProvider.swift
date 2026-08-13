import Foundation

nonisolated
struct NetworkProvider<Target: NetworkTarget>: Sendable {
    private let transport: any NetworkTransport
    private let adapters: [any RequestAdapter]
    private let monitors: [any NetworkEventMonitor]
    private let requestBuilder: NetworkRequestBuilder
    private let stubBehavior: @Sendable (Target) -> StubBehavior
    private let clock: AppClock
    private let diagnosticRecorder: NetworkDiagnosticRecorder?

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
        clock: AppClock = .live,
        diagnosticRecorder: NetworkDiagnosticRecorder? = nil
    ) {
        self.transport = transport
        self.adapters = adapters
        self.monitors = monitors
        requestBuilder = NetworkRequestBuilder(
            jsonEncoderFactory: jsonEncoderFactory
        )
        self.stubBehavior = stubBehavior
        self.clock = clock
        self.diagnosticRecorder = diagnosticRecorder
    }

    @concurrent
    func request(_ target: Target) async throws -> NetworkResponse {
        let operationID = UUID()
        let started = clock.monotonicNow()
        let descriptor = target.diagnosticDescriptor
        let method = target.method
        var request: URLRequest

        do {
            request = try requestBuilder.build(target)
        } catch {
            let networkError = (error as? NetworkError)
                ?? NetworkError.requestConstruction
            await recordDiagnostic(
                descriptor: descriptor,
                operationID: operationID,
                method: method,
                started: started,
                response: nil,
                error: networkError
            )
            throw networkError
        }

        do {
            for adapter in adapters {
                request = try await adapter.adapt(
                    request,
                    target: target
                )
            }
        } catch {
            let networkError = adaptationError(from: error)
            await recordDiagnostic(
                descriptor: descriptor,
                operationID: operationID,
                method: method,
                started: started,
                response: nil,
                error: networkError
            )
            throw networkError
        }

        var preparedRequest = request
        if !target.shouldHandleCookies {
            preparedRequest = CredentialRedirectPolicy().prepare(request)
        }

        let context = NetworkRequestContext(
            id: operationID,
            request: preparedRequest
        )

        for monitor in monitors {
            await monitor.willSend(context: context, target: target)
        }

        let result = await result(
            for: preparedRequest,
            target: target,
            operationID: operationID
        )

        for monitor in monitors {
            await monitor.didComplete(
                context: context,
                result: result,
                target: target
            )
        }

        switch result {
        case let .success(response):
            await recordDiagnostic(
                descriptor: descriptor,
                operationID: operationID,
                method: method,
                started: started,
                response: response,
                error: nil
            )
        case let .failure(error):
            await recordDiagnostic(
                descriptor: descriptor,
                operationID: operationID,
                method: method,
                started: started,
                response: response(from: error),
                error: error
            )
        }

        return try result.get()
    }

    private func result(
        for request: URLRequest,
        target: Target,
        operationID: UUID
    ) async -> Result<NetworkResponse, NetworkError> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        let response: NetworkResponse
        switch stubBehavior(target) {
        case .never:
            switch await liveResult(
                for: request,
                operationID: operationID
            ) {
            case let .success(liveResponse):
                response = liveResponse
            case let .failure(error):
                return .failure(error)
            }
        case .immediate:
            response = stubResponse(
                for: request,
                target: target,
                operationID: operationID
            )
        case let .delayed(duration):
            do {
                try await clock.sleep(duration)
            } catch {
                return .failure(executionError(from: error))
            }
            guard !Task.isCancelled else {
                return .failure(.cancelled)
            }
            response = stubResponse(
                for: request,
                target: target,
                operationID: operationID
            )
        }

        guard target.validation.accepts(response.statusCode) else {
            return .failure(.unacceptableStatus(response))
        }

        return .success(response)
    }

    private func liveResult(
        for request: URLRequest,
        operationID: UUID
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
                operationID: operationID,
                request: request,
                url: httpResponse.url,
                statusCode: httpResponse.statusCode,
                headers: httpHeaders(from: httpResponse),
                data: data
            )
        )
    }

    private func stubResponse(
        for request: URLRequest,
        target: Target,
        operationID: UUID
    ) -> NetworkResponse {
        let sample = target.sampleResponse
        return NetworkResponse(
            operationID: operationID,
            request: request,
            url: request.url,
            statusCode: sample.statusCode,
            headers: sample.headers,
            data: sample.data
        )
    }

    private func adaptationError(from error: any Error) -> NetworkError {
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

    private func recordDiagnostic(
        descriptor: NetworkDiagnosticDescriptor?,
        operationID: UUID,
        method: HTTPMethod,
        started: ContinuousClock.Instant,
        response: NetworkResponse?,
        error: NetworkError?
    ) async {
        guard let descriptor, let diagnosticRecorder else { return }
        let event = NetworkDiagnosticEvent(
            operationID: operationID,
            operation: descriptor.operation,
            method: method,
            safePath: descriptor.safePath,
            queryKeys: descriptor.queryKeys,
            statusClass: response.map { $0.statusCode / 100 },
            elapsed: started.duration(to: clock.monotonicNow()),
            failure: error.map(diagnosticFailure),
            summary: nil
        )
        await diagnosticRecorder.record(event)
    }

    private func diagnosticFailure(
        _ error: NetworkError
    ) -> NetworkDiagnosticFailure {
        switch error {
        case .cancelled:
            .cancelled
        case .transport:
            .transport
        case let .unacceptableStatus(response):
            .statusClass(response.statusCode / 100)
        case .requestConstruction,
             .requestEncoding,
             .requestAdaptation,
             .nonHTTPResponse,
             .decoding:
            .invalidResponse
        }
    }

    private func response(from error: NetworkError) -> NetworkResponse? {
        switch error {
        case let .unacceptableStatus(response),
             let .decoding(_, response):
            response
        default:
            nil
        }
    }

    private func httpHeaders(
        from response: HTTPURLResponse
    ) -> HTTPHeaders {
        let entries = response.allHeaderFields.compactMap {
            key, value -> (String, String)? in
            guard
                let name = key as? String,
                HTTPHeaders.isValidFieldName(name)
            else {
                return nil
            }
            return (name, String(describing: value))
        }.sorted {
            let leftCanonical = HTTPHeaders.canonicalName($0.0)
            let rightCanonical = HTTPHeaders.canonicalName($1.0)
            if leftCanonical != rightCanonical {
                return leftCanonical < rightCanonical
            }
            if $0.0 != $1.0 {
                return $0.0.utf8.lexicographicallyPrecedes($1.0.utf8)
            }
            return $0.1 < $1.1
        }

        return entries.reduce(into: HTTPHeaders()) { headers, entry in
            headers.set(entry.1, for: entry.0)
        }
    }
}
