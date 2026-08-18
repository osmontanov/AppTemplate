import Foundation

nonisolated
struct URLSessionImageHTTPTransport: ImageHTTPTransport {
    // One session per transport so connections are reused across image loads;
    // per-request deadlines still come from the policy via the URLRequest.
    private let session: URLSession

    init(
        protocolClasses: [AnyClass]? = nil,
        configurationTimeout: TimeInterval = ImageLoadPolicy.product.timeoutInterval
    ) {
        let configuration = EphemeralURLSessionConfiguration.make(
            timeout: configurationTimeout,
            protocolClasses: protocolClasses
        )
        configuration.httpShouldSetCookies = false
        session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )
    }

    func fetch(_ url: URL, policy: ImageLoadPolicy) async throws -> ImageHTTPResponse {
        guard url.scheme != nil, url.host != nil else {
            throw ImageLoaderError.invalidURL
        }
        guard policy.permits(url) else {
            throw ImageLoaderError.disallowedOrigin
        }
        guard policy.maximumEncodedBytes >= 0 else {
            throw ImageLoaderError.responseTooLarge
        }

        let operation = ImageHTTPTransportOperation(policy: policy)
        return try await operation.run(url: url, session: session)
    }
}

nonisolated
private final class ImageHTTPTransportOperation: NSObject,
    URLSessionDataDelegate,
    URLSessionTaskDelegate,
    @unchecked Sendable
{
    private struct State {
        var continuation: CheckedContinuation<ImageHTTPResponse, Error>?
        var task: URLSessionDataTask?
        var response: HTTPURLResponse?
        var data = Data()
        var isFinished = false
        var cancellationRequested = false
    }

    private let policy: ImageLoadPolicy
    private let lock = NSLock()
    private var state = State()

    init(policy: ImageLoadPolicy) {
        self.policy = policy
    }

    func run(
        url: URL,
        session: URLSession
    ) async throws -> ImageHTTPResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                begin(url: url, session: session, continuation: continuation)
            }
        } onCancel: {
            cancel()
        }
    }

    private func begin(
        url: URL,
        session: URLSession,
        continuation: CheckedContinuation<ImageHTTPResponse, Error>
    ) {
        let shouldCancel = lock.withLock {
            if state.cancellationRequested {
                state.isFinished = true
                return true
            }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = policy.timeoutInterval
            let task = session.dataTask(with: request)
            task.delegate = self
            state.continuation = continuation
            state.task = task
            task.resume()
            return false
        }
        if shouldCancel {
            continuation.resume(throwing: ImageLoaderError.cancelled)
        }
    }

    private func cancel() {
        let resources = lock.withLock { () -> (URLSessionDataTask?, CheckedContinuation<ImageHTTPResponse, Error>?) in
            state.cancellationRequested = true
            guard !state.isFinished else { return (nil, nil) }
            state.isFinished = true
            let resources = (state.task, state.continuation)
            state.task = nil
            state.continuation = nil
            return resources
        }
        resources.0?.cancel()
        resources.1?.resume(throwing: ImageLoaderError.cancelled)
    }

    private func finish(_ result: Result<ImageHTTPResponse, Error>) {
        let resources = lock.withLock { () -> (URLSessionDataTask?, CheckedContinuation<ImageHTTPResponse, Error>?) in
            guard !state.isFinished else { return (nil, nil) }
            state.isFinished = true
            let resources = (state.task, state.continuation)
            state.task = nil
            state.continuation = nil
            state.response = nil
            state.data = Data()
            return resources
        }
        guard let continuation = resources.1 else { return }
        switch result {
        case let .success(response):
            continuation.resume(returning: response)
        case let .failure(error):
            resources.0?.cancel()
            continuation.resume(throwing: error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        _ = session
        _ = task
        _ = response
        guard let url = request.url, policy.permits(url) else {
            completionHandler(nil)
            finish(.failure(ImageLoaderError.disallowedOrigin))
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        _ = session
        _ = dataTask
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(ImageLoaderError.transport))
            return
        }
        guard let finalURL = response.url, policy.permits(finalURL) else {
            completionHandler(.cancel)
            finish(.failure(ImageLoaderError.disallowedOrigin))
            return
        }
        guard (200...299).contains(response.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(ImageLoaderError.invalidStatus))
            return
        }
        guard response.expectedContentLength < 0 ||
                response.expectedContentLength <= Int64(policy.maximumEncodedBytes)
        else {
            completionHandler(.cancel)
            finish(.failure(ImageLoaderError.responseTooLarge))
            return
        }
        lock.withLock { state.response = response }
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        _ = session
        _ = dataTask
        let exceeded = lock.withLock {
            guard !state.isFinished else { return false }
            guard data.count <= policy.maximumEncodedBytes - state.data.count else {
                return true
            }
            state.data.append(data)
            return false
        }
        if exceeded {
            finish(.failure(ImageLoaderError.responseTooLarge))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        _ = session
        _ = task
        if let error {
            let wasCancelled = lock.withLock { state.cancellationRequested }
            if wasCancelled || (error as? URLError)?.code == .cancelled {
                finish(.failure(ImageLoaderError.cancelled))
            } else {
                finish(.failure(ImageLoaderError.transport))
            }
            return
        }

        let response = lock.withLock { () -> ImageHTTPResponse? in
            guard let httpResponse = state.response,
                  let finalURL = httpResponse.url
            else {
                return nil
            }
            return ImageHTTPResponse(
                finalURL: finalURL,
                statusCode: httpResponse.statusCode,
                mimeType: httpResponse.mimeType,
                data: state.data
            )
        }
        guard let response else {
            finish(.failure(ImageLoaderError.transport))
            return
        }
        finish(.success(response))
    }
}
