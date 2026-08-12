import Foundation
import Security

nonisolated protocol KeychainSecItemExecuting: Sendable {
    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult
    func update(service: String, account: String, data: Data) async throws -> OSStatus
    func add(service: String, account: String, data: Data) async throws -> OSStatus
    func delete(service: String, account: String) async throws -> OSStatus
}

nonisolated enum KeychainSecItemCopyResult: Equatable, Sendable {
    case data(Data)
    case invalid
    case status(OSStatus)
}
