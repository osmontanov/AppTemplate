import Foundation
import Nuke

nonisolated
struct FailClosedImageDataLoader: DataLoading {
    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable ((any Error)?) -> Void
    ) -> any Cancellable {
        completion(ImageServiceError.transport)
        return ImageLoadCancellation()
    }
}
