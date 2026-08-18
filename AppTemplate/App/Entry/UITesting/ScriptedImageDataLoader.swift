import Foundation
import Nuke

nonisolated enum ScriptedImageOutcome: Equatable, Sendable {
    case response(statusCode: Int, contentType: String, body: Data)
    case failure(ImageServiceError)
}

nonisolated struct ScriptedImageStep: Equatable, Sendable {
    let url: URL
    let outcome: ScriptedImageOutcome

    static func png(_ url: URL, body: Data) -> ScriptedImageStep {
        ScriptedImageStep(
            url: url,
            outcome: .response(statusCode: 200, contentType: "image/png", body: body)
        )
    }
}

nonisolated enum ScriptedImageDataLoaderError: Error, Equatable, Sendable {
    case unexpectedURL
    case unconsumedSteps(Int)
}

nonisolated final class ScriptedImageDataLoader: DataLoading, @unchecked Sendable {
    private struct State {
        var stepsByURL: [URL: ScriptedImageStep]
        var servedURLs: Set<URL> = []
        var requestedURLs: [URL] = []
        var notifications: [Task<Void, Never>] = []
    }

    // NSLock rather than an actor: DataLoading is a synchronous Sendable seam,
    // written from Nuke's pipeline actor and read by the exhaustion assertion.
    private let lock = NSLock()
    private var state: State
    private let policy: ImagePolicy
    private let tracker: UITestScriptConsumptionTracker?

    init(
        steps: [ScriptedImageStep],
        policy: ImagePolicy = .product,
        tracker: UITestScriptConsumptionTracker? = nil
    ) {
        // The tracker is seeded from steps.count, so a duplicate URL would make
        // .exhausted unreachable.
        precondition(
            Set(steps.map(\.url)).count == steps.count,
            "Scripted image steps must have unique URLs"
        )
        state = State(stepsByURL: Dictionary(
            uniqueKeysWithValues: steps.map { ($0.url, $0) }
        ))
        self.policy = policy
        self.tracker = tracker
    }

    var requestedURLs: [URL] {
        lock.withLock { state.requestedURLs }
    }

    // DataLoading is synchronous, so tracker updates leave through an unstructured
    // Task. A test that asserts on the tracker has to be able to await that hop
    // rather than sleep and hope.
    func drainNotifications() async {
        let pending = lock.withLock {
            let pending = state.notifications
            state.notifications.removeAll()
            return pending
        }
        for task in pending { await task.value }
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable ((any Error)?) -> Void
    ) -> any Cancellable {
        guard let url = request.url else {
            fail(completion, ImageServiceError.disallowedOrigin)
            return ImageLoadCancellation()
        }
        lock.withLock { state.requestedURLs.append(url) }
        guard policy.permits(url) else {
            fail(completion, ImageServiceError.disallowedOrigin)
            return ImageLoadCancellation()
        }

        let resolved = lock.withLock { () -> (ScriptedImageStep, Bool)? in
            guard let step = state.stepsByURL[url] else { return nil }
            let isFirstServe = state.servedURLs.insert(url).inserted
            return (step, isFirstServe)
        }
        guard let (step, isFirstServe) = resolved else {
            fail(completion, ScriptedImageDataLoaderError.unexpectedURL)
            return ImageLoadCancellation()
        }
        // A replay must not consume a second step: the reminder path re-requests
        // the URL the detail view already showed, and pipeline.data(for:) does
        // not consult the decoded-image cache.
        if isFirstServe {
            let tracker = tracker
            let notification = Task { _ = await tracker?.didConsume(.image) }
            lock.withLock { state.notifications.append(notification) }
        }

        switch step.outcome {
        case let .response(statusCode, contentType, body):
            do {
                let bytes = try ImageBytes.validated(
                    body,
                    from: ImageHTTPResponse(
                        finalURL: url,
                        statusCode: statusCode,
                        contentType: contentType
                    ),
                    policy: policy
                )
                guard let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": contentType]
                ) else {
                    completion(ImageServiceError.transport)
                    return ImageLoadCancellation()
                }
                didReceiveData(bytes.data, response)
                completion(nil)
            } catch {
                completion(error)
            }
        case let .failure(error):
            completion(error)
        }
        return ImageLoadCancellation()
    }

    func assertExhausted() throws {
        let remaining = lock.withLock {
            state.stepsByURL.count - state.servedURLs.count
        }
        guard remaining == 0 else {
            throw ScriptedImageDataLoaderError.unconsumedSteps(remaining)
        }
    }

    private func fail(
        _ completion: @escaping @Sendable ((any Error)?) -> Void,
        _ error: any Error
    ) {
        let tracker = tracker
        let notification = Task { _ = await tracker?.didFail(.image) }
        lock.withLock { state.notifications.append(notification) }
        completion(error)
    }
}

nonisolated
extension ImageService {
    // diskCache stays nil: a disk hit would serve bytes without reaching the
    // scripted loader and desynchronise the tracker. The rate limiter is off
    // because it introduces delays a journey cannot predict.
    static func scripted(
        steps: [ScriptedImageStep],
        tracker: UITestScriptConsumptionTracker?,
        policy: ImagePolicy = .product
    ) -> ImageService {
        ImageService(
            pipeline: ImagePipeline(configuration: configuration(
                loader: ScriptedImageDataLoader(
                    steps: steps,
                    policy: policy,
                    tracker: tracker
                ),
                policy: policy,
                diskCache: nil,
                isRateLimiterEnabled: false
            )),
            policy: policy,
            kind: .scripted
        )
    }
}
