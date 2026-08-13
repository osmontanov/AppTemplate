import Foundation

nonisolated
struct URLSessionImageHTTPTransport: IImageHTTPTransport {
    private let protocolClasses: [AnyClass]?

    init(protocolClasses: [AnyClass]? = nil) {
        self.protocolClasses = protocolClasses
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

        let configuration = EphemeralURLSessionConfiguration.make(
            timeout: policy.timeoutInterval,
            protocolClasses: protocolClasses
        )
        configuration.httpShouldSetCookies = false
        let operation = ImageHTTPTransportOperation(policy: policy)
        return try await operation.run(url: url, configuration: configuration)
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
        var session: URLSession?
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
        configuration: URLSessionConfiguration
    ) async throws -> ImageHTTPResponse {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                begin(url: url, configuration: configuration, continuation: continuation)
            }
        } onCancel: {
            cancel()
        }
    }

    private func begin(
        url: URL,
        configuration: URLSessionConfiguration,
        continuation: CheckedContinuation<ImageHTTPResponse, Error>
    ) {
        let shouldCancel = lock.withLock {
            if state.cancellationRequested {
                state.isFinished = true
                return true
            }
            let session = URLSession(
                configuration: configuration,
                delegate: self,
                delegateQueue: nil
            )
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = policy.timeoutInterval
            let task = session.dataTask(with: request)
            state.continuation = continuation
            state.session = session
            state.task = task
            task.resume()
            return false
        }
        if shouldCancel {
            continuation.resume(throwing: ImageLoaderError.cancelled)
        }
    }

    private func cancel() {
        let resources = lock.withLock { () -> (URLSession?, URLSessionDataTask?, CheckedContinuation<ImageHTTPResponse, Error>?) in
            state.cancellationRequested = true
            guard !state.isFinished else { return (nil, nil, nil) }
            state.isFinished = true
            let resources = (state.session, state.task, state.continuation)
            state.session = nil
            state.task = nil
            state.continuation = nil
            return resources
        }
        resources.1?.cancel()
        resources.0?.invalidateAndCancel()
        resources.2?.resume(throwing: ImageLoaderError.cancelled)
    }

    private func finish(_ result: Result<ImageHTTPResponse, Error>) {
        let resources = lock.withLock { () -> (URLSession?, URLSessionDataTask?, CheckedContinuation<ImageHTTPResponse, Error>?) in
            guard !state.isFinished else { return (nil, nil, nil) }
            state.isFinished = true
            let resources = (state.session, state.task, state.continuation)
            state.session = nil
            state.task = nil
            state.continuation = nil
            state.response = nil
            state.data = Data()
            return resources
        }
        guard let continuation = resources.2 else { return }
        switch result {
        case let .success(response):
            resources.0?.finishTasksAndInvalidate()
            continuation.resume(returning: response)
        case let .failure(error):
            resources.1?.cancel()
            resources.0?.invalidateAndCancel()
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
