import Foundation
import Security
import Testing
@testable import AppTemplate

struct KeychainServiceTests {
    @Test func readReturnsCopiedDataAndMissingNil() async throws {
        let dataExecutor = ScriptedKeychainSecItemExecutor([.copy(.data(Data([1, 2])))])
        #expect(try await service(dataExecutor).data(for: .data("Token")) == Data([1, 2]))
        #expect(await dataExecutor.operations() == [.copy(service: "AppTemplate", account: "Token")])

        let missing = ScriptedKeychainSecItemExecutor([.copy(.status(errSecItemNotFound))])
        #expect(try await service(missing).data(for: .data("Token")) == nil)
    }

    @Test func readMapsInvalidAndImpossibleSuccessExactly() async {
        let invalid = ScriptedKeychainSecItemExecutor([.copy(.invalid)])
        await #expect(throws: KeychainServiceError.invalidStoredData) {
            _ = try await service(invalid).data(for: .data("Token"))
        }
        let impossible = ScriptedKeychainSecItemExecutor([.copy(.status(errSecSuccess))])
        await #expect(throws: KeychainServiceError.internalFailure) {
            _ = try await service(impossible).data(for: .data("Token"))
        }
        #expect(await impossible.operations().count == 1)
    }

    @Test func everyTerminalSecurityStatusMapsExactly() async {
        for (status, expected) in terminalStatusCases {
            let executor = ScriptedKeychainSecItemExecutor([.copy(.status(status))])
            await #expect(throws: expected) {
                _ = try await service(executor).data(for: .data("Token"))
            }
            #expect(await executor.operations().count == 1)
        }
    }

    @Test func injectedReadFailureMapsToRedactedInternalFailureWithoutExtraCall() async {
        let executor = ScriptedKeychainSecItemExecutor([
            .injectedFailure(SentinelExecutorError(
                description: "SECRET-EXECUTOR service/account/PAYLOAD"
            ))
        ])
        do {
            _ = try await service(executor).data(for: .data("Token"))
            Issue.record("Expected KeychainServiceError.internalFailure")
        } catch {
            assertRedacted(
                error,
                expected: .internalFailure,
                forbidden: ["SECRET-EXECUTOR", "service/account/PAYLOAD"]
            )
        }
        #expect(await executor.operations() == [
            .copy(service: "AppTemplate", account: "Token")
        ])
    }

    @Test func removeReturnsTrueForSuccessAndFalseForAbsence() async throws {
        let success = ScriptedKeychainSecItemExecutor([.status(errSecSuccess)])
        #expect(try await service(success).remove(.data("Token")))
        let missing = ScriptedKeychainSecItemExecutor([.status(errSecItemNotFound)])
        #expect(!(try await service(missing).remove(.data("Token"))))
    }

    @Test func removeMapsEveryTerminalStatusAndInjectedFailureWithoutExtraCall() async {
        for (status, expected) in terminalStatusCases {
            let executor = ScriptedKeychainSecItemExecutor([.status(status)])
            await #expect(throws: expected) {
                _ = try await service(executor).remove(.data("Token"))
            }
            #expect(await executor.operations() == [
                .delete(service: "AppTemplate", account: "Token")
            ])
        }
        let executor = ScriptedKeychainSecItemExecutor([
            .injectedFailure(SentinelExecutorError(
                description: "SECRET-EXECUTOR service/account/PAYLOAD"
            ))
        ])
        do {
            _ = try await service(executor).remove(.data("Token"))
            Issue.record("Expected KeychainServiceError.internalFailure")
        } catch {
            assertRedacted(
                error,
                expected: .internalFailure,
                forbidden: ["SECRET-EXECUTOR", "service/account/PAYLOAD"]
            )
        }
        #expect(await executor.operations().count == 1)
    }

    @Test func operationSpecificSpecialStatusesRejectEveryForbiddenPosition() async {
        let readDuplicate = ScriptedKeychainSecItemExecutor([
            .copy(.status(errSecDuplicateItem))
        ])
        await #expect(throws: KeychainServiceError.unexpectedStatus(errSecDuplicateItem)) {
            _ = try await service(readDuplicate).data(for: .data("Token"))
        }

        let removeDuplicate = ScriptedKeychainSecItemExecutor([
            .status(errSecDuplicateItem)
        ])
        await #expect(throws: KeychainServiceError.unexpectedStatus(errSecDuplicateItem)) {
            _ = try await service(removeDuplicate).remove(.data("Token"))
        }

        let forbiddenSetCases: [
            (responses: [ScriptedKeychainResponse], status: OSStatus,
             expectedCallCount: Int)
        ] = [
            ([.status(errSecDuplicateItem)], errSecDuplicateItem, 1),
            ([.status(errSecItemNotFound), .status(errSecItemNotFound)],
             errSecItemNotFound, 2),
            ([.status(errSecItemNotFound), .status(errSecDuplicateItem),
              .status(errSecDuplicateItem)],
             errSecDuplicateItem, 3),
            ([.status(errSecItemNotFound), .status(errSecDuplicateItem),
              .status(errSecItemNotFound), .status(errSecItemNotFound)],
             errSecItemNotFound, 4)
        ]
        for fixture in forbiddenSetCases {
            let executor = ScriptedKeychainSecItemExecutor(fixture.responses)
            await #expect(throws: KeychainServiceError.unexpectedStatus(fixture.status)) {
                try await service(executor).set(Data(), for: .data("Token"))
            }
            #expect(await executor.operations() == expectedSetOperations(
                count: fixture.expectedCallCount,
                data: Data()
            ))
        }
        #expect(await readDuplicate.operations() == [
            .copy(service: "AppTemplate", account: "Token")
        ])
        #expect(await removeDuplicate.operations() == [
            .delete(service: "AppTemplate", account: "Token")
        ])
    }

    @Test func setUpdateSuccessUsesOneCall() async throws {
        let executor = ScriptedKeychainSecItemExecutor([.status(errSecSuccess)])
        try await service(executor).set(Data([1]), for: .data("Token"))
        #expect(await executor.operations() == [
            .update(service: "AppTemplate", account: "Token", data: Data([1]))
        ])
    }

    @Test func setUpdateMissingThenAddSuccessUsesTwoCalls() async throws {
        let executor = ScriptedKeychainSecItemExecutor([
            .status(errSecItemNotFound), .status(errSecSuccess)
        ])
        try await service(executor).set(Data([1]), for: .data("Token"))
        #expect(await executor.operations() == expectedSetOperations(
            count: 2, data: Data([1])
        ))
    }

    @Test func setConvergesAfterDuplicateRaceInAtMostFourCalls() async throws {
        let three = ScriptedKeychainSecItemExecutor([
            .status(errSecItemNotFound), .status(errSecDuplicateItem), .status(errSecSuccess)
        ])
        try await service(three).set(Data([1]), for: .data("Token"))
        #expect(await three.operations() == expectedSetOperations(
            count: 3, data: Data([1])
        ))

        let four = ScriptedKeychainSecItemExecutor([
            .status(errSecItemNotFound), .status(errSecDuplicateItem),
            .status(errSecItemNotFound), .status(errSecSuccess)
        ])
        try await service(four).set(Data([1]), for: .data("Token"))
        #expect(await four.operations() == expectedSetOperations(
            count: 4, data: Data([1])
        ))
    }

    @Test func secondAddDuplicateThrowsConcurrentMutationAfterFourCalls() async {
        let executor = ScriptedKeychainSecItemExecutor([
            .status(errSecItemNotFound), .status(errSecDuplicateItem),
            .status(errSecItemNotFound), .status(errSecDuplicateItem)
        ])
        await #expect(throws: KeychainServiceError.concurrentMutation) {
            try await service(executor).set(Data([1]), for: .data("Token"))
        }
        #expect(await executor.operations() == expectedSetOperations(
            count: 4, data: Data([1])
        ))
    }

    @Test func everyTerminalSetStatusStopsWithoutExtraCall() async {
        let transitions: [
            (prefix: [ScriptedKeychainResponse], expectedCallCount: Int)
        ] = [
            ([], 1),
            ([.status(errSecItemNotFound)], 2),
            ([.status(errSecItemNotFound), .status(errSecDuplicateItem)],
             3),
            ([.status(errSecItemNotFound), .status(errSecDuplicateItem),
              .status(errSecItemNotFound)], 4)
        ]
        for transition in transitions {
            for (status, expected) in terminalStatusCases {
                let executor = ScriptedKeychainSecItemExecutor(
                    transition.prefix + [.status(status)]
                )
                await #expect(throws: expected) {
                    try await service(executor).set(Data(), for: .data("Token"))
                }
                #expect(await executor.operations() == expectedSetOperations(
                    count: transition.expectedCallCount,
                    data: Data()
                ))
            }
        }
    }

    @Test func injectedExecutorFailureMapsToRedactedInternalFailureAtEverySetCall() async {
        let prefixes: [[ScriptedKeychainResponse]] = [
            [],
            [.status(errSecItemNotFound)],
            [.status(errSecItemNotFound), .status(errSecDuplicateItem)],
            [.status(errSecItemNotFound), .status(errSecDuplicateItem),
             .status(errSecItemNotFound)]
        ]
        for prefix in prefixes {
            let executor = ScriptedKeychainSecItemExecutor(prefix + [
                .injectedFailure(SentinelExecutorError(
                    description: "SECRET-EXECUTOR service/account/PAYLOAD"
                ))
            ])
            do {
                try await service(executor).set(Data(), for: .data("Token"))
                Issue.record("Expected KeychainServiceError.internalFailure")
            } catch {
                assertRedacted(
                    error,
                    expected: .internalFailure,
                    forbidden: ["SECRET-EXECUTOR", "service/account/PAYLOAD"]
                )
            }
            #expect(await executor.operations() == expectedSetOperations(
                count: prefix.count + 1,
                data: Data()
            ))
        }
    }

    @Test func preCancelledPublicOperationsInvokeNothing() async {
        let readExecutor = ScriptedKeychainSecItemExecutor([])
        let readTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await service(readExecutor).data(for: .data("Token"))
        }
        await #expect(throws: CancellationError.self) { try await readTask.value }

        let setExecutor = ScriptedKeychainSecItemExecutor([])
        let setTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await service(setExecutor).set(Data(), for: .data("Token"))
        }
        await #expect(throws: CancellationError.self) { try await setTask.value }

        let removeExecutor = ScriptedKeychainSecItemExecutor([])
        let removeTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await service(removeExecutor).remove(.data("Token"))
        }
        await #expect(throws: CancellationError.self) { try await removeTask.value }

        #expect(await readExecutor.operations().isEmpty)
        #expect(await setExecutor.operations().isEmpty)
        #expect(await removeExecutor.operations().isEmpty)
    }

    @Test(arguments: [1, 2, 3])
    func cancellationBetweenEveryRetryStopsNextCall(_ completedCallCount: Int) async {
        let responses: [ScriptedKeychainResponse] = [
            .status(errSecItemNotFound), .status(errSecDuplicateItem),
            .status(errSecItemNotFound), .status(errSecSuccess)
        ]
        let barrier = ScriptedKeychainCallBarrier()
        let executor = ScriptedKeychainSecItemExecutor(
            responses,
            pausedRecordedCallCount: completedCallCount,
            barrier: barrier
        )
        let task = Task { try await service(executor).set(Data(), for: .data("Token")) }
        await barrier.waitUntilReached()
        task.cancel()
        await barrier.release()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await executor.operations() == expectedSetOperations(
            count: completedCallCount,
            data: Data()
        ))
    }

    @Test func cancellationDuringSuccessfulMutationOrDeleteIsNotPostChecked() async throws {
        let update = ScriptedKeychainSecItemExecutor([.cancelCurrentTaskThenStatus(errSecSuccess)])
        try await Task { try await service(update).set(Data(), for: .data("Token")) }.value
        let add = ScriptedKeychainSecItemExecutor([
            .status(errSecItemNotFound), .cancelCurrentTaskThenStatus(errSecSuccess)
        ])
        try await Task { try await service(add).set(Data(), for: .data("Token")) }.value
        let delete = ScriptedKeychainSecItemExecutor([.cancelCurrentTaskThenStatus(errSecSuccess)])
        #expect(try await Task { try await service(delete).remove(.data("Token")) }.value)
    }

    @Test func manyDistinctKeysCompleteWithExactPerKeySequences() async throws {
        let executor = ConcurrentKeychainSecItemExecutor()
        let keychain = service(executor)
        let entries = (0..<100).map { (account: "Distinct-\($0)", data: Data([UInt8($0)])) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask {
                    try await keychain.set(entry.data, for: .data(entry.account))
                }
            }
            try await group.waitForAll()
        }

        let operations = await executor.operations()
        #expect(operations.count == 200)
        for entry in entries {
            #expect(await executor.storedData(for: entry.account) == entry.data)
            #expect(operations.filter { operation in
                switch operation {
                case let .update(_, account, _), let .add(_, account, _): account == entry.account
                case .copy, .delete: false
                }
            } == [
                .update(service: "AppTemplate", account: entry.account, data: entry.data),
                .add(service: "AppTemplate", account: entry.account, data: entry.data)
            ])
        }
    }

    @Test func manyWritersForOneKeyCompleteWithValidPerPayloadSequences() async throws {
        let executor = ConcurrentKeychainSecItemExecutor()
        let keychain = service(executor)
        let payloads = (0..<100).map { Data([UInt8($0)]) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for payload in payloads {
                group.addTask {
                    try await keychain.set(payload, for: .data("Token"))
                }
            }
            try await group.waitForAll()
        }

        let operations = await executor.operations()
        #expect((100...400).contains(operations.count))
        #expect(await executor.storedData(for: "Token").map { payloads.contains($0) } == true)
        for payload in payloads {
            let payloadOperations = operations.filter { operation in
                switch operation {
                case let .update(_, _, data), let .add(_, _, data): data == payload
                case .copy, .delete: false
                }
            }
            #expect((1...4).contains(payloadOperations.count))
            #expect(payloadOperations == expectedSetOperations(
                count: payloadOperations.count,
                data: payload
            ))
        }
    }

    #if os(macOS)
    @Test func blankServiceNamespaceTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainService(
                service: " \n\t ",
                executor: ScriptedKeychainSecItemExecutor([])
            )
        }
    }

    @Test func nulServiceNamespaceTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainService(
                service: "Bad\0Service",
                executor: ScriptedKeychainSecItemExecutor([])
            )
        }
    }
    #endif
}

