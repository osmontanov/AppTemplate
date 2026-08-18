import Foundation
import Nuke

nonisolated
enum ImageServiceError: Error, Equatable, Sendable {
    case disallowedOrigin
    case invalidStatus
    case invalidMIMEType
    case invalidSignature
    case responseTooLarge
    case dimensionsTooLarge
    case timedOut
    case cancelled
    case decodeFailed
    case transport
}

nonisolated
extension ImageServiceError {
    // Our own errors travel through Nuke wrapped twice over: the loader's reach
    // the pipeline as `dataLoadingFailed`, the decoder's as `decodingFailed`.
    // Unwrapping here is what keeps the reason a caller sees the same one the
    // validator produced.
    init(_ error: ImagePipeline.Error) {
        switch error {
        case let .dataLoadingFailed(underlying):
            self = ImageServiceError(underlying: underlying)
        case let .decodingFailed(_, _, underlying):
            self = ImageServiceError(underlying: underlying)
        case let .processingFailed(_, _, underlying):
            self = ImageServiceError(underlying: underlying)
        case .dataDownloadExceededMaximumSize:
            self = .responseTooLarge
        case .dataIsEmpty, .decoderNotRegistered, .dataMissingInCache:
            self = .invalidSignature
        case .imageRequestMissing, .pipelineInvalidated:
            self = .transport
        case .cancelled:
            self = .cancelled
        }
    }

    private init(underlying: any Error) {
        if let mapped = underlying as? ImageServiceError {
            self = mapped
        } else if underlying is CancellationError {
            self = .cancelled
        } else if let urlError = underlying as? URLError {
            switch urlError.code {
            case .cancelled: self = .cancelled
            case .timedOut: self = .timedOut
            default: self = .transport
            }
        } else {
            self = .transport
        }
    }
}
