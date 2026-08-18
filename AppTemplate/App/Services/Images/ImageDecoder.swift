import Foundation
import Nuke

nonisolated
struct ImageDecoder: ImageDecoding {
    private let policy: ImagePolicy
    private let base = ImageDecoders.Default()

    init(policy: ImagePolicy) {
        self.policy = policy
    }

    var isAsynchronous: Bool { true }

    // The second byte boundary: a disk-cache hit reaches the decoder without
    // ever passing through DataLoading, so cached bytes are re-proven here.
    func decode(_ data: Data) throws -> ImageContainer {
        _ = try ImageBytes.validated(data, from: nil, policy: policy)
        return try base.decode(data)
    }

    func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? { nil }
}