nonisolated private let terminalStatusCases: [(OSStatus, KeychainServiceError)] = [
    (errSecDecode, .invalidStoredData),
    (errSecInvalidData, .invalidStoredData),
    (errSecInvalidEncoding, .invalidStoredData),
    (errSecNotAvailable, .unavailable),
    (errSecServiceNotAvailable, .unavailable),
    (errSecDataNotAvailable, .unavailable),
    (errSecNoSuchKeychain, .unavailable),
    (errSecInteractionNotAllowed, .interactionNotAllowed),
    (errSecInteractionRequired, .interactionNotAllowed),
    (errSecAuthFailed, .authenticationFailed),
    (errSecUserCanceled, .interactionCancelled),
    (errSecWrPerm, .permissionDenied),
    (errSecReadOnly, .permissionDenied),
    (errSecNoAccessForItem, .permissionDenied),
    (errSecMissingEntitlement, .missingEntitlement),
    (errSecDataTooLarge, .dataTooLarge),
    (errSecParam, .invalidRequest),
    (errSecInvalidQuery, .invalidRequest),
    (errSecMissingValue, .invalidRequest),
    (errSecBadReq, .invalidRequest),
    (errSecReadOnlyAttr, .invalidRequest),
    (-7777, .unexpectedStatus(-7777))
]

