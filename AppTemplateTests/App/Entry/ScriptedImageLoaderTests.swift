import Foundation
import Testing
@testable import AppTemplate

struct ScriptedImageLoaderTests {
    private let image = LoadedImage(data: Data([1, 2]), mimeType: "image/png", pixelWidth: 1, pixelHeight: 1)

    @Test
    func consumesOrderedMatchingImage() async throws {
        let url = URL(string: "https://cdn.dummyjson.com/a.png")!
        let loader = ScriptedImageLoader(steps: [.init(url: url, result: .success(image))])
        #expect(try await loader.load(url, policy: .product) == image)
        try await loader.assertExhausted()
    }

    @Test
    func repeatedSuccessfulURLUsesTheConsumedCachedImage() async throws {
        let url = URL(string: "https://cdn.dummyjson.com/a.png")!
        let loader = ScriptedImageLoader(steps: [
            .init(url: url, result: .success(image))
        ])

        #expect(try await loader.load(url, policy: .product) == image)
        #expect(try await loader.load(url, policy: .product) == image)
        try await loader.assertExhausted()
    }

    @Test
    func mismatchDoesNotConsumeAndEmptyScriptFailsClosed() async {
        let expectedURL = URL(string: "https://cdn.dummyjson.com/a.png")!
        let otherURL = URL(string: "https://cdn.dummyjson.com/private.png")!
        let loader = ScriptedImageLoader(steps: [.init(url: expectedURL, result: .success(image))])
        await #expect(throws: ScriptedImageLoaderError.urlMismatch) {
            _ = try await loader.load(otherURL, policy: .product)
        }
        await #expect(throws: ScriptedImageLoaderError.unconsumedSteps(1)) {
            try await loader.assertExhausted()
        }
        let empty = ScriptedImageLoader(steps: [])
        await #expect(throws: ScriptedImageLoaderError.unexpectedURL) {
            _ = try await empty.load(otherURL, policy: .product)
        }
        #expect(!String(describing: ScriptedImageLoaderError.urlMismatch).contains("private"))
    }

    @Test
    func scriptedFailureConsumesTheStep() async throws {
        let url = URL(string: "https://cdn.dummyjson.com/a.png")!
        let loader = ScriptedImageLoader(steps: [.init(url: url, result: .failure)])
        await #expect(throws: ScriptedImageLoaderError.scriptedFailure) {
            _ = try await loader.load(url, policy: .product)
        }
        try await loader.assertExhausted()
    }
}
