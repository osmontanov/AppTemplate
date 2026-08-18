import Foundation
import Nuke
@testable import AppTemplate

// An ImageService that reaches a scripted loader holding no steps: every request
// fails, and the loader records what was asked for, so a test can prove a graph
// kept the exact instance it was handed and never touched it.
nonisolated
struct ImageServiceProbe: Sendable {
    let loader: ScriptedImageDataLoader
    let service: ImageService

    init(steps: [ScriptedImageStep] = [], policy: ImagePolicy = .product) {
        let loader = ScriptedImageDataLoader(steps: steps, policy: policy)
        self.loader = loader
        service = ImageService(
            pipeline: ImagePipeline(configuration: ImageService.configuration(
                loader: loader,
                policy: policy,
                diskCache: nil,
                isRateLimiterEnabled: false
            )),
            policy: policy,
            kind: .failClosed
        )
    }

    var requestedURLs: [URL] { loader.requestedURLs }
}
