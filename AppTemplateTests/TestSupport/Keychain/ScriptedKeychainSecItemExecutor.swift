import Foundation
import Security
@testable import AppTemplate

nonisolated enum ScriptedKeychainOperation: Equatable, Sendable {
    case copy(service: String, account: String)
    case update(service: String, account: String, data: Data)
    case add(service: String, account: String, data: Data)
    case delete(service: String, account: String)
}

nonisolated enum ScriptedKeychainResponse: Sendable {
    case copy(KeychainSecItemCopyResult)
    case status(OSStatus)
    case injectedFailure(SentinelExecutorError)
    case cancelCurrentTaskThenStatus(OSStatus)
}

nonisolated struct SentinelExecutorError:
    Error,
    LocalizedError,
    CustomStringConvertible,
    Sendable
{
    let description: String
    var errorDescription: String? { description }
}

actor ScriptedKeychainCallBarrier {
    private var reached = false
    private var released = false
    private var reachedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func reachAndWait() async {
        reached = true
        reachedContinuation?.resume()
        reachedContinuation = nil
        guard !released else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilReached() async {
        guard !reached else { return }
        await withCheckedContinuation { reachedContinuation = $0 }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

actor ScriptedKeychainSecItemExecutor: KeychainSecItemExecuting {
    private var responses: [ScriptedKeychainResponse]
    private var recorded: [ScriptedKeychainOperation] = []
    private let pausedRecordedCallCount: Int?
    private let barrier: ScriptedKeychainCallBarrier?

    init(
        _ responses: [ScriptedKeychainResponse],
        pausedRecordedCallCount: Int? = nil,
        barrier: ScriptedKeychainCallBarrier? = nil
    ) {
        self.responses = responses
        self.pausedRecordedCallCount = pausedRecordedCallCount
        self.barrier = barrier
    }

    func operations() -> [ScriptedKeychainOperation] { recorded }

    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult {
        let response = try await next(.copy(service: service, account: account))
        switch response {
        case let .copy(result):
            return result
        case let .injectedFailure(error):
            throw error
        case .status, .cancelCurrentTaskThenStatus:
            throw SentinelExecutorError(description: "SECRET-EXECUTOR wrong copy response")
        }
    }

    func update(service: String, account: String, data: Data) async throws -> OSStatus {
        let response = try await next(.update(service: service, account: account, data: data))
        return try status(from: response)
    }

    func add(service: String, account: String, data: Data) async throws -> OSStatus {
        let response = try await next(.add(service: service, account: account, data: data))
        return try status(from: response)
    }

    func delete(service: String, account: String) async throws -> OSStatus {
        let response = try await next(.delete(service: service, account: account))
        return try status(from: response)
    }

    private func next(
        _ operation: ScriptedKeychainOperation
    ) async throws -> ScriptedKeychainResponse {
        recorded.append(operation)
        if recorded.count == pausedRecordedCallCount { await barrier?.reachAndWait() }
        guard !responses.isEmpty else {
            throw SentinelExecutorError(description: "SECRET-EXECUTOR missing response")
        }
        return responses.removeFirst()
    }

    private func status(
        from response: ScriptedKeychainResponse
    ) throws -> OSStatus {
        switch response {
        case let .status(status): return status
        case let .injectedFailure(error): throw error
        case let .cancelCurrentTaskThenStatus(status):
            withUnsafeCurrentTask { $0?.cancel() }
            return status
        case .copy:
            throw SentinelExecutorError(description: "SECRET-EXECUTOR wrong status response")
        }
    }
}
