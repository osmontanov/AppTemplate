import CoreFoundation
import Foundation
import Security
import Synchronization
import Testing
@testable import AppTemplate

struct SecurityKeychainSecItemExecutorTests {
    @Test func copyUsesExactDataProtectionQueryAndCopiesBytes() async throws {
        let source = MutableCFDataSource(Data([1, 2, 3]))
        let recorder = SecurityCallRecorder(copyResult: .mutableData(source))
        let result = try await makeExecutor(recorder).copy(service: "Service", account: "Account")
        #expect(result == .data(Data([1, 2, 3])))
        source.replace(with: Data([9, 9, 9]))
        #expect(result == .data(Data([1, 2, 3])))
        #expect(recorder.onlyCall()?.kind == .copy)
        #expect(recorder.onlyCall()?.query == .copy(service: "Service", account: "Account"))
    }

    @Test func updateUsesExactIdentityAndAttributes() async throws {
        let recorder = SecurityCallRecorder()
        #expect(try await makeExecutor(recorder).update(
            service: "Service", account: "Account", data: Data([4])
        ) == errSecSuccess)
        #expect(recorder.onlyCall() == .update(
            query: .base(service: "Service", account: "Account"),
            data: Data([4]), accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        ))
    }

    @Test func addUsesExactIdentityAndAttributes() async throws {
        let recorder = SecurityCallRecorder()
        #expect(try await makeExecutor(recorder).add(
            service: "Service", account: "Account", data: Data([5])
        ) == errSecSuccess)
        #expect(recorder.onlyCall() == .add(
            query: .base(service: "Service", account: "Account"),
            data: Data([5]), accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        ))
    }

    @Test func deleteUsesExactBaseIdentity() async throws {
        let recorder = SecurityCallRecorder()
        #expect(try await makeExecutor(recorder).delete(service: "Service", account: "Account") == errSecSuccess)
        #expect(recorder.onlyCall() == .delete(query: .base(service: "Service", account: "Account")))
    }

    @Test func copyUsesPhysicalCFBooleans() async throws {
        let recorder = SecurityCallRecorder(copyResult: .data(Data()))
        _ = try await makeExecutor(recorder).copy(service: "Service", account: "Account")
        let call = try #require(recorder.onlyCall())
        #expect(call.booleanEvidence.synchronizableType == CFBooleanGetTypeID())
        #expect(call.booleanEvidence.dataProtectionType == CFBooleanGetTypeID())
        #expect(call.booleanEvidence.returnDataType == CFBooleanGetTypeID())
        #expect(call.booleanEvidence.synchronizableIsFalse)
        #expect(call.booleanEvidence.dataProtectionIsTrue)
        #expect(call.booleanEvidence.returnDataIsTrue)
    }

    @Test func copyClassifiesNilWrongEmptyAndNonSuccessResults() async throws {
        #expect(try await makeExecutor(SecurityCallRecorder(copyResult: .none)).copy(
            service: "S", account: "A"
        ) == .invalid)
        #expect(try await makeExecutor(SecurityCallRecorder(copyResult: .string("wrong"))).copy(
            service: "S", account: "A"
        ) == .invalid)
        #expect(try await makeExecutor(SecurityCallRecorder(copyResult: .data(Data()))).copy(
            service: "S", account: "A"
        ) == .data(Data()))
        let failure = SecurityCallRecorder(
            copyStatus: errSecAuthFailed,
            copyResult: .data(Data([7]))
        )
        #expect(try await makeExecutor(failure).copy(service: "S", account: "A") == .status(errSecAuthFailed))
    }

    @Test func eachMethodInvokesExactlyOneSecurityClosure() async throws {
        let recorder = SecurityCallRecorder(copyResult: .data(Data()))
        let executor = makeExecutor(recorder)
        _ = try await executor.copy(service: "S", account: "C")
        _ = try await executor.update(service: "S", account: "U", data: Data())
        _ = try await executor.add(service: "S", account: "A", data: Data())
        _ = try await executor.delete(service: "S", account: "D")
        #expect(recorder.callKinds() == [.copy, .update, .add, .delete])
    }

    @Test func mutationMethodsReturnExactNonSuccessSecurityStatus() async throws {
        let sentinel: OSStatus = -7777
        let recorder = SecurityCallRecorder(
            updateStatus: sentinel,
            addStatus: sentinel,
            deleteStatus: sentinel
        )
        let executor = makeExecutor(recorder)
        #expect(try await executor.update(
            service: "S", account: "U", data: Data([1])
        ) == sentinel)
        #expect(try await executor.add(
            service: "S", account: "A", data: Data([2])
        ) == sentinel)
        #expect(try await executor.delete(service: "S", account: "D") == sentinel)
        #expect(recorder.callKinds() == [.update, .add, .delete])
    }

    @Test(arguments: SecurityCallKind.allCases)
    func preCancelledExecutorMethodsInvokeNoSecurityClosure(
        _ operation: SecurityCallKind
    ) async {
        let recorder = SecurityCallRecorder(copyResult: .data(Data()))
        let executor = makeExecutor(recorder)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            switch operation {
            case .copy:
                _ = try await executor.copy(service: "S", account: "A")
            case .update:
                _ = try await executor.update(service: "S", account: "A", data: Data())
            case .add:
                _ = try await executor.add(service: "S", account: "A", data: Data())
            case .delete:
                _ = try await executor.delete(service: "S", account: "A")
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(recorder.callKinds().isEmpty)
    }

    @Test func cancellationWhileExecutorIsOccupiedPreventsQueuedSecurityClosure() async throws {
        let gate = SecurityClosureGate()
        let recorder = SecurityCallRecorder(
            copyResult: .data(Data()),
            copyGate: gate
        )
        let executor = makeExecutor(recorder)
        let first = Task { try await executor.copy(service: "S", account: "First") }
        let entered = await gate.waitUntilEntered()
        #expect(entered)
        guard entered else {
            gate.release()
            _ = try? await first.value
            return
        }
        let queuedStart = QueuedExecutorCallStart()
        let queued = Task {
            queuedStart.markStarted()
            _ = try await executor.update(service: "S", account: "Queued", data: Data())
        }
        let queuedStarted = await queuedStart.waitUntilStarted()
        #expect(queuedStarted)
        guard queuedStarted else {
            queued.cancel()
            gate.release()
            _ = try? await first.value
            _ = try? await queued.value
            return
        }
        await Task.yield()
        queued.cancel()
        gate.release()
        #expect(try await first.value == .data(Data()))
        await #expect(throws: CancellationError.self) { _ = try await queued.value }
        #expect(recorder.callKinds() == [.copy])
        #expect(!gate.didTimeOut)
    }

    @Test func closureTableIsCheckedSendableAndRecorderHandlesConcurrentDirectCalls() async throws {
        let recorder = SecurityCallRecorder(copyResult: .data(Data([1])))
        let api = recorder.api
        requireSendable(api)
        let statuses = await withTaskGroup(of: OSStatus.self) { group in
            for index in 0..<200 {
                group.addTask {
                    let query: [CFString: Any] = [
                        kSecClass: kSecClassGenericPassword,
                        kSecAttrService: "S",
                        kSecAttrAccount: "A\(index)",
                        kSecAttrSynchronizable: kCFBooleanFalse!,
                        kSecUseDataProtectionKeychain: kCFBooleanTrue!,
                        kSecReturnData: kCFBooleanTrue!,
                        kSecMatchLimit: kSecMatchLimitOne
                    ]
                    var object: CFTypeRef?
                    return api.copyMatching(query as CFDictionary, &object)
                }
            }
            var results: [OSStatus] = []
            for await status in group { results.append(status) }
            return results
        }
        #expect(statuses.allSatisfy { $0 == errSecSuccess })
        #expect(recorder.callKinds().count == 200)
    }
}