nonisolated private func expectedSetOperations(
    count: Int,
    data: Data
) -> [ScriptedKeychainOperation] {
    precondition((1...4).contains(count))
    return Array([
        .update(service: "AppTemplate", account: "Token", data: data),
        .add(service: "AppTemplate", account: "Token", data: data),
        .update(service: "AppTemplate", account: "Token", data: data),
        .add(service: "AppTemplate", account: "Token", data: data)
    ].prefix(count))
}

nonisolated private func service(
    _ executor: any KeychainSecItemExecuting
) -> KeychainService {
    KeychainService(service: "AppTemplate", executor: executor)
}

actor ConcurrentKeychainSecItemExecutor: KeychainSecItemExecuting {
    private var values: [String: Data] = [:]
    private var recorded: [ScriptedKeychainOperation] = []

    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult {
        throw SentinelExecutorError(description: "copy is unused")
    }

    func update(service: String, account: String, data: Data) async throws -> OSStatus {
        recorded.append(.update(service: service, account: account, data: data))
        guard values[account] != nil else { return errSecItemNotFound }
        values[account] = data
        return errSecSuccess
    }

    func add(service: String, account: String, data: Data) async throws -> OSStatus {
        recorded.append(.add(service: service, account: account, data: data))
        guard values[account] == nil else { return errSecDuplicateItem }
        values[account] = data
        return errSecSuccess
    }

    func delete(service: String, account: String) async throws -> OSStatus {
        throw SentinelExecutorError(description: "delete is unused")
    }

    func operations() -> [ScriptedKeychainOperation] { recorded }
    func storedData(for account: String) -> Data? { values[account] }
}
