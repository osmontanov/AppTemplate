nonisolated enum UserDefaultsServiceError: Error, Equatable, Sendable {
    case invalidStoredValue
    case encodingFailed
    case decodingFailed
}
