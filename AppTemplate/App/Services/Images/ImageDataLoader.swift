import Foundation
import Nuke

nonisolated
struct ImageLoadCancellation: Cancellable {
    private let operation: @Sendable () -> Void

    init(_ operation: @escaping @Sendable () -> Void = {}) {
        self.operation = operation
    }

    func cancel() {
        operation()
    }
}

nonisolated
struct ImageDataLoader: DataLoading {
    private let session: URLSession
    private let policy: ImagePolicy
    private let clock: AppClock

    init(
        policy: ImagePolicy = .product,
        clock: AppClock = .live,
        protocolClasses: [AnyClass]? = nil
    ) {
        self.policy = policy
        self.clock = clock
        let configuration = EphemeralURLSessionConfiguration.make(
            timeout: policy.timeoutInterval,
            protocolClasses: protocolClasses
        )
        configuration.httpShouldSetCookies = false
        session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable ((any Error)?) -> Void
    ) -> any Cancellable {
        guard let url = request.url, policy.permits(url) else {
            completion(ImageServiceError.disallowedOrigin)
            return ImageLoadCancellation()
        }
        let load = ImageDataLoad(
            policy: policy,
            didReceiveData: didReceiveData,
            completion: completion
        )
        load.start(request: request, session: session, clock: clock)
        return load
    }
}

nonisolated
private final class ImageDataLoad: NSObject,
    URLSessionDataDelegate,
    Cancellable,
    @unchecked Sendable
{
    private struct State {
        var task: URLSessionDataTask?
        var response: HTTPURLResponse?
        var body = Data()
        var deadline: Task<Void, Never>?
        var isFinished = false
        var cancellationRequested = false
    }

    // NSLock rather than an actor: URLSession delivers its delegate callbacks on
    // its own queue while Nuke cancels from @ImagePipelineActor, and the
    // DataLoading contract requires `completion` to run exactly once.
    private let lock = NSLock()
    private var state = State()
    private let policy: ImagePolicy
    private let didReceiveData: @Sendable (Data, URLResponse) -> Void
    private let completion: @Sendable ((any Error)?) -> Void

    init(
        policy: ImagePolicy,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable ((any Error)?) -> Void
    ) {
        self.policy = policy
        self.didReceiveData = didReceiveData
        self.completion = completion
    }

    func start(request: URLRequest, session: URLSession, clock: AppClock) {
        var request = request
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = policy.timeoutInterval
        let timeout = policy.timeout

        let shouldAbort = lock.withLock {
            guard !state.cancellationRequested else {
                state.isFinished = true
                return true
            }
            let task = session.dataTask(with: request)
            task.delegate = self
            state.task = task
            // The deadline is the injected clock, not the session timeout, so a
            // test can drive it without waiting in real time.
            state.deadline = Task { [weak self] in
                do {
                    try await clock.sleep(timeout)
                } catch {
                    return
                }
                guard let self else { return }
                self.finish(.failure(.timedOut))
            }
            task.resume()
            return false
        }
        if shouldAbort {
            completion(ImageServiceError.cancelled)
        }
    }

    func cancel() {
        let resources = lock.withLock { () -> (URLSessionDataTask?, Task<Void, Never>?, Bool) in
            state.cancellationRequested = true
            guard !state.isFinished else { return (nil, nil, false) }
            state.isFinished = true
            let resources = (state.task, state.deadline, true)
            state.task = nil
            state.deadline = nil
            return resources
        }
        resources.0?.cancel()
        resources.1?.cancel()
        guard resources.2 else { return }
        completion(ImageServiceError.cancelled)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, policy.permits(url) else {
            completionHandler(nil)
            finish(.failure(.disallowedOrigin))
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
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(.transport))
            return
        }
        guard let finalURL = response.url, policy.permits(finalURL) else {
            completionHandler(.cancel)
            finish(.failure(.disallowedOrigin))
            return
        }
        guard (200...299).contains(response.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(.invalidStatus))
            return
        }
        // Not the response's own mimeType: URLSession sniffs the body and
        // rewrites that property to match the bytes, so comparing it against
        // the bytes would compare the content with itself and always agree.
        guard ImageByteFormat(
            contentType: response.value(forHTTPHeaderField: "Content-Type")
        ) != nil else {
            completionHandler(.cancel)
            finish(.failure(.invalidMIMEType))
            return
        }
        guard response.expectedContentLength < 0
            || response.expectedContentLength <= Int64(policy.maximumEncodedBytes)
        else {
            completionHandler(.cancel)
            finish(.failure(.responseTooLarge))
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
        let exceeded = lock.withLock {
            guard !state.isFinished else { return false }
            guard data.count <= policy.maximumEncodedBytes - state.body.count else {
                return true
            }
            state.body.append(data)
            return false
        }
        if exceeded {
            finish(.failure(.responseTooLarge))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            let wasCancelled = lock.withLock { state.cancellationRequested }
            if wasCancelled || (error as? URLError)?.code == .cancelled {
                finish(.failure(.cancelled))
            } else if (error as? URLError)?.code == .timedOut {
                finish(.failure(.timedOut))
            } else {
                finish(.failure(.transport))
            }
            return
        }

        let pending = lock.withLock { () -> (Data, ImageHTTPResponse)? in
            guard !state.isFinished,
                  let response = state.response,
                  let finalURL = response.url
            else {
                return nil
            }
            return (state.body, ImageHTTPResponse(
                finalURL: finalURL,
                statusCode: response.statusCode,
                contentType: response.value(forHTTPHeaderField: "Content-Type")
            ))
        }
        guard let pending else {
            finish(.failure(.transport))
            return
        }
        do {
            let bytes = try ImageBytes.validated(
                pending.0,
                from: pending.1,
                policy: policy
            )
            finish(.success(bytes))
        } catch {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<ImageBytes, ImageServiceError>) {
        let resources = lock.withLock { () -> (URLSessionDataTask?, HTTPURLResponse?, Task<Void, Never>?)? in
            guard !state.isFinished else { return nil }
            state.isFinished = true
            let resources = (state.task, state.response, state.deadline)
            state.task = nil
            state.deadline = nil
            state.body = Data()
            return resources
        }
        guard let resources else { return }
        resources.2?.cancel()
        switch result {
        case let .success(bytes):
            guard let response = resources.1 else {
                completion(ImageServiceError.transport)
                return
            }
            // Nuke sees the body only once, and only after the validator has
            // accepted every byte of it.
            didReceiveData(bytes.data, response)
            completion(nil)
        case let .failure(error):
            resources.0?.cancel()
            completion(error)
        }
    }
}