nonisolated private func requireSendable<T: Sendable>(_ value: T) {}

nonisolated enum SecurityCallKind: CaseIterable, Equatable, Sendable {
    case copy, update, add, delete
}

nonisolated final class SecurityClosureGate: Sendable {
    private let entered = Atomic(false)
    private let released = Atomic(false)
    private let timedOut = Atomic(false)

    func enterAndWait() {
        entered.store(true, ordering: .releasing)
        let deadline = ContinuousClock.now + .seconds(10)
        while !released.load(ordering: .acquiring), ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        if !released.load(ordering: .acquiring) {
            timedOut.store(true, ordering: .releasing)
        }
    }

    func waitUntilEntered() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(10)
        while !entered.load(ordering: .acquiring), ContinuousClock.now < deadline {
            await Task.yield()
        }
        return entered.load(ordering: .acquiring)
    }

    func release() { released.store(true, ordering: .releasing) }
    var didTimeOut: Bool { timedOut.load(ordering: .acquiring) }
}

nonisolated final class QueuedExecutorCallStart: Sendable {
    private let started = Atomic(false)

    func markStarted() { started.store(true, ordering: .releasing) }

    func waitUntilStarted() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(10)
        while !started.load(ordering: .acquiring), ContinuousClock.now < deadline {
            await Task.yield()
        }
        return started.load(ordering: .acquiring)
    }
}

