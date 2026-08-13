nonisolated
enum ImageLoaderError: Error, Equatable, Sendable {
    case invalidURL
    case disallowedOrigin
    case invalidStatus
    case invalidMIMEType
    case invalidSignature
    case responseTooLarge
    case dimensionsTooLarge
    case timedOut
    case cancelled
    case transport
}
