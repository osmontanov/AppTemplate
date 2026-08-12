import Foundation
import Testing
@testable import AppTemplate

struct InMemoryKeychainServiceTests {
    @Test func inMemoryServiceRoundTripsAndRemoves() async throws {
        let service = InMemoryKeychainService()
        let key = KeychainKey.data("Token")
        #expect(try await service.data(for: key) == nil)
        try await service.set(Data([1]), for: key)
        #expect(try await service.data(for: key) == Data([1]))
        try await service.set(Data([2]), for: key)
        #expect(try await service.data(for: key) == Data([2]))
        #expect(try await service.remove(key))
        #expect(!(try await service.remove(key)))
    }

    @Test func protocolConveniencesUseTheSameCodecs() async throws {
        let service: any IKeychainService = InMemoryKeychainService()
        let stringKey = KeychainKey.data("String")
        let modelKey: KeychainCodableKey<FirstSecret> = .codable("Model", schemaVersion: 1)
        try await service.set("value", for: stringKey)
        try await service.set(FirstSecret(value: 8), for: modelKey)
        #expect(try await service.string(for: stringKey) == "value")
        #expect(try await service.value(for: modelKey) == FirstSecret(value: 8))
    }

    @Test func preCancelledOperationsDoNotReadWriteOrRemove() async throws {
        let service = InMemoryKeychainService()
        let key = KeychainKey.data("Token")
        try await service.set(Data([1]), for: key)
        for operation in InMemoryInvocation.allCases {
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await operation.invoke(service, key)
            }
            await #expect(throws: CancellationError.self) { _ = try await task.value }
        }
        #expect(try await service.data(for: key) == Data([1]))
    }

    @Test func concurrentIndependentKeysRemainIsolated() async throws {
        let service = InMemoryKeychainService()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask {
                    try await service.set(Data([UInt8(index % 256)]), for: .data("Key-\(index)"))
                }
            }
            try await group.waitForAll()
        }
        for index in 0..<200 {
            #expect(try await service.data(for: .data("Key-\(index)")) == Data([UInt8(index % 256)]))
        }
    }

    @Test func separateInstancesDoNotShareStorage() async throws {
        let first = InMemoryKeychainService()
        let second = InMemoryKeychainService()
        let key = KeychainKey.data("Token")

        try await first.set(Data([1]), for: key)

        #expect(try await second.data(for: key) == nil)
    }
}

private enum InMemoryInvocation: CaseIterable, Sendable {
    case read
    case set
    case remove

    func invoke(
        _ service: InMemoryKeychainService,
        _ key: KeychainKey
    ) async throws {
        switch self {
        case .read:
            _ = try await service.data(for: key)
        case .set:
            try await service.set(Data([2]), for: key)
        case .remove:
            _ = try await service.remove(key)
        }
    }
}