nonisolated struct BooleanEvidence: Equatable, Sendable {
    let synchronizableType: CFTypeID
    let dataProtectionType: CFTypeID
    let returnDataType: CFTypeID?
    let synchronizableIsFalse: Bool
    let dataProtectionIsTrue: Bool
    let returnDataIsTrue: Bool
}

nonisolated struct QuerySnapshot: Equatable, Sendable {
    let service: String
    let account: String
    let keyNames: Set<String>
    let synchronizable: Bool
    let dataProtection: Bool
    let returnData: Bool?
    let matchLimit: String?
    let booleanEvidence: BooleanEvidence

    static func base(service: String, account: String) -> Self {
        Self(
            service: service,
            account: account,
            keyNames: [
                kSecClass as String,
                kSecAttrService as String,
                kSecAttrAccount as String,
                kSecAttrSynchronizable as String,
                kSecUseDataProtectionKeychain as String
            ],
            synchronizable: false,
            dataProtection: true,
            returnData: nil,
            matchLimit: nil,
            booleanEvidence: .required(returnData: nil)
        )
    }

    static func copy(service: String, account: String) -> Self {
        Self(
            service: service,
            account: account,
            keyNames: base(service: service, account: account).keyNames.union([
                kSecReturnData as String,
                kSecMatchLimit as String
            ]),
            synchronizable: false,
            dataProtection: true,
            returnData: true,
            matchLimit: kSecMatchLimitOne as String,
            booleanEvidence: .required(returnData: true)
        )
    }
}

nonisolated extension BooleanEvidence {
    static func required(returnData: Bool?) -> Self {
        Self(
            synchronizableType: CFBooleanGetTypeID(),
            dataProtectionType: CFBooleanGetTypeID(),
            returnDataType: returnData == nil ? nil : CFBooleanGetTypeID(),
            synchronizableIsFalse: true,
            dataProtectionIsTrue: true,
            returnDataIsTrue: returnData == true
        )
    }
}

nonisolated enum SecurityCall: Equatable, Sendable {
    case copy(query: QuerySnapshot)
    case update(query: QuerySnapshot, data: Data, accessible: String)
    case add(query: QuerySnapshot, data: Data, accessible: String)
    case delete(query: QuerySnapshot)

    var kind: SecurityCallKind {
        switch self {
        case .copy: .copy
        case .update: .update
        case .add: .add
        case .delete: .delete
        }
    }

    var query: QuerySnapshot {
        switch self {
        case let .copy(query), let .update(query, _, _),
             let .add(query, _, _), let .delete(query):
            query
        }
    }

    var booleanEvidence: BooleanEvidence { query.booleanEvidence }
}

// Test-only synchronization wrapper. `NSMutableData` is non-Sendable, so this
// one test fixture uses a reviewed unchecked conformance. It is file-private
// in use: the fake closure synchronously lends its retained CFData, the
// executor copies it without an intervening await, and the test calls replace
// only after awaited copy completion. The Mutex protects the wrapper's own
// pointer handoff/mutation; no concurrent mutation is permitted. Production
// Keychain source remains forbidden from using unchecked conformances.
nonisolated final class MutableCFDataSource: @unchecked Sendable {
    private let lock = Mutex(())
    private let storage: NSMutableData

    init(_ data: Data) { storage = NSMutableData(data: data) }

    func write(to pointer: UnsafeMutablePointer<CFTypeRef?>?) {
        lock.withLock { _ in pointer?.pointee = storage as CFData }
    }

    func replace(with data: Data) {
        lock.withLock { _ in storage.setData(data) }
    }
}

