import Foundation

nonisolated enum ScriptedImageLoaderError: Error, Equatable, Sendable {
    case unexpectedURL
    case urlMismatch
    case scriptedFailure
    case unconsumedSteps(Int)
}

nonisolated enum ScriptedImageResult: Equatable, Sendable {
    case success(LoadedImage)
    case failure
}

nonisolated struct ScriptedImageStep: Equatable, Sendable {
    let url: URL
    let result: ScriptedImageResult
}

actor ScriptedImageLoader: IImageLoader {
    private var remaining: [ScriptedImageStep]
    private var successfulImagesByURL: [URL: LoadedImage] = [:]
    private let tracker: UITestScriptConsumptionTracker?

    init(steps: [ScriptedImageStep], tracker: UITestScriptConsumptionTracker? = nil) {
        remaining = steps
        self.tracker = tracker
    }

    func load(_ url: URL, policy: ImageLoadPolicy) async throws -> LoadedImage {
        _ = policy
        try Task.checkCancellation()
        if let cached = successfulImagesByURL[url] { return cached }
        guard let step = remaining.first else {
            await tracker?.didFail(.image)
            throw ScriptedImageLoaderError.unexpectedURL
        }
        guard step.url == url else {
            await tracker?.didFail(.image)
            throw ScriptedImageLoaderError.urlMismatch
        }
        try Task.checkCancellation()
        let matched = remaining.removeFirst()
        await tracker?.didConsume(.image)
        switch matched.result {
        case let .success(image):
            successfulImagesByURL[url] = image
            return image
        case .failure: throw ScriptedImageLoaderError.scriptedFailure
        }
    }

    func assertExhausted() throws {
        guard remaining.isEmpty else {
            throw ScriptedImageLoaderError.unconsumedSteps(remaining.count)
        }
    }
}
