import Foundation
import Security

actor KeychainService: IKeychainService {
    private let service: String
    private let executor: any KeychainSecItemExecuting

    init(service: String) {
        KeychainComponent.validateService(service)
        self.service = service
        executor = SecurityKeychainSecItemExecutor()
    }

    init(service: String, executor: any KeychainSecItemExecuting) {
        KeychainComponent.validateService(service)
        self.service = service
        self.executor = executor
    }

    func data(for key: KeychainKey) async throws -> Data? {
        let result: KeychainSecItemCopyResult
        do {
            try Task.checkCancellation()
            result = try await executor.copy(service: service, account: key.account)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.internalFailure
        }
        switch result {
        case let .data(data): return data
        case .invalid: throw KeychainServiceError.invalidStoredData
        case .status(errSecItemNotFound): return nil
        case .status(errSecSuccess): throw KeychainServiceError.internalFailure
        case let .status(status): throw mappedError(status)
        }
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        let firstUpdate = try await update(data, key)
        if firstUpdate == errSecSuccess { return }
        guard firstUpdate == errSecItemNotFound else { throw mappedError(firstUpdate) }

        let firstAdd = try await add(data, key)
        if firstAdd == errSecSuccess { return }
        guard firstAdd == errSecDuplicateItem else { throw mappedError(firstAdd) }

        let secondUpdate = try await update(data, key)
        if secondUpdate == errSecSuccess { return }
        guard secondUpdate == errSecItemNotFound else { throw mappedError(secondUpdate) }

        let secondAdd = try await add(data, key)
        if secondAdd == errSecSuccess { return }
        if secondAdd == errSecDuplicateItem { throw KeychainServiceError.concurrentMutation }
        throw mappedError(secondAdd)
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        let status: OSStatus
        do {
            try Task.checkCancellation()
            status = try await executor.delete(service: service, account: key.account)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.internalFailure
        }
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound { return false }
        throw mappedError(status)
    }

    private func update(_ data: Data, _ key: KeychainKey) async throws -> OSStatus {
        do {
            try Task.checkCancellation()
            return try await executor.update(service: service, account: key.account, data: data)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.internalFailure
        }
    }

    private func add(_ data: Data, _ key: KeychainKey) async throws -> OSStatus {
        do {
            try Task.checkCancellation()
            return try await executor.add(service: service, account: key.account, data: data)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.internalFailure
        }
    }

    private func mappedError(_ status: OSStatus) -> KeychainServiceError {
        switch status {
        case errSecDecode, errSecInvalidData, errSecInvalidEncoding:
            .invalidStoredData
        case errSecNotAvailable, errSecServiceNotAvailable,
             errSecDataNotAvailable, errSecNoSuchKeychain:
            .unavailable
        case errSecInteractionNotAllowed, errSecInteractionRequired:
            .interactionNotAllowed
        case errSecAuthFailed:
            .authenticationFailed
        case errSecUserCanceled:
            .interactionCancelled
        case errSecWrPerm, errSecReadOnly, errSecNoAccessForItem:
            .permissionDenied
        case errSecMissingEntitlement:
            .missingEntitlement
        case errSecDataTooLarge:
            .dataTooLarge
        case errSecParam, errSecInvalidQuery, errSecMissingValue,
             errSecBadReq, errSecReadOnlyAttr:
            .invalidRequest
        default:
            .unexpectedStatus(status)
        }
    }
}