nonisolated enum FakeCopyResult: Sendable {
    case none
    case data(Data)
    case mutableData(MutableCFDataSource)
    case string(String)

    func write(to pointer: UnsafeMutablePointer<CFTypeRef?>?) {
        switch self {
        case .none:
            pointer?.pointee = nil
        case let .data(data):
            pointer?.pointee = data as CFData
        case let .mutableData(source):
            source.write(to: pointer)
        case let .string(string):
            pointer?.pointee = string as CFString
        }
    }
}

nonisolated private struct RawDictionary {
    let values: NSDictionary
    let keys: Set<String>

    init?(_ dictionary: CFDictionary) {
        let values = dictionary as NSDictionary
        let stringKeys = values.allKeys.compactMap { $0 as? String }
        guard stringKeys.count == values.count else { return nil }
        self.values = values
        keys = Set(stringKeys)
    }

    func value(_ key: CFString) -> Any? { values[key as String] }
}

nonisolated private func booleanEvidence(
    _ raw: RawDictionary,
    includesReturnData: Bool
) -> BooleanEvidence? {
    guard
        let synchronizable = raw.value(kSecAttrSynchronizable),
        let dataProtection = raw.value(kSecUseDataProtectionKeychain)
    else { return nil }
    let synchronizableRef = synchronizable as CFTypeRef
    let dataProtectionRef = dataProtection as CFTypeRef
    let returnData = includesReturnData ? raw.value(kSecReturnData) : nil
    let returnDataRef = returnData.map { $0 as CFTypeRef }
    return BooleanEvidence(
        synchronizableType: CFGetTypeID(synchronizableRef),
        dataProtectionType: CFGetTypeID(dataProtectionRef),
        returnDataType: returnDataRef.map(CFGetTypeID),
        synchronizableIsFalse: CFEqual(synchronizableRef, kCFBooleanFalse!),
        dataProtectionIsTrue: CFEqual(dataProtectionRef, kCFBooleanTrue!),
        returnDataIsTrue: returnDataRef.map { CFEqual($0, kCFBooleanTrue!) } ?? false
    )
}

nonisolated private let baseKeyNames: Set<String> = [
    kSecClass as String,
    kSecAttrService as String,
    kSecAttrAccount as String,
    kSecAttrSynchronizable as String,
    kSecUseDataProtectionKeychain as String
]

nonisolated private func normalizeIdentity(
    _ dictionary: CFDictionary,
    expectedKeys: Set<String>,
    reportedKeys: Set<String>,
    includesReturnData: Bool
) -> QuerySnapshot? {
    guard
        let raw = RawDictionary(dictionary),
        raw.keys == expectedKeys,
        raw.value(kSecClass) as? String == kSecClassGenericPassword as String,
        let service = raw.value(kSecAttrService) as? String,
        let account = raw.value(kSecAttrAccount) as? String,
        let evidence = booleanEvidence(raw, includesReturnData: includesReturnData),
        evidence.synchronizableType == CFBooleanGetTypeID(),
        evidence.dataProtectionType == CFBooleanGetTypeID(),
        evidence.synchronizableIsFalse,
        evidence.dataProtectionIsTrue
    else { return nil }

    let matchLimit = raw.value(kSecMatchLimit) as? String
    if includesReturnData {
        guard
            evidence.returnDataType == CFBooleanGetTypeID(),
            evidence.returnDataIsTrue,
            matchLimit == kSecMatchLimitOne as String
        else { return nil }
    }
    return QuerySnapshot(
        service: service,
        account: account,
        keyNames: reportedKeys,
        synchronizable: false,
        dataProtection: true,
        returnData: includesReturnData ? true : nil,
        matchLimit: includesReturnData ? matchLimit : nil,
        booleanEvidence: evidence
    )
}

nonisolated private func normalizeMutationAttributes(
    _ dictionary: CFDictionary
) -> (data: Data, accessible: String)? {
    guard
        let raw = RawDictionary(dictionary),
        raw.keys == [kSecValueData as String, kSecAttrAccessible as String],
        let data = raw.value(kSecValueData) as? Data,
        let accessible = raw.value(kSecAttrAccessible) as? String,
        accessible == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
    else { return nil }
    return (data, accessible)
}

