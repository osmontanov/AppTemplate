import Security

nonisolated enum KeychainServiceError: Error, Equatable, Sendable {
    case invalidStoredData
    case invalidUTF8
    case encodingFailed
    case decodingFailed
    case unavailable
    case interactionNotAllowed
    case authenticationFailed
    case interactionCancelled
    case permissionDenied
    case missingEntitlement
    case dataTooLarge
    case invalidRequest
    case concurrentMutation
    case internalFailure
    case unexpectedStatus(OSStatus)
}