nonisolated final class SecurityCallRecorder: Sendable {
    private struct State: Sendable {
        var calls: [SecurityCall] = []
        var normalizationFailures: [String] = []
    }

    private let state = Mutex(State())
    private let copyStatus: OSStatus
    private let updateStatus: OSStatus
    private let addStatus: OSStatus
    private let deleteStatus: OSStatus
    private let copyResult: FakeCopyResult
    private let copyGate: SecurityClosureGate?

    init(
        copyStatus: OSStatus = errSecSuccess,
        copyResult: FakeCopyResult = .none,
        updateStatus: OSStatus = errSecSuccess,
        addStatus: OSStatus = errSecSuccess,
        deleteStatus: OSStatus = errSecSuccess,
        copyGate: SecurityClosureGate? = nil
    ) {
        self.copyStatus = copyStatus
        self.copyResult = copyResult
        self.updateStatus = updateStatus
        self.addStatus = addStatus
        self.deleteStatus = deleteStatus
        self.copyGate = copyGate
    }

    var api: KeychainSecurityAPI {
        KeychainSecurityAPI(
            copyMatching: { [self] query, result in
                let expected = baseKeyNames.union([
                    kSecReturnData as String,
                    kSecMatchLimit as String
                ])
                guard let snapshot = normalizeIdentity(
                    query,
                    expectedKeys: expected,
                    reportedKeys: expected,
                    includesReturnData: true
                ) else { return normalizationFailure("copy") }
                state.withLock { $0.calls.append(.copy(query: snapshot)) }
                copyGate?.enterAndWait()
                copyResult.write(to: result)
                return copyStatus
            },
            update: { [self] query, attributes in
                guard
                    let identity = normalizeIdentity(
                        query,
                        expectedKeys: baseKeyNames,
                        reportedKeys: baseKeyNames,
                        includesReturnData: false
                    ),
                    let mutation = normalizeMutationAttributes(attributes)
                else { return normalizationFailure("update") }
                state.withLock {
                    $0.calls.append(.update(
                        query: identity,
                        data: mutation.data,
                        accessible: mutation.accessible
                    ))
                }
                return updateStatus
            },
            add: { [self] attributes, result in
                let mutationKeys: Set<String> = [
                    kSecValueData as String,
                    kSecAttrAccessible as String
                ]
                guard
                    result == nil,
                    let identity = normalizeIdentity(
                        attributes,
                        expectedKeys: baseKeyNames.union(mutationKeys),
                        reportedKeys: baseKeyNames,
                        includesReturnData: false
                    ),
                    let raw = RawDictionary(attributes),
                    let data = raw.value(kSecValueData) as? Data,
                    let accessible = raw.value(kSecAttrAccessible) as? String,
                    accessible == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
                else { return normalizationFailure("add") }
                state.withLock {
                    $0.calls.append(.add(
                        query: identity,
                        data: data,
                        accessible: accessible
                    ))
                }
                return addStatus
            },
            delete: { [self] query in
                guard let identity = normalizeIdentity(
                    query,
                    expectedKeys: baseKeyNames,
                    reportedKeys: baseKeyNames,
                    includesReturnData: false
                ) else { return normalizationFailure("delete") }
                state.withLock { $0.calls.append(.delete(query: identity)) }
                return deleteStatus
            }
        )
    }

    func onlyCall() -> SecurityCall? {
        state.withLock {
            guard $0.normalizationFailures.isEmpty, $0.calls.count == 1 else { return nil }
            return $0.calls[0]
        }
    }

    func callKinds() -> [SecurityCallKind] {
        state.withLock { $0.calls.map(\.kind) }
    }

    func failures() -> [String] {
        state.withLock { $0.normalizationFailures }
    }

    private func normalizationFailure(_ operation: String) -> OSStatus {
        state.withLock { $0.normalizationFailures.append(operation) }
        return errSecParam
    }
}

nonisolated private func makeExecutor(
    _ recorder: SecurityCallRecorder
) -> SecurityKeychainSecItemExecutor {
    SecurityKeychainSecItemExecutor(security: recorder.api)
}
