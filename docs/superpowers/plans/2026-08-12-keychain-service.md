# App-Private Keychain Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an async, app-private Data Protection Keychain boundary for small secrets, with typed String/versioned-Codable conveniences, deterministic injected-Security tests, and fresh in-memory preview/UI-test composition.

**Architecture:** `IKeychainService` exposes raw `Data` through an actor-safe async contract; protocol extensions own UTF-8 and direct-JSON codecs. `KeychainService` owns public errors, cancellation, and the bounded update-add-update-add state machine, while a separate `SecurityKeychainSecItemExecutor` actor contains every Core Foundation dictionary and synchronous Security call behind a checked-`Sendable` closure table.

**Tech Stack:** Swift 6.3, Foundation, CoreFoundation, Security, Synchronization, Swift Testing, Xcode 26.6, iOS/iPadOS/macOS 26, filesystem-synchronized Xcode groups.

## Global Constraints

- Treat `docs/superpowers/specs/2026-08-12-keychain-service-design.md` at commit `a83574042cd38ee6a53eb2f74bc7f59e2196e7ac` as normative. Its history for this cycle is exactly design commit `96205b098e9084db96745b3d7259ab6c4275903b` plus hardening commit `a83574042cd38ee6a53eb2f74bc7f59e2196e7ac`.
- Treat `fb683478a36736f5f062ab036bd956cb2faecd17` as the immutable Keychain implementation base for changed-path scope and whole-branch review. The reviewed plan commit is created after that base; `a835740...` remains the normative specification commit, not the implementation-diff base.
- Work only in `/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database` on branch `codex/userdefaults-service`. Commit this reviewed plan before implementation Task 1 starts; implementation tasks require a clean worktree and do not stage the plan.
- **Hard execution precondition:** do not create a production or test Keychain Swift file until the preceding UserDefaults Task 6 report says PASS and records PASS for all nine gates. At plan-writing time `.superpowers/sdd/2026-08-12-userdefaults-service/final-verification-report.md` is blocked by macOS UI-automation initialization and gates 1–9 are not run. Planning may complete; implementation may not start from that state.
- The rerun that clears the precondition must treat the Keychain spec's committed history as the two documentation-only commits above, prove the reviewed Keychain plan was introduced by one documentation-only commit, exclude exactly those two documentation paths from the UserDefaults changed-path set, and must not require the current spec blob to equal the earlier `96205b0` blob.
- Follow strict TDD in every implementation task: write the focused failing test, retain the intended RED evidence, add only the minimum implementation, rerun a fresh GREEN bundle, perform the listed mutation probes, restore production code, rerun GREEN, review, then commit.
- Every Swift declaration that must escape MainActor-default isolation is explicitly `nonisolated`. Both production layers and the in-memory service are actors; production code uses no detached task, semaphore, lock, global queue, callback bridge, or global mutable cache. Test-only synchronization is limited to the explicitly specified `Synchronization.Mutex`/`Atomic` fixtures and actor barriers; no real Security closure is invoked by them.
- Public storage is exactly raw `Data` read/set/Bool-remove. UTF-8 `String` and versioned `Codable & Sendable` conveniences live only on `IKeychainService`; no public Security dictionary, status, access group, default value, logger, property wrapper, enumeration, or delete-all API is authorized.
- Every item is a generic password in the Data Protection Keychain, explicitly nonsynchronizable, protected by `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and queried without `kSecAttrAccessGroup` under the no-extra-authorized-groups invariant.
- `KeychainSecurityAPI` uses four explicitly `@Sendable` closure types and synthesized checked `Sendable`. Production Keychain source must contain no `@unchecked Sendable`. All fake closure mutation uses `Synchronization.Mutex` or actor isolation.
- Core Foundation dictionaries, `Any`, pointers, and result objects remain synchronous and executor-actor-local. Reduce them to owned `Data`, `.invalid`, or `OSStatus` before returning. After a `CFData` type-ID check, use `unsafeDowncast`, never `unsafeBitCast`.
- Every query Boolean is a nonoptional physical `CFBoolean` returned by the exact `nonisolated private func requiredCFBoolean(_ value: Bool) -> CFBoolean` whose body is `value ? kCFBooleanTrue! : kCFBooleanFalse!`. Tests inspect `CFGetTypeID` and `CFEqual`; bridgeable truthiness is not sufficient.
- Ordinary unit, composition, preview, and UI tests must never invoke real `SecItemCopyMatching`, `SecItemUpdate`, `SecItemAdd`, or `SecItemDelete`. Concrete-service tests inject a semantic scripted executor; query tests inject synchronized fake Security closures into the real executor.
- Preserve the completed UserDefaults/AppState, SwiftData, networking, navigation, Feature, preview, and UI-test behavior. Keychain stores no real token and adds no Feature/ViewModel consumer.
- Live service/account names are fixed opaque metadata: service exactly `AppTemplate`; test names use fixed sentinels. Never derive service/account from a secret, user ID, email, response, localized text, or bundle metadata.
- Do not add packages, capabilities, entitlements, an entitlements file, App Groups, Keychain Sharing, custom access groups, synchronizable items, biometrics, prompts, background-locked policy, file-based `SecKeychain` APIs, logging, a privacy manifest, build setting, deployment change, project membership edit, or hosted automation.
- `REGISTER_APP_GROUPS = YES` remains byte-for-byte unchanged. It is a project setting, not proof of an entitlement.
- Every RED, GREEN, compiler proof, and final automated gate uses its own validated `mktemp -d` root. Every GREEN/final test uses a fresh result bundle that reports `Passed`, a nonzero executed-test count, and zero failed, skipped, or expected-failure tests. Build results must report zero errors, warnings, and analyzer warnings with Swift and Clang warnings treated as errors.
- A generic/ad-hoc macOS Release build and unsigned generic iOS Release build are compile/link and source/project-policy evidence only. The current macOS artifact is ad-hoc/runtime signed and has no TeamIdentifier, platform application identifier, or Keychain group; it cannot prove runtime Data Protection Keychain access.
- The separately signed-and-provisioned adopter gate is a mandatory release blocker. Never label it PASS from a simulator, unit test, command-line probe, unsigned build, or ad-hoc artifact.
- Preserve these completed-cycle SHA-256 values unless a task explicitly lists a file for modification:

```text
c0ba88dfcadf96053fca4230c653c8644a02007dc64b4dbf9a4f1a90414cca71  AppTemplate/App/Services/UserDefaults/IUserDefaultsService.swift
29088b164531fc713897f1f9e084a9414857ac5b403cd583d36da3ea0b4ce924  AppTemplate/App/Services/UserDefaults/UserDefaultsEncodedValue.swift
a7a9d2ddca4ac524ff5cba25b67accf758ffe072e88e642f068ec589a7f38cb4  AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift
bc49452767e49ff7349aaa68b23059e549f47fe7e9048054d177627d44d91479  AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift
c71220a1dc571bfb3d8cc3b20389c9611493e58e7faacd995ad19cbfb684717a  AppTemplate/App/Services/UserDefaults/UserDefaultsServiceError.swift
e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022  AppTemplate/App/ApplicationState/AppStateStore.swift
ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137  AppTemplate/App/ApplicationState/AppState.swift
f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043  AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift
30482218448299f2c2f0d7760454f78624f17d85f1cbfd03c35ea41d0703cbd4  AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift
56c1479cfdf852b90eab6a0cc4d9cecdfda5fcbb30e607de7be0daa58c3ab917  AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift
80e866dc0204649761eaf2a4d0b802edbce98c3b47661a9f2070f98b24292788  AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift
aed280f9ca12aecb9b720dd9e496a1d740d15f973a30f7cbebeeb3bdf6a0fce8  AppTemplate/App/Entry/AppTemplateApp.swift
dbe1ed75f049d7f96639661fb32aaea498ef84c782e33654ac80629f7071aa01  AppTemplate/App/PreviewSupport/PreviewFixtures.swift
bbd56931042546e0442fd1047896add039ad655f28f97de3bf885130c2c33dcb  AppTemplate.xcodeproj/project.pbxproj
```

## File Map

Create production files:

- `AppTemplate/App/Services/Keychain/IKeychainService.swift` — raw async protocol and shared String/Codable conveniences.
- `AppTemplate/App/Services/Keychain/KeychainKey.swift` — validated raw and versioned-Codable key identities.
- `AppTemplate/App/Services/Keychain/KeychainServiceError.swift` — fixed redacted public errors.
- `AppTemplate/App/Services/Keychain/KeychainService.swift` — cancellation, status mapping, and bounded set state machine.
- `AppTemplate/App/Services/Keychain/InMemoryKeychainService.swift` — fresh actor-owned preview/UI-test storage.
- `AppTemplate/App/Services/Keychain/Internal/KeychainSecItemExecuting.swift` — Sendable semantic executor protocol/result.
- `AppTemplate/App/Services/Keychain/Internal/KeychainSecurityAPI.swift` — checked-Sendable table containing the only four live Security calls.
- `AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift` — exact actor-local Security dictionaries and owned-result reduction.

Modify production:

- `AppTemplate/App/AppDependencies/AppDependencies.swift` — add app-graph Keychain ownership and live/in-memory/test injection only.

Create tests/support:

- `AppTemplateTests/App/Services/Keychain/KeychainKeyTests.swift`
- `AppTemplateTests/App/Services/Keychain/KeychainConvenienceTests.swift`
- `AppTemplateTests/App/Services/Keychain/KeychainServiceTests.swift`
- `AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift`
- `AppTemplateTests/App/Services/Keychain/InMemoryKeychainServiceTests.swift`
- `AppTemplateTests/App/Services/Keychain/Fixtures/KeychainCodableTypeMismatchCompileFixture.swift`
- `AppTemplateTests/TestSupport/Keychain/KeychainServiceSpy.swift`
- `AppTemplateTests/TestSupport/Keychain/KeychainTestModels.swift`
- `AppTemplateTests/TestSupport/Keychain/ScriptedKeychainSecItemExecutor.swift`
- Modify `AppTemplateTests/App/Composition/AppDependenciesTests.swift`.

Modify active documentation only:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CUSTOMIZATION.md`
- `docs/RELEASE_CHECKLIST.md`

---

### Task 1: Define Typed Keys, Public Errors, and Shared Codecs

**Files:**

- Create: `AppTemplate/App/Services/Keychain/KeychainKey.swift`
- Create: `AppTemplate/App/Services/Keychain/KeychainServiceError.swift`
- Create: `AppTemplate/App/Services/Keychain/IKeychainService.swift`
- Create: `AppTemplateTests/TestSupport/Keychain/KeychainServiceSpy.swift`
- Create: `AppTemplateTests/TestSupport/Keychain/KeychainTestModels.swift`
- Create: `AppTemplateTests/App/Services/Keychain/KeychainKeyTests.swift`
- Create: `AppTemplateTests/App/Services/Keychain/KeychainConvenienceTests.swift`
- Create: `AppTemplateTests/App/Services/Keychain/Fixtures/KeychainCodableTypeMismatchCompileFixture.swift`

**Interfaces:**

- Produces `KeychainKey`, `KeychainCodableKey<Value>`, `KeychainServiceError`, and the exact `IKeychainService` contract consumed by every later task.
- Produces a raw actor spy and unrelated Codable fixtures for codec/composition tests. No Security import or call belongs in this task.

- [ ] **Step 0: Prove the UserDefaults hard precondition before touching Keychain source**

```bash
set -euo pipefail
report='.superpowers/sdd/2026-08-12-userdefaults-service/final-verification-report.md'
test -f "$report"
rg -q '^Status: \*\*PASS' "$report"
for gate in 1 2 3 4 5 6 7 8 9; do
  rg -q "^\\|[[:space:]]*$gate([^|]*)\\|[[:space:]]*PASS[[:space:]]*\\|" "$report"
done
expected_history="$({
  printf '%s\n' 96205b098e9084db96745b3d7259ab6c4275903b
  printf '%s\n' a83574042cd38ee6a53eb2f74bc7f59e2196e7ac
})"
actual_history="$(git log --reverse --format=%H -- \
  docs/superpowers/specs/2026-08-12-keychain-service-design.md)"
test "$actual_history" = "$expected_history"
test -z "$(git status --porcelain)"
```

Expected before the UserDefaults rerun: the `rg '^Status: **PASS'` assertion fails. Stop without creating any Keychain implementation/test file. Expected after the valid rerun: all assertions pass and implementation may begin.

- [ ] **Step 1: Write the typed-key and codec RED**

Create these test-support fixtures. Put the value fixtures and the internal
`assertRedacted` helper in `KeychainTestModels.swift`; put only the actor spy in
`KeychainServiceSpy.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

nonisolated struct FirstSecret: Codable, Equatable, Sendable { let value: Int }
nonisolated struct SecondSecret: Codable, Equatable, Sendable { let text: String }
nonisolated struct UnicodeSecret: Codable, Equatable, Sendable {
    let title: String
    let enabled: Bool
}

nonisolated struct SentinelCodecError:
    Error,
    LocalizedError,
    CustomStringConvertible,
    Sendable
{
    let description: String
    var errorDescription: String? { description }
}

nonisolated struct FailingEncodeSecret: Codable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {
        throw SentinelCodecError(
            description: "SECRET-DECODE-PAYLOAD at codingPath.session.token"
        )
    }
    func encode(to encoder: any Encoder) throws {
        throw SentinelCodecError(
            description: "SECRET-ENCODE-PAYLOAD at codingPath.session.token"
        )
    }
}

nonisolated struct FailingDecodeSecret: Codable, Sendable {
    init(from decoder: any Decoder) throws {
        throw SentinelCodecError(
            description: "SECRET-DECODE-PAYLOAD at codingPath.session.token"
        )
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(0)
    }
}

nonisolated struct CancellingCodecSecret: Codable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws { throw CancellationError() }
    func encode(to encoder: any Encoder) throws { throw CancellationError() }
}

nonisolated func assertRedacted(
    _ error: any Error,
    expected: KeychainServiceError,
    forbidden: [String]
) {
    #expect(error as? KeychainServiceError == expected)
    let rendered = [
        String(describing: error),
        String(reflecting: error),
        (error as NSError).localizedDescription
    ]
    for sentinel in forbidden {
        #expect(rendered.allSatisfy { !$0.contains(sentinel) })
    }
}
```

Create `KeychainServiceSpy.swift` separately with its own imports:

```swift
import Foundation
@testable import AppTemplate

actor KeychainServiceSpy: IKeychainService {
    private var storage: [KeychainKey: Data]
    private(set) var reads: [KeychainKey] = []
    private(set) var writes: [(KeychainKey, Data)] = []
    private(set) var removals: [KeychainKey] = []
    private let beforeRead: @Sendable () throws -> Void
    private let beforeWrite: @Sendable () throws -> Void

    init(
        storage: [KeychainKey: Data] = [:],
        beforeRead: @escaping @Sendable () throws -> Void = {},
        beforeWrite: @escaping @Sendable () throws -> Void = {}
    ) {
        self.storage = storage
        self.beforeRead = beforeRead
        self.beforeWrite = beforeWrite
    }

    func data(for key: KeychainKey) async throws -> Data? {
        reads.append(key)
        try beforeRead()
        return storage[key]
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        writes.append((key, data))
        try beforeWrite()
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        removals.append(key)
        return storage.removeValue(forKey: key) != nil
    }

    func storedData(for key: KeychainKey) -> Data? { storage[key] }
    func callCounts() -> (reads: Int, writes: Int, removals: Int) {
        (reads.count, writes.count, removals.count)
    }
}
```

Create `KeychainKeyTests` with these exact test names and assertions:

```swift
import Testing
@testable import AppTemplate

struct KeychainKeyTests {
    @Test func factoriesWorkFromNonisolatedContextAndPreserveExactSpelling() {
        constructKeychainKeysFromNonisolatedContext()
        #expect(KeychainKey.data("  Session Token  ").account == "  Session Token  ")
        let key: KeychainCodableKey<FirstSecret> =
            .codable("Session", schemaVersion: 12)
        #expect(key.account == "Session.schema-12")
    }

    @Test func schemaVersionsProduceDifferentPhysicalAccounts() {
        let first: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 1)
        let second: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 2)
        #expect(first.account == "Session.schema-1")
        #expect(second.account == "Session.schema-2")
        #expect(first.account != second.account)
    }

    @Test func everyValidationBranchBindsItsExactFixedDiagnostic() {
        #expect(KeychainComponent.keyFailure(" \n\t ") == .blankKey)
        #expect(KeychainValidationFailure.blankKey.rawValue ==
            "Keychain key must not be blank.")
        #expect(KeychainComponent.keyFailure("Bad\0Name") == .nulKey)
        #expect(KeychainValidationFailure.nulKey.rawValue ==
            "Keychain key must not contain NUL.")
        #expect(KeychainComponent.keyFailure("Bad.schema-Name") == .reservedSchemaMarker)
        #expect(KeychainValidationFailure.reservedSchemaMarker.rawValue ==
            "Keychain key must not contain '.schema-'.")
        #expect(KeychainComponent.schemaFailure(0) == .nonpositiveSchemaVersion)
        #expect(KeychainValidationFailure.nonpositiveSchemaVersion.rawValue ==
            "Keychain schema version must be greater than zero.")
        #expect(KeychainComponent.serviceFailure(" \n\t ") == .blankService)
        #expect(KeychainValidationFailure.blankService.rawValue ==
            "Keychain service must not be blank.")
        #expect(KeychainComponent.serviceFailure("Bad\0Service") == .nulService)
        #expect(KeychainValidationFailure.nulService.rawValue ==
            "Keychain service must not contain NUL.")
        #expect(KeychainComponent.keyFailure("  Exact Name  ") == nil)
        #expect(KeychainComponent.serviceFailure("  Exact Service  ") == nil)
        #expect(KeychainComponent.schemaFailure(1) == nil)
    }

    #if os(macOS)
    @Test func blankLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data(" \n\t ")
        }
    }

    @Test func nulLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data("Bad\0Name")
        }
    }

    @Test func reservedSchemaMarkerLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainKey.data("Bad.schema-Name")
        }
    }

    @Test func zeroSchemaVersionTerminates() async {
        await #expect(processExitsWith: .failure) {
            let _: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 0)
        }
    }
    #endif
}

nonisolated private func constructKeychainKeysFromNonisolatedContext() {
    _ = KeychainKey.data("Raw")
    let _: KeychainCodableKey<FirstSecret> = .codable("Model", schemaVersion: 1)
}
```

The pinned Apple Swift 6.3.3 compiler crashes in `SendNonSendable` when a
parameterized Swift Testing argument is captured by a `processExitsWith` closure;
the same crash occurs for both `String` and a `Sendable` enum argument. Keep the
three logical-name exit tests as separate, fixed-literal, nonparameterized
no-capture tests. Do not consolidate them into an argument-driven helper or test.

Create `KeychainConvenienceTests` with these exact tests:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct KeychainConvenienceTests {
    @Test func dataPassesThroughWithoutTransformation() async throws {
        let service = KeychainServiceSpy()
        let key = KeychainKey.data("Bytes")
        let bytes = Data([0x00, 0xFF, 0x41])
        try await service.set(bytes, for: key)
        #expect(try await service.data(for: key) == bytes)
    }

    @Test func unicodeStringRoundTripsAndEmptyStringIsPresent() async throws {
        let service = KeychainServiceSpy()
        let unicode = KeychainKey.data("Unicode")
        let empty = KeychainKey.data("Empty")
        try await service.set("Привет 🌍", for: unicode)
        try await service.set("", for: empty)
        #expect(try await service.string(for: unicode) == "Привет 🌍")
        #expect(try await service.string(for: empty) == "")
    }

    @Test func invalidUTF8ThrowsWithoutChangingStoredBytes() async throws {
        let key = KeychainKey.data("Invalid UTF8")
        let bytes = Data([0xC3, 0x28])
        let service = KeychainServiceSpy(storage: [key: bytes])
        await #expect(throws: KeychainServiceError.invalidUTF8) {
            _ = try await service.string(for: key)
        }
        #expect(await service.storedData(for: key) == bytes)
    }

    @Test func codableModelsRoundTripAndSchemaVersionsCoexist() async throws {
        let service = KeychainServiceSpy()
        let first: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 1)
        let second: KeychainCodableKey<UnicodeSecret> = .codable("Session", schemaVersion: 2)
        try await service.set(FirstSecret(value: 7), for: first)
        try await service.set(UnicodeSecret(title: "Кыргызча", enabled: true), for: second)
        #expect(try await service.value(for: first) == FirstSecret(value: 7))
        #expect(try await service.value(for: second) == UnicodeSecret(title: "Кыргызча", enabled: true))
    }

    @Test func encodingFailureMakesNoRawServiceCall() async {
        let service = KeychainServiceSpy()
        let key: KeychainCodableKey<FailingEncodeSecret> = .codable("Failure", schemaVersion: 1)
        await #expect(throws: KeychainServiceError.encodingFailed) {
            try await service.set(FailingEncodeSecret(), for: key)
        }
        let counts = await service.callCounts()
        #expect(counts.reads == 0 && counts.writes == 0 && counts.removals == 0)
    }

    @Test func decodingFailureLeavesStoredBytesUntouched() async throws {
        let key: KeychainCodableKey<FirstSecret> = .codable("Decode", schemaVersion: 1)
        let raw = KeychainKey(validatedPhysicalAccount: key.account)
        let bytes = Data("not-json".utf8)
        let service = KeychainServiceSpy(storage: [raw: bytes])
        await #expect(throws: KeychainServiceError.decodingFailed) {
            _ = try await service.value(for: key)
        }
        #expect(await service.storedData(for: raw) == bytes)
    }

    @Test func codecCancellationRemainsCancellationError() async {
        let setService = KeychainServiceSpy()
        let key: KeychainCodableKey<CancellingCodecSecret> = .codable("Cancel", schemaVersion: 1)
        await #expect(throws: CancellationError.self) {
            try await setService.set(CancellingCodecSecret(), for: key)
        }

        let raw = KeychainKey(validatedPhysicalAccount: key.account)
        let readService = KeychainServiceSpy(storage: [raw: Data("{}".utf8)])
        await #expect(throws: CancellationError.self) {
            _ = try await readService.value(for: key)
        }
    }

    @Test func preCancelledConveniencesRespectEveryCodecBoundary() async {
        let stringKey = KeychainKey.data("String")
        let codableKey: KeychainCodableKey<FirstSecret> =
            .codable("Codable", schemaVersion: 1)

        let writeService = KeychainServiceSpy()
        let stringWrite = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await writeService.set("value", for: stringKey)
        }
        await #expect(throws: CancellationError.self) { try await stringWrite.value }
        let codableWrite = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await writeService.set(FirstSecret(value: 1), for: codableKey)
        }
        await #expect(throws: CancellationError.self) { try await codableWrite.value }
        #expect(await writeService.callCounts().writes == 0)

        let rawCodable = KeychainKey(validatedPhysicalAccount: codableKey.account)
        let readService = KeychainServiceSpy(storage: [
            stringKey: Data([0xC3, 0x28]),
            rawCodable: Data("not-json".utf8)
        ])
        let stringRead = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await readService.string(for: stringKey)
        }
        await #expect(throws: CancellationError.self) { try await stringRead.value }
        let codableRead = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await readService.value(for: codableKey)
        }
        await #expect(throws: CancellationError.self) { try await codableRead.value }
        #expect(await readService.callCounts().reads == 2)
    }

    @Test func successfulConvenienceWriteIsNotPostCheckedForCancellation() async throws {
        let service = KeychainServiceSpy(beforeWrite: {
            withUnsafeCurrentTask { $0?.cancel() }
        })
        let stringKey = KeychainKey.data("String")
        let codableKey: KeychainCodableKey<FirstSecret> =
            .codable("Codable", schemaVersion: 1)
        try await Task { try await service.set("value", for: stringKey) }.value
        try await Task {
            try await service.set(FirstSecret(value: 1), for: codableKey)
        }.value
        #expect(await service.callCounts().writes == 2)
    }

    @Test func codableRemoveUsesDerivedRawAccountAndBoolSemantics() async throws {
        let service = KeychainServiceSpy()
        let key: KeychainCodableKey<FirstSecret> = .codable("Session", schemaVersion: 3)
        try await service.set(FirstSecret(value: 1), for: key)
        #expect(try await service.remove(key))
        #expect(!(try await service.remove(key)))
    }

    @Test func realCodecFailuresAreRedactedAtThePublicBoundary() async {
        let encodeService = KeychainServiceSpy()
        let encodeKey: KeychainCodableKey<FailingEncodeSecret> =
            .codable("Encode", schemaVersion: 1)
        do {
            try await encodeService.set(FailingEncodeSecret(), for: encodeKey)
            Issue.record("Expected KeychainServiceError.encodingFailed")
        } catch {
            assertRedacted(
                error,
                expected: .encodingFailed,
                forbidden: ["SECRET-ENCODE-PAYLOAD", "codingPath.session.token"]
            )
        }

        let decodeKey: KeychainCodableKey<FailingDecodeSecret> =
            .codable("Decode", schemaVersion: 1)
        let raw = KeychainKey(validatedPhysicalAccount: decodeKey.account)
        let decodeService = KeychainServiceSpy(storage: [raw: Data("0".utf8)])
        do {
            _ = try await decodeService.value(for: decodeKey)
            Issue.record("Expected KeychainServiceError.decodingFailed")
        } catch {
            assertRedacted(
                error,
                expected: .decodingFailed,
                forbidden: ["SECRET-DECODE-PAYLOAD", "codingPath.session.token"]
            )
        }
    }
}
```

Do not add a public initializer to make the decoding test compile. Use the same internal initializer that the Codable extension needs to address its derived physical account:

```swift
// Internal, never public. The public factory validates logical names.
init(validatedPhysicalAccount account: String) { self.account = account }
```

Create the compile-negative fixture:

```swift
#if KEYCHAIN_CODABLE_TYPE_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

nonisolated func keychainCodableTypeMismatch(
    service: any IKeychainService,
    key: KeychainCodableKey<FirstSecret>
) async throws {
    let _: SecondSecret? = try await service.value(for: key)
}
#endif
```

Expected RED: the focused build fails because the Keychain types and protocol do not exist.

- [ ] **Step 2: Run and retain RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task1-RED.XXXXXX)"
test -d "$red_root"; test ! -L "$red_root"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainKeyTests \
  -only-testing:AppTemplateTests/KeychainConvenienceTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n 'cannot find.*Keychain(Key|Service|ServiceError)|cannot find.*IKeychainService' \
  "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement the minimum typed contract**

Use these exact public declarations:

```swift
import Foundation
import Security

nonisolated struct KeychainKey: Hashable, Sendable {
    let account: String

    private init(logicalName: String) {
        KeychainComponent.validateKey(logicalName)
        account = logicalName
    }

    init(validatedPhysicalAccount account: String) { self.account = account }

    static func data(_ name: String) -> Self { Self(logicalName: name) }
}

nonisolated struct KeychainCodableKey<Value: Codable & Sendable>: Sendable {
    let account: String

    static func codable(_ name: String, schemaVersion: UInt) -> Self {
        KeychainComponent.validateKey(name)
        KeychainComponent.validateSchema(schemaVersion)
        return Self(account: "\(name).schema-\(schemaVersion)")
    }

    var rawKey: KeychainKey { KeychainKey(validatedPhysicalAccount: account) }
}

nonisolated enum KeychainValidationFailure: String, Equatable, Sendable {
    case blankKey = "Keychain key must not be blank."
    case nulKey = "Keychain key must not contain NUL."
    case reservedSchemaMarker = "Keychain key must not contain '.schema-'."
    case nonpositiveSchemaVersion =
        "Keychain schema version must be greater than zero."
    case blankService = "Keychain service must not be blank."
    case nulService = "Keychain service must not contain NUL."
}

nonisolated enum KeychainComponent {
    static func keyFailure(_ name: String) -> KeychainValidationFailure? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blankKey
        }
        if name.contains("\0") { return .nulKey }
        if name.contains(".schema-") { return .reservedSchemaMarker }
        return nil
    }

    static func schemaFailure(_ version: UInt) -> KeychainValidationFailure? {
        version > 0 ? nil : .nonpositiveSchemaVersion
    }

    static func serviceFailure(_ service: String) -> KeychainValidationFailure? {
        if service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blankService
        }
        if service.contains("\0") { return .nulService }
        return nil
    }

    static func validateKey(_ name: String) {
        let failure = keyFailure(name)
        precondition(failure == nil, failure!.rawValue)
    }

    static func validateSchema(_ version: UInt) {
        let failure = schemaFailure(version)
        precondition(failure == nil, failure!.rawValue)
    }

    static func validateService(_ service: String) {
        let failure = serviceFailure(service)
        precondition(failure == nil, failure!.rawValue)
    }
}
```

`KeychainServiceError` is exactly:

```swift
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
```

`IKeychainService.swift` contains the exact raw contract and conveniences:

```swift
import Foundation

nonisolated protocol IKeychainService: Sendable {
    func data(for key: KeychainKey) async throws -> Data?
    func set(_ data: Data, for key: KeychainKey) async throws
    @discardableResult func remove(_ key: KeychainKey) async throws -> Bool
}

nonisolated extension IKeychainService {
    func string(for key: KeychainKey) async throws -> String? {
        guard let data = try await data(for: key) else { return nil }
        try Task.checkCancellation()
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainServiceError.invalidUTF8
        }
        return value
    }

    func set(_ string: String, for key: KeychainKey) async throws {
        try Task.checkCancellation()
        try await set(Data(string.utf8), for: key)
    }

    func value<Value: Codable & Sendable>(
        for key: KeychainCodableKey<Value>
    ) async throws -> Value? {
        guard let data = try await data(for: key.rawKey) else { return nil }
        try Task.checkCancellation()
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.decodingFailed
        }
    }

    func set<Value: Codable & Sendable>(
        _ value: Value,
        for key: KeychainCodableKey<Value>
    ) async throws {
        try Task.checkCancellation()
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw KeychainServiceError.encodingFailed
        }
        try await set(data, for: key.rawKey)
    }

    @discardableResult
    func remove<Value: Codable & Sendable>(
        _ key: KeychainCodableKey<Value>
    ) async throws -> Bool {
        try await remove(key.rawKey)
    }
}
```

Keep every diagnostic fixed and noninterpolating. The derived account interpolation is identity construction, not a diagnostic.

- [ ] **Step 4: Run GREEN and compiler-negative proof**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task1-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainKeyTests \
  -only-testing:AppTemplateTests/KeychainConvenienceTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
tests_json="$green_root/tests.json"
xcrun xcresulttool get test-results tests --path "$green_root/Tests.xcresult" --compact >"$tests_json"
jq -e '
  def descendants: recurse(.children[]?);
  [.testNodes[] | descendants
    | select(.nodeType == "Test Suite" and .name == "KeychainKeyTests" and .result == "Passed")
    | ([. | descendants | select(.nodeType == "Test Case" and .result == "Passed")] | length)]
  | length == 1 and .[0] == 7
' "$tests_json"

compile_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task1-CompileNegative.XXXXXX)"
set +e
xcodebuild build-for-testing -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) KEYCHAIN_CODABLE_TYPE_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n "cannot (convert|assign).*FirstSecret.*(to|as).*SecondSecret" \
  "$compile_root/build.log"
```

- [ ] **Step 5: Perform Task 1 mutation probes and restore**

1. Change Codable `set` to call raw `set` from its encode-error catch. Rerun `encodingFailureMakesNoRawServiceCall`; require failure, restore, rerun GREEN.
2. Change derived account to `"\(name).v\(schemaVersion)"`. Rerun `schemaVersionsProduceDifferentPhysicalAccounts` and `codableModelsRoundTripAndSchemaVersionsCoexist`; require at least the exact-account test to fail, restore.
3. Convert a codec-thrown `CancellationError` into `.encodingFailed`/`.decodingFailed`. Rerun `codecCancellationRemainsCancellationError`; require failure, restore.
4. Change the non-cancellation codec catch from the fixed public error to `throw error`. Rerun `realCodecFailuresAreRedactedAtThePublicBoundary`; require the sentinel payload/coding-path assertion to fail, then restore.
5. First remove the NUL predicate from `keyFailure(_:)`. Rerun `nulLogicalNameTerminates`, `blankLogicalNameTerminates`, `reservedSchemaMarkerLogicalNameTerminates`, and `everyValidationBranchBindsItsExactFixedDiagnostic`; require only `nulLogicalNameTerminates` to fail its exit assertion with child `exitCode(0)`, require `everyValidationBranchBindsItsExactFixedDiagnostic` to fail, and require the blank and reserved-marker exit tests to pass. Restore. Then swap the `.blankKey` and `.nulKey` returns in `keyFailure(_:)`; rerun `everyValidationBranchBindsItsExactFixedDiagnostic` and require failure, then restore. This proves the tests bind each validation branch to its literal rather than merely finding all six strings somewhere in source.
6. Temporarily change the compile fixture assignment to `FirstSecret?`; require the negative build to succeed. Restore `SecondSecret?`, rerun the negative proof, and require the mismatch diagnostic.
7. Replace either inline fresh JSON codec with a cached/shared `JSONEncoder` or
   `JSONDecoder`. The exact fresh-codec source oracle below must fail even though
   Foundation may still create distinct internal `Encoder`/`Decoder` containers;
   restore before GREEN. This is the discriminating proof for the spec's
   no-cached-codec rule.
8. Remove a convenience pre-codec/pre-decode cancellation checkpoint; the corresponding branch of `preCancelledConveniencesRespectEveryCodecBoundary` must encode/decode or make a forbidden raw write. Add a post-success cancellation checkpoint after the raw set; `successfulConvenienceWriteIsNotPostCheckedForCancellation` must fail. Restore both mutations.
9. Run this exact source/function oracle for all six diagnostics and both fresh
   JSON codecs before committing:

```bash
set -euo pipefail
for literal in \
  'Keychain key must not be blank.' \
  'Keychain key must not contain NUL.' \
  "Keychain key must not contain '.schema-'." \
  'Keychain schema version must be greater than zero.' \
  'Keychain service must not be blank.' \
  'Keychain service must not contain NUL.'; do
  test "$(rg -F -- "$literal" AppTemplate/App/Services/Keychain | wc -l | tr -d ' ')" = 1
done
test "$(rg -F 'precondition(failure == nil, failure!.rawValue)' \
  AppTemplate/App/Services/Keychain/KeychainKey.swift | wc -l | tr -d ' ')" = 3
test -z "$(rg -n 'precondition(Failure)?\([^,]+,[[:space:]]*"' \
  AppTemplate/App/Services/Keychain)"
test "$(rg -o 'JSONEncoder\(\)\.encode\(value\)' \
  AppTemplate/App/Services/Keychain/IKeychainService.swift | wc -l | tr -d ' ')" = 1
test "$(rg -o 'JSONDecoder\(\)\.decode\(Value\.self, from: data\)' \
  AppTemplate/App/Services/Keychain/IKeychainService.swift | wc -l | tr -d ' ')" = 1
test -z "$(rg -n 'static (let|var) .*JSON(Encoder|Decoder)|private (let|var) .*JSON(Encoder|Decoder)' \
  AppTemplate/App/Services/Keychain)"
```

- [ ] **Step 6: Commit Task 1**

```bash
git add AppTemplate/App/Services/Keychain/IKeychainService.swift \
  AppTemplate/App/Services/Keychain/KeychainKey.swift \
  AppTemplate/App/Services/Keychain/KeychainServiceError.swift \
  AppTemplateTests/App/Services/Keychain/KeychainKeyTests.swift \
  AppTemplateTests/App/Services/Keychain/KeychainConvenienceTests.swift \
  AppTemplateTests/App/Services/Keychain/Fixtures/KeychainCodableTypeMismatchCompileFixture.swift \
  AppTemplateTests/TestSupport/Keychain/KeychainServiceSpy.swift \
  AppTemplateTests/TestSupport/Keychain/KeychainTestModels.swift
git diff --cached --check
git commit -m "feat: add typed Keychain contract"
test -z "$(git status --porcelain)"
```

---

### Task 2: Build the Checked-Sendable Security Executor

**Files:**

- Create: `AppTemplate/App/Services/Keychain/Internal/KeychainSecItemExecuting.swift`
- Create: `AppTemplate/App/Services/Keychain/Internal/KeychainSecurityAPI.swift`
- Create: `AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift`
- Create: `AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift`

**Interfaces:**

- Consumes fixed `service`, physical `account`, and proposed `Data` only.
- Produces `KeychainSecItemExecuting`, `KeychainSecItemCopyResult`, the injectable four-closure Security table, and a live executor actor. Task 3 owns public status semantics and retries.

- [ ] **Step 1: Write the executor-query RED**

Create `SecurityKeychainSecItemExecutorTests` with these exact tests:

```swift
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
        // The task has begun and reached the occupied executor hop. The first
        // closure still blocks executor isolation, so the update closure cannot
        // have run before cancellation.
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
```

Swift 6.3.3 diagnoses `group.reduce(into:)` here because its concurrent
reducing closure sends the inout accumulator and TaskGroup across concurrency
domains. Collecting through the task-group scope's serial `for await` loop
preserves the same 200 completion statuses and their order of delivery without
the sending/inout higher-order reduction.

Add this complete synchronized test seam in the same file. Every fake closure normalizes its `CFDictionary` arguments into owned Sendable snapshots before locking or returning. A missing, foreign, or extra key records a normalization failure and returns `errSecParam`; it is never silently ignored.

```swift
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
```

The `RawDictionary` and normalization helpers are synchronous closure-local values only. `SecurityCallRecorder.State` contains only owned Sendable snapshots; it never stores `NSDictionary`, `CFDictionary`, `CFTypeRef`, a pointer, or `Any`. `MutableCFDataSource` is the sole test-only unchecked Sendable fixture: the fake synchronously lends the retained object, the executor copies it before any await, and mutation is permitted only after awaited copy completion; its own handoff/mutation methods share one private `Mutex`. The warnings-as-errors Xcode GREEN build is the required compile-emission proof under the project flags. Every exact-call test additionally requires `recorder.failures().isEmpty`; `onlyCall()` already returns `nil` if normalization failed.

Expected RED: `KeychainSecurityAPI`, executor/result/protocol, and query snapshot inputs do not exist.

- [ ] **Step 2: Run and retain RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task2-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SecurityKeychainSecItemExecutorTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n 'cannot find.*SecurityKeychainSecItemExecutor|cannot find.*KeychainSecurityAPI' \
  "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement the semantic executor protocol and checked-Sendable table**

```swift
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
```

```swift
import CoreFoundation
import Security

nonisolated struct KeychainSecurityAPI: Sendable {
    typealias CopyMatching = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    typealias Update = @Sendable (CFDictionary, CFDictionary) -> OSStatus
    typealias Add = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    typealias Delete = @Sendable (CFDictionary) -> OSStatus

    let copyMatching: CopyMatching
    let update: Update
    let add: Add
    let delete: Delete

    static let live = Self(
        copyMatching: { SecItemCopyMatching($0, $1) },
        update: { SecItemUpdate($0, $1) },
        add: { SecItemAdd($0, $1) },
        delete: { SecItemDelete($0) }
    )
}
```

- [ ] **Step 4: Implement exact actor-local queries and owned copy reduction**

```swift
import CoreFoundation
import Foundation
import Security

actor SecurityKeychainSecItemExecutor: KeychainSecItemExecuting {
    private let security: KeychainSecurityAPI

    init(security: KeychainSecurityAPI = .live) { self.security = security }

    func copy(service: String, account: String) async throws -> KeychainSecItemCopyResult {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = requiredCFBoolean(true)
        query[kSecMatchLimit] = kSecMatchLimitOne
        var object: CFTypeRef?
        try Task.checkCancellation()
        let status = security.copyMatching(query as CFDictionary, &object)
        guard status == errSecSuccess else { return .status(status) }
        guard let object, CFGetTypeID(object) == CFDataGetTypeID() else { return .invalid }
        let source = unsafeDowncast(object, to: CFData.self)
        let count = CFDataGetLength(source)
        guard count > 0 else { return .data(Data()) }
        guard let bytes = CFDataGetBytePtr(source) else { return .invalid }
        return .data(Data(bytes: bytes, count: count))
    }

    func update(service: String, account: String, data: Data) async throws -> OSStatus {
        let query = baseQuery(service: service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        try Task.checkCancellation()
        return security.update(query as CFDictionary, attributes as CFDictionary)
    }

    func add(service: String, account: String, data: Data) async throws -> OSStatus {
        var attributes = baseQuery(service: service, account: account)
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        try Task.checkCancellation()
        return security.add(attributes as CFDictionary, nil)
    }

    func delete(service: String, account: String) async throws -> OSStatus {
        let query = baseQuery(service: service, account: account)
        try Task.checkCancellation()
        return security.delete(query as CFDictionary)
    }

    private func baseQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: requiredCFBoolean(false),
            kSecUseDataProtectionKeychain: requiredCFBoolean(true)
        ]
    }
}

nonisolated private func requiredCFBoolean(_ value: Bool) -> CFBoolean {
    value ? kCFBooleanTrue! : kCFBooleanFalse!
}
```

There is no `await` after a dictionary is built and before its closure call. The actor retains only `KeychainSecurityAPI`, never a query/result object.

- [ ] **Step 5: Run GREEN, mutation probes, and source boundary checks**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task2-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/SecurityKeychainSecItemExecutorTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'

live_security_file='AppTemplate/App/Services/Keychain/Internal/KeychainSecurityAPI.swift'
test "$(rg -l '\bSecItem(CopyMatching|Update|Add|Delete)\s*\(' \
  AppTemplate --glob '*.swift')" = "$live_security_file"
test -z "$(rg -n '\bSecItem(CopyMatching|Update|Add|Delete)\s*\(' \
  AppTemplateTests AppTemplateUITests --glob '*.swift')"
test -z "$(rg -n '@unchecked Sendable|unsafeBitCast' AppTemplate/App/Services/Keychain)"
test "$(rg -n '@unchecked Sendable' \
  AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift \
  | wc -l | tr -d ' ')" = 1
rg -q '^nonisolated final class MutableCFDataSource: @unchecked Sendable {' \
  AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift
rg -q 'unsafeDowncast' AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift
rg -q 'Data(bytes: bytes, count: count)' \
  AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift
test -z "$(rg -n 'Data\(referencing:|bytesNoCopy' \
  AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift)"
rg -q 'security\.add(attributes as CFDictionary, nil)' \
  AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift
rg -q 'value \? kCFBooleanTrue! : kCFBooleanFalse!' \
  AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift
rg -q '^nonisolated private func requiredCFBoolean(_ value: Bool) -> CFBoolean {' \
  AppTemplate/App/Services/Keychain/Internal/SecurityKeychainSecItemExecutor.swift
```

Perform and restore these mutations, using a fresh bundle for every expected failure:

1. Set `kSecAttrSynchronizable` to `requiredCFBoolean(true)`; `copyUsesPhysicalCFBooleans` and exact-query tests must fail.
2. Remove `kSecUseDataProtectionKeychain` from `baseQuery`; all four exact-query tests must fail.
3. Add `kSecAttrAccessGroup` or an extra label to one fake production query; the corresponding exact-key-set test must fail.
4. Change the production add call's result argument from `nil` to a pointer. The add recorder's `result == nil` guard and exact source oracle must fail before accepting the mutation.
5. Remove `Task.checkCancellation()` from each of copy, update, add, and delete one at a time; the corresponding argument of `preCancelledExecutorMethodsInvokeNoSecurityClosure` must fail.
6. Remove the executor-entry cancellation check from update, then run `cancellationWhileExecutorIsOccupiedPreventsQueuedSecurityClosure`; the queued update must reach the fake Security closure and fail the exact `[.copy]` assertion. Restore immediately.
7. Replace the returned update, add, or delete closure status with `errSecSuccess` one at a time; `mutationMethodsReturnExactNonSuccessSecurityStatus` must fail for that operation.
8. Remove `Sendable` from `KeychainSecurityAPI` or `@Sendable` from one stored closure alias; `closureTableIsCheckedSendableAndRecorderHandlesConcurrentDirectCalls` must fail to compile at `requireSendable` or the checked conformance. Restore immediately.
9. Return `Data(referencing:)`/`Data(bytesNoCopy:)` or otherwise remove the exact `Data(bytes: bytes, count: count)` owned-copy constructor. The owned-copy source oracle must fail deterministically; for a no-copy mutation, the behavioral source-mutation assertion must fail as well.
10. Replace `unsafeDowncast` with `unsafeBitCast`; the source boundary check must fail even if tests happen to pass. Restore and rerun the complete GREEN command.

- [ ] **Step 6: Commit Task 2**

```bash
git add AppTemplate/App/Services/Keychain/Internal \
  AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift
git diff --cached --check
git commit -m "feat: add Data Protection Keychain executor"
test -z "$(git status --porcelain)"
```

---

### Task 3: Implement Public Status Semantics and the Bounded Set State Machine

**Files:**

- Create: `AppTemplate/App/Services/Keychain/KeychainService.swift`
- Create: `AppTemplateTests/TestSupport/Keychain/ScriptedKeychainSecItemExecutor.swift`
- Create: `AppTemplateTests/App/Services/Keychain/KeychainServiceTests.swift`

**Interfaces:**

- Consumes `KeychainSecItemExecuting`, `KeychainSecItemCopyResult`, raw keys, and public errors.
- Produces the concrete `KeychainService` actor used by live composition. It maps status/cancellation and performs only the four-call bounded state machine; it never builds a Security dictionary.

- [ ] **Step 1: Create the deterministic semantic executor and service RED**

Create test support with this exact semantic surface:

```swift
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
```

The implementation may factor the `status(from:)` await syntax to compile cleanly, but it must preserve the exact serialized response and barrier semantics above.

Create `KeychainServiceTests` with these exact test names and coverage:

```swift
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

    #if os(macOS)
    @Test(arguments: [" \n\t ", "Bad\0Service"])
    func invalidServiceNamespacesTerminate(_ namespace: String) async {
        await #expect(processExitsWith: .failure) {
            _ = KeychainService(service: namespace, executor: ScriptedKeychainSecItemExecutor([]))
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
```

Define one test-local `terminalStatusCases` constant containing all 22 terminal pairs from `everyTerminalSecurityStatusMapsExactly` (the 21 named mapped statuses plus `(-7777, .unexpectedStatus(-7777))`). Reuse that exact constant for read, remove, and each of the four reachable set positions; do not maintain shorter duplicate lists. Keep `expectedSetOperations(count:data:)` as the single exact service/account/data/order oracle for every set path; there is no default branch.

Add a test-only actor executor owning `[String: Data]` plus recorded
`[ScriptedKeychainOperation]`. Its update changes existing data or returns
`errSecItemNotFound`; its add inserts absent data or returns
`errSecDuplicateItem`; copy/delete are unused failures. Add two concurrent tests:

- `manyDistinctKeysCompleteWithExactPerKeySequences()` submits 100 unique accounts and unique payloads. Require all calls to succeed, every account to store its submitted bytes, every account's recorded sequence to equal exactly `[update, add]` with its exact service/account/data, and total calls to equal 200.
- `manyWritersForOneKeyCompleteWithValidPerPayloadSequences()` submits 100 unique payloads for one account. Require every call to succeed, group recorded operations by exact payload, and require every group to equal one of `expectedSetOperations(count: 1...4, data: payload)`, preserving `AppTemplate`, the shared account, and that payload. Require total calls in `100...400` and final stored bytes to equal one submitted payload.

Mutation probe: inject one extra, reordered, wrong-account, or wrong-data
operation while keeping the aggregate count inside `100...400`; the exact
per-key/per-payload sequence test must fail. Restore before GREEN.

Expected RED: `KeychainService` does not exist.

- [ ] **Step 2: Run and retain RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task3-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainServiceTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n 'cannot find.*KeychainService' "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement the exact actor and status map**

```swift
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
        } catch let error as CancellationError { throw error }
        catch { throw KeychainServiceError.internalFailure }
    }

    private func add(_ data: Data, _ key: KeychainKey) async throws -> OSStatus {
        do {
            try Task.checkCancellation()
            return try await executor.add(service: service, account: key.account, data: data)
        } catch let error as CancellationError { throw error }
        catch { throw KeychainServiceError.internalFailure }
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
```

`errSecSuccess`, `errSecItemNotFound`, and `errSecDuplicateItem` reach the default `.unexpectedStatus(status)` when an operation-specific caller did not consume them. The function carries only `OSStatus` and never calls `SecCopyErrorMessageString`.

- [ ] **Step 4: Run GREEN and mutation probes**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task3-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainServiceTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

Perform and restore these mutations with a fresh expected-RED root each time:

1. Replace the second-add duplicate branch with another retry; `secondAddDuplicateThrowsConcurrentMutationAfterFourCalls` must fail or exceed four calls.
2. Remove the cancellation check in the private second-update path by temporarily splitting it into a no-check helper; the `completedCallCount == 2` case must fail its exact `[.update, .add]` prefix by recording call 3.
3. Add `Task.checkCancellation()` after a successful update/add/delete; `cancellationDuringSuccessfulMutationOrDeleteIsNotPostChecked` must fail.
4. Map `errSecUserCanceled` to `CancellationError` or `.authenticationFailed`; `everyTerminalSecurityStatusMapsExactly` must fail.
5. Map injected Swift errors by rethrowing them in each raw operation; `injectedReadFailureMapsToRedactedInternalFailureWithoutExtraCall`, `injectedExecutorFailureMapsToRedactedInternalFailureAtEverySetCall`, and `removeMapsEveryTerminalStatusAndInjectedFailureWithoutExtraCall` must fail on the real sentinel localized description.
6. Treat duplicate as valid for read/remove, duplicate as valid for update, or item-not-found as valid for add; the corresponding case in `operationSpecificSpecialStatusesRejectEveryForbiddenPosition` must fail its exact error/call-prefix assertion.
7. Remove the entry cancellation check from read, set/update, or remove/delete one at a time; the corresponding branch of `preCancelledPublicOperationsInvokeNothing` must record a call or throw the wrong error.
8. Restore all code and rerun the complete GREEN command.

- [ ] **Step 5: Commit Task 3**

```bash
git add AppTemplate/App/Services/Keychain/KeychainService.swift \
  AppTemplateTests/TestSupport/Keychain/ScriptedKeychainSecItemExecutor.swift \
  AppTemplateTests/App/Services/Keychain/KeychainServiceTests.swift
git diff --cached --check
git commit -m "feat: add bounded Keychain service"
test -z "$(git status --porcelain)"
```

---

### Task 4: Add Fresh In-Memory Keychain Storage

**Files:**

- Create: `AppTemplate/App/Services/Keychain/InMemoryKeychainService.swift`
- Create: `AppTemplateTests/App/Services/Keychain/InMemoryKeychainServiceTests.swift`

**Interfaces:**

- Consumes only the raw protocol and `KeychainKey`.
- Produces a cancellation-aware actor for preview/UI-test graphs. It does not emulate Security status, entitlements, lock state, or persistence.

- [ ] **Step 1: Write the in-memory RED**

```swift
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
}
```

Define `InMemoryInvocation: CaseIterable, Sendable` with literal `.read`, `.set`, `.remove` cases and an async `invoke` switch. Expected RED: `InMemoryKeychainService` does not exist.

- [ ] **Step 2: Run RED, implement the actor, and run GREEN**

```swift
import Foundation

actor InMemoryKeychainService: IKeychainService {
    private var storage: [KeychainKey: Data] = [:]

    init() {}

    func data(for key: KeychainKey) async throws -> Data? {
        try Task.checkCancellation()
        return storage[key]
    }

    func set(_ data: Data, for key: KeychainKey) async throws {
        try Task.checkCancellation()
        storage[key] = data
    }

    func remove(_ key: KeychainKey) async throws -> Bool {
        try Task.checkCancellation()
        return storage.removeValue(forKey: key) != nil
    }
}
```

Run RED before adding the actor using `/tmp/AppTemplate-Keychain-Task4-RED.XXXXXX`, then GREEN afterward:

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task4-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/InMemoryKeychainServiceTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

- [ ] **Step 3: Mutation probes and commit**

1. Remove entry cancellation from `remove`; the `.remove` invocation must stop failing and the stored item must disappear, proving the test catches the mutation.
2. Replace Bool removal with unconditional `true`; the second removal assertion must fail.
3. Make storage static/shared; create two instances in a temporary test, write through the first, and require the second to observe `nil`; the mutation must fail. Restore instance storage and retain this two-instance isolation assertion in the test file.
4. Restore, rerun complete GREEN, then commit:

```bash
git add AppTemplate/App/Services/Keychain/InMemoryKeychainService.swift \
  AppTemplateTests/App/Services/Keychain/InMemoryKeychainServiceTests.swift
git diff --cached --check
git commit -m "feat: add in-memory Keychain service"
test -z "$(git status --porcelain)"
```

---

### Task 5: Compose Live, Preview, UI-Test, and Test Graphs

**Files:**

- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Consumes `KeychainService(service:)`, `InMemoryKeychainService()`, and `any IKeychainService`.
- Produces one immutable `keychain` property at the app graph. No Feature dependency slice changes and no factory reads or seeds a secret.

- [ ] **Step 1: Add composition RED assertions**

Add these exact tests to `AppDependenciesTests`:

```swift
@Test func liveGraphOwnsKeychainWithoutEagerAccess() {
    let dependencies = AppDependencies.live()
    #expect(dependencies.keychain is KeychainService)
}

@Test func liveGraphRetainsInjectedKeychainExactly() throws {
    let injected = KeychainServiceSpy()
    let dependencies = AppDependencies.live(keychainService: injected)
    let resolved = try #require(dependencies.keychain as? KeychainServiceSpy)
    #expect(resolved === injected)
}

@Test func previewGraphRetainsInjectedKeychainExactly() throws {
    let injected = KeychainServiceSpy()
    let dependencies = AppDependencies.preview(
        settings: SettingsDependencies(appInfo: AppInfoService(displayName: "Preview", version: "1")),
        keychainService: injected
    )
    let resolved = try #require(dependencies.keychain as? KeychainServiceSpy)
    #expect(resolved === injected)
}

@Test func previewAndUITestingGraphsUseFreshInMemoryKeychains() async throws {
    let settings = SettingsDependencies(
        appInfo: AppInfoService(displayName: "Preview", version: "1")
    )
    let preview1 = AppDependencies.preview(settings: settings)
    let preview2 = AppDependencies.preview(settings: settings)
    try await preview1.keychain.set(Data([1]), for: .data("Isolation"))
    #expect(try await preview2.keychain.data(for: .data("Isolation")) == nil)

    let state = AppState(
        isAuthenticated: false,
        hasCompletedOnboarding: false,
        isMaintenanceEnabled: false
    )
    let ui1 = AppDependencies.uiTesting(initialState: state)
    let ui2 = AppDependencies.uiTesting(initialState: state)
    try await ui1.keychain.set(Data([1]), for: .data("Isolation"))
    #expect(try await ui2.keychain.data(for: .data("Isolation")) == nil)
}

@Test func testGraphRetainsRequiredKeychainExactly() throws {
    let injected = KeychainServiceSpy()
    let dependencies = AppDependencies.test(
        localDatabaseService: InjectedLocalDatabaseService(),
        remoteService: InjectedRemoteService(),
        appStateStorage: InjectedAppStateStorage(),
        keychainService: injected,
        settings: SettingsDependencies(appInfo: AppInfoService(displayName: "Test", version: "1"))
    )
    let resolved = try #require(dependencies.keychain as? KeychainServiceSpy)
    #expect(resolved === injected)
}
```

Update the existing `testGraphKeepsInjectedServices` invocation to pass the same `injected` Keychain actor and assert identity there rather than creating a second redundant graph if the compiler reports duplicate coverage. Keep all existing UserDefaults/AppState/database/remote/settings assertions.

Expected RED: `AppDependencies` has no `keychain`, and factories have no Keychain parameters.

- [ ] **Step 2: Run and retain composition RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task5-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n 'no member.*keychain|extra argument.*keychainService|missing argument.*keychain' \
  "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Modify the graph exactly**

The final declarations/factory seams are:

```swift
nonisolated struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let settings: SettingsDependencies

    static func live(
        localDatabaseStoreLocationResolver:
            LocalDatabaseStoreLocationResolver = .live(),
        userDefaultsService: any IUserDefaultsService = UserDefaultsService(
            namespace: "AppTemplate"
        ),
        keychainService: any IKeychainService = KeychainService(
            service: "AppTemplate"
        )
    ) -> AppDependencies

    static func preview(
        settings: SettingsDependencies,
        appStateStorage: any IAppStateStorage = InMemoryAppStateStorage(),
        localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .inMemory()
        ),
        remoteService: any IRemoteService = RemoteService(),
        keychainService: any IKeychainService = InMemoryKeychainService()
    ) -> AppDependencies

    static func test(
        localDatabaseService: any ILocalDatabaseService,
        remoteService: any IRemoteService,
        appStateStorage: any IAppStateStorage,
        keychainService: any IKeychainService,
        settings: SettingsDependencies
    ) -> AppDependencies
}
```

`live` stores `keychainService`; `preview` stores its parameter; `test` stores its required parameter. `uiTesting(initialState:)` creates `InMemoryKeychainService()` inside every factory call. Do not create a static service, read a key, or change `AppTemplateApp`/`PreviewFixtures`.

- [ ] **Step 4: Run GREEN and composition mutation probes**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task5-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/InMemoryKeychainServiceTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

1. Reuse one static in-memory actor for preview/UI testing; the fresh-graph test must fail.
2. Ignore an injected live or preview service and construct another; the corresponding identity test must fail.
3. Read any key while constructing `live`; inject a spy and add an assertion that its call counts are all zero immediately after graph creation. Retain the zero-count assertion, restore lazy composition, rerun GREEN.
4. Verify no Feature consumption: `test -z "$(rg -n 'IKeychainService|KeychainService|KeychainKey|KeychainCodableKey' AppTemplate/Features)"`.

- [ ] **Step 5: Commit Task 5**

```bash
git add AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git diff --cached --check
git commit -m "refactor: compose Keychain service"
test -z "$(git status --porcelain)"
```

---

### Task 6: Document the Boundary and Enforce Static Policy

**Files:**

- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Interfaces:**

- Documents only the implemented low-level boundary and the separate adopter obligations.
- Produces deterministic source/scope guards that Task 7 reruns. It never claims the local Release artifacts exercised Keychain.

- [ ] **Step 1: Run the documentation RED**

```bash
set -euo pipefail
set +e
rg -q 'Data Protection Keychain' README.md
r1=$?
rg -q 'update.*add.*update.*add' docs/ARCHITECTURE.md
r2=$?
rg -q 'signed-and-provisioned' docs/RELEASE_CHECKLIST.md
r3=$?
set -e
test "$r1" -ne 0
test "$r2" -ne 0
test "$r3" -ne 0
```

- [ ] **Step 2: Make the four exact documentation changes**

- `README.md`: replace “future `KeychainService`” with the implemented app-private Data Protection Keychain boundary; state that it stores no sample credential and Features should use semantic repositories.
- `docs/ARCHITECTURE.md`: document `IKeychainService -> KeychainService -> KeychainSecItemExecuting -> SecurityKeychainSecItemExecutor`, Data-first codecs, two actors, exact generic-password/nonsync/WhenUnlockedThisDeviceOnly/no-explicit-group policy, update-add-update-add maximum of four calls, and fresh in-memory graphs.
- `docs/CUSTOMIZATION.md`: document stable opaque service/account names, raw versus String versus versioned direct-JSON keys, positive monotonic schema versions, new-first/write-new-before-remove-old migrations, semantic repository wrapping, and why shared groups/sync/biometrics/background-lock access/team or bundle identity changes need a separate design.
- `docs/RELEASE_CHECKLIST.md`: add the mandatory final-team/final-bundle signed-and-provisioned physical iPhone/iPad and signed macOS runtime gate; exact platform application-identifier and absent-or-singleton-equal `keychain-access-groups` rule; absence of App Groups; missing/add/read/update/Bool-remove/cleanup; lock-state, logout, retention, device-transfer, backup, recovery, and incident review. State explicitly that ad-hoc macOS and unsigned/simulator/unit evidence is compile/link evidence only and cannot clear the runtime blocker.

- [ ] **Step 3: Run complete source, entitlement, privacy, and scope guards**

```bash
set -euo pipefail
keychain='AppTemplate/App/Services/Keychain'

live_security_file='AppTemplate/App/Services/Keychain/Internal/KeychainSecurityAPI.swift'
test "$(rg -l '\bSecItem(CopyMatching|Update|Add|Delete)\s*\(' AppTemplate --glob '*.swift')" = \
  "$live_security_file"
test "$(rg -o '\bSecItem(CopyMatching|Update|Add|Delete)\s*\(' \
  "$live_security_file" | wc -l | tr -d ' ')" = 4
test -z "$(rg -n '\bSecItem(CopyMatching|Update|Add|Delete)\s*\(' \
  AppTemplateTests AppTemplateUITests --glob '*.swift')"
test -z "$(rg -n '@unchecked Sendable|unsafeBitCast|Logger|OSLog|SecCopyErrorMessageString|SecKeychain' "$keychain")"
test "$(rg -n '@unchecked Sendable' AppTemplateTests/App/Services/Keychain \
  AppTemplateTests/TestSupport/Keychain --glob '*.swift' \
  | wc -l | tr -d ' ')" = 1
test "$(rg -l '@unchecked Sendable' AppTemplateTests/App/Services/Keychain \
  AppTemplateTests/TestSupport/Keychain --glob '*.swift')" = \
  'AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift'
rg -q '^nonisolated final class MutableCFDataSource: @unchecked Sendable {' \
  AppTemplateTests/App/Services/Keychain/SecurityKeychainSecItemExecutorTests.swift
rg -q 'unsafeDowncast' "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
rg -q 'Data(bytes: bytes, count: count)' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
test -z "$(rg -n 'Data\(referencing:|bytesNoCopy' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift")"
rg -q 'security\.add(attributes as CFDictionary, nil)' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
test -z "$(rg -n 'kSecAttrSynchronizableAny|kSecAttrAccessGroup|kSecUseAuthenticationUI|kSecAccessControl|kSecAttrLabel|kSecAttrDescription|kSecAttrComment|kSecReturnPersistentRef|kSecReturnRef' "$keychain")"
rg -q 'kSecUseDataProtectionKeychain: requiredCFBoolean\(true\)' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
rg -q 'kSecAttrSynchronizable: requiredCFBoolean\(false\)' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
test "$(rg -o 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift" | wc -l | tr -d ' ')" = 2
rg -q 'value \? kCFBooleanTrue! : kCFBooleanFalse!' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"

for literal in \
  'Keychain key must not be blank.' \
  'Keychain key must not contain NUL.' \
  "Keychain key must not contain '.schema-'." \
  'Keychain schema version must be greater than zero.' \
  'Keychain service must not be blank.' \
  'Keychain service must not contain NUL.'; do
  test "$(rg -F -- "$literal" "$keychain" | wc -l | tr -d ' ')" = 1
done
test -z "$(rg -n 'precondition(Failure)?\([^,]+,[[:space:]]*"' "$keychain")"
rg -q '^nonisolated private func requiredCFBoolean(_ value: Bool) -> CFBoolean {' \
  "$keychain/Internal/SecurityKeychainSecItemExecutor.swift"
test "$(rg -o 'JSONEncoder\(\)\.encode\(value\)' \
  "$keychain/IKeychainService.swift" | wc -l | tr -d ' ')" = 1
test "$(rg -o 'JSONDecoder\(\)\.decode\(Value\.self, from: data\)' \
  "$keychain/IKeychainService.swift" | wc -l | tr -d ' ')" = 1
test -z "$(rg -n 'static (let|var) .*JSON(Encoder|Decoder)|private (let|var) .*JSON(Encoder|Decoder)' \
  "$keychain")"

test -z "$(find . \( -name '*.entitlements' -o -name 'PrivacyInfo.xcprivacy' \) -print)"
test "$(rg -n 'REGISTER_APP_GROUPS = YES;' AppTemplate.xcodeproj/project.pbxproj | wc -l | tr -d ' ')" = 2
test "$(shasum -a 256 AppTemplate.xcodeproj/project.pbxproj | awk '{print $1}')" = \
  bbd56931042546e0442fd1047896add039ad655f28f97de3bf885130c2c33dcb
test -z "$(rg -n 'IKeychainService|KeychainService|KeychainKey|KeychainCodableKey' \
  AppTemplate/Features AppTemplate/App/Networking AppTemplate/App/PreviewSupport AppTemplateUITests)"

test "$(shasum -a 256 AppTemplate/App/Services/UserDefaults/IUserDefaultsService.swift | awk '{print $1}')" = c0ba88dfcadf96053fca4230c653c8644a02007dc64b4dbf9a4f1a90414cca71
test "$(shasum -a 256 AppTemplate/App/Services/UserDefaults/UserDefaultsEncodedValue.swift | awk '{print $1}')" = 29088b164531fc713897f1f9e084a9414857ac5b403cd583d36da3ea0b4ce924
test "$(shasum -a 256 AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | awk '{print $1}')" = a7a9d2ddca4ac524ff5cba25b67accf758ffe072e88e642f068ec589a7f38cb4
test "$(shasum -a 256 AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift | awk '{print $1}')" = bc49452767e49ff7349aaa68b23059e549f47fe7e9048054d177627d44d91479
test "$(shasum -a 256 AppTemplate/App/Services/UserDefaults/UserDefaultsServiceError.swift | awk '{print $1}')" = c71220a1dc571bfb3d8cc3b20389c9611493e58e7faacd995ad19cbfb684717a
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppStateStore.swift | awk '{print $1}')" = e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppState.swift | awk '{print $1}')" = ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift | awk '{print $1}')" = f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift | awk '{print $1}')" = 30482218448299f2c2f0d7760454f78624f17d85f1cbfd03c35ea41d0703cbd4
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift | awk '{print $1}')" = 56c1479cfdf852b90eab6a0cc4d9cecdfda5fcbb30e607de7be0daa58c3ab917
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift | awk '{print $1}')" = 80e866dc0204649761eaf2a4d0b802edbce98c3b47661a9f2070f98b24292788
test "$(shasum -a 256 AppTemplate/App/Entry/AppTemplateApp.swift | awk '{print $1}')" = aed280f9ca12aecb9b720dd9e496a1d740d15f973a30f7cbebeeb3bdf6a0fce8
test "$(shasum -a 256 AppTemplate/App/PreviewSupport/PreviewFixtures.swift | awk '{print $1}')" = dbe1ed75f049d7f96639661fb32aaea498ef84c782e33654ac80629f7071aa01

changed_paths="$({
  git diff fb683478a36736f5f062ab036bd956cb2faecd17 --name-only
  git ls-files --others --exclude-standard
} | LC_ALL=C sort -u)"
while IFS= read -r changed_path; do
  test -n "$changed_path" || continue
  case "$changed_path" in
    docs/superpowers/plans/2026-08-12-keychain-service.md | \
    README.md | docs/ARCHITECTURE.md | docs/CUSTOMIZATION.md | docs/RELEASE_CHECKLIST.md | \
    AppTemplate/App/Services/Keychain/* | \
    AppTemplate/App/AppDependencies/AppDependencies.swift | \
    AppTemplateTests/App/Services/Keychain/* | \
    AppTemplateTests/TestSupport/Keychain/* | \
    AppTemplateTests/App/Composition/AppDependenciesTests.swift) ;;
    *) printf 'Out-of-scope path: %s\n' "$changed_path" >&2; exit 1 ;;
  esac
done <<<"$changed_paths"

rg -q 'Data Protection Keychain' README.md
rg -qi 'update.*add.*update.*add' docs/ARCHITECTURE.md
rg -q 'signed-and-provisioned' docs/RELEASE_CHECKLIST.md
rg -qi 'ad-hoc.*compile/link|compile/link.*ad-hoc' docs/RELEASE_CHECKLIST.md
rg -q 'application-identifier' docs/RELEASE_CHECKLIST.md
rg -q 'com.apple.application-identifier' docs/RELEASE_CHECKLIST.md
rg -q 'keychain-access-groups' docs/RELEASE_CHECKLIST.md
git diff --check
```

- [ ] **Step 4: Run the focused six-suite GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-Keychain-Task6-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainKeyTests \
  -only-testing:AppTemplateTests/KeychainConvenienceTests \
  -only-testing:AppTemplateTests/SecurityKeychainSecItemExecutorTests \
  -only-testing:AppTemplateTests/KeychainServiceTests \
  -only-testing:AppTemplateTests/InMemoryKeychainServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

- [ ] **Step 5: Commit Task 6**

```bash
git add README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md
git diff --cached --check
git commit -m "docs: explain app-private Keychain storage"
test -z "$(git status --porcelain)"
```

---

### Task 7: Run Compiler Proof, Nine Local Gates, Artifact Inspection, and Independent Review

**Files:**

- Verify only; edit only through a reviewed focused fix round.
- Evidence: `.superpowers/sdd/2026-08-12-keychain-service/final-verification-report.md` (ignored, never committed).

**Interfaces:**

- Consumes the reviewed Tasks 1–6 branch.
- Produces local deterministic evidence and an explicit release-blocker status. It does not perform or simulate the separately signed/provisioned adopter runtime gate.

- [ ] **Step 1: Preflight and compile-negative proof**

```bash
set -euo pipefail
test "$(pwd -P)" = '/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database'
test "$(git branch --show-current)" = 'codex/userdefaults-service'
test "$(git merge-base fb683478a36736f5f062ab036bd956cb2faecd17 HEAD)" = fb683478a36736f5f062ab036bd956cb2faecd17
test -z "$(git status --porcelain)"
xcodebuild -version
xcrun swift --version
jq --version
destinations="$(xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate -showdestinations)"
rg 'OS:26\.5, name:iPhone 17' <<<"$destinations"
rg 'OS:26\.5, name:iPad \(A16\)' <<<"$destinations"

compile_root="$(mktemp -d /tmp/AppTemplate-Keychain-FinalCompile.XXXXXX)"
set +e
xcodebuild build-for-testing -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) KEYCHAIN_CODABLE_TYPE_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
exit_code=$?
set -e
test "$exit_code" -ne 0
rg -n "cannot (convert|assign).*FirstSecret.*(to|as).*SecondSecret" \
  "$compile_root/build.log"
```

- [ ] **Step 2: Re-prove macOS UI-automation authorization**

```bash
set -euo pipefail
ui_root="$(mktemp -d /tmp/AppTemplate-Keychain-UIAuth.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  '-only-testing:AppTemplateUITests/AppTemplateUITests/testOnboardingRootIsVisible' \
  -derivedDataPath "$ui_root/DerivedData" \
  -resultBundlePath "$ui_root/UIAuth.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$ui_root/UIAuth.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount == 1 and .passedTests == 1 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
```

If automation initialization fails, preserve the bundle and stop. Do not skip or weaken gate 5.

- [ ] **Step 3: Run all nine automated gates under one validated root**

```bash
set -euo pipefail
root="$(mktemp -d /tmp/AppTemplate-Keychain-final.XXXXXX)"
test -d "$root"; test ! -L "$root"
case "$root" in /tmp/AppTemplate-Keychain-final.*) ;; *) exit 1 ;; esac
trap 'printf "Artifacts retained at %s\n" "$root"' EXIT
mkdir -p .superpowers/sdd/2026-08-12-keychain-service
printf '%s\n' "$root" > \
  .superpowers/sdd/2026-08-12-keychain-service/final-root.txt

assert_build() {
  local bundle="${1:?}"
  xcrun xcresulttool get build-results --path "$bundle" --compact \
  | jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0 and (.errors | length) == 0 and (.warnings | length) == 0 and (.analyzerWarnings | length) == 0'
}
assert_test() {
  local bundle="${1:?}"
  assert_build "$bundle"
  xcrun xcresulttool get test-results summary --path "$bundle" --compact \
  | jq -e '.result == "Passed" and .totalTestCount > 0 and .passedTests == .totalTestCount and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
}
run_test() {
  local name="${1:?}" destination="${2:?}"; shift 2
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -configuration Debug -destination "$destination" \
    -derivedDataPath "$root/DerivedData-$name" \
    -resultBundlePath "$root/$name.xcresult" "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_test "$root/$name.xcresult"
}
run_build() {
  local name="${1:?}" destination="${2:?}"; shift 2
  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
    -configuration Release -destination "$destination" \
    -derivedDataPath "$root/DerivedData-$name" \
    -resultBundlePath "$root/$name.xcresult" "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_build "$root/$name.xcresult"
}

# Gate 1: five Keychain suites plus composition, deterministic fakes only.
run_test focused-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests/KeychainKeyTests \
  -only-testing:AppTemplateTests/KeychainConvenienceTests \
  -only-testing:AppTemplateTests/SecurityKeychainSecItemExecutorTests \
  -only-testing:AppTemplateTests/KeychainServiceTests \
  -only-testing:AppTemplateTests/InMemoryKeychainServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests
# Gates 2–4: all units.
run_test units-macOS 'platform=macOS' -only-testing:AppTemplateTests
run_test units-iPhone17 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -only-testing:AppTemplateTests
run_test units-iPadA16 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' -only-testing:AppTemplateTests
# Gates 5–7: complete macOS scheme and complete mobile UI bundles.
run_test scheme-macOS 'platform=macOS'
run_test ui-iPhone17 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -only-testing:AppTemplateUITests
run_test ui-iPadA16 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' -only-testing:AppTemplateUITests
# Gate 8: generic/ad-hoc macOS compile/link only. Gate 9: unsigned generic iOS compile/link only.
run_build release-macOS 'generic/platform=macOS'
run_build release-iOS 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 4: Prove suite/case presence and inspect the ad-hoc macOS artifact honestly**

```bash
set -euo pipefail
root_file='.superpowers/sdd/2026-08-12-keychain-service/final-root.txt'
test -s "$root_file"
root="$(sed -n '1p' "$root_file")"
test -n "$root"
test "$(wc -l <"$root_file" | tr -d ' ')" = 1
test -d "$root"
test ! -L "$root"
case "$root" in /tmp/AppTemplate-Keychain-final.*) ;; *) exit 1 ;; esac
tests_json="$root/focused-tests.json"
xcrun xcresulttool get test-results tests --path "$root/focused-macOS.xcresult" --compact >"$tests_json"
for suite in KeychainKeyTests KeychainConvenienceTests \
  SecurityKeychainSecItemExecutorTests KeychainServiceTests \
  InMemoryKeychainServiceTests AppDependenciesTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$tests_json"
done

for mobile in units-iPhone17 units-iPadA16; do
  mobile_json="$root/$mobile-tests.json"
  xcrun xcresulttool get test-results tests --path "$root/$mobile.xcresult" --compact >"$mobile_json"
  jq -e --argjson required '[
    "dataPassesThroughWithoutTransformation()",
    "unicodeStringRoundTripsAndEmptyStringIsPresent()",
    "codableModelsRoundTripAndSchemaVersionsCoexist()",
    "copyUsesPhysicalCFBooleans()",
    "setConvergesAfterDuplicateRaceInAtMostFourCalls()",
    "secondAddDuplicateThrowsConcurrentMutationAfterFourCalls()",
    "inMemoryServiceRoundTripsAndRemoves()",
    "previewAndUITestingGraphsUseFreshInMemoryKeychains()"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Case" and .result == "Passed") | .name] as $passed
    | all($required[]; . as $name | $passed | index($name) != null)
  ' "$mobile_json"
done

release_app="$(find "$root/DerivedData-release-macOS/Build/Products/Release" \
  -maxdepth 1 -type d -name 'AppTemplate.app' -print)"
test -n "$release_app"
test "$(printf '%s\n' "$release_app" | wc -l | tr -d ' ')" = 1
codesign --verify --deep --strict --verbose=2 "$release_app"
codesign -d --entitlements - --xml "$release_app" \
  >"$root/release-macOS-entitlements.plist" \
  2>"$root/release-macOS-entitlements.stderr"
if test -s "$root/release-macOS-entitlements.plist"; then
  plutil -convert json -o "$root/release-macOS-entitlements.json" \
    "$root/release-macOS-entitlements.plist"
else
  printf '{}\n' >"$root/release-macOS-entitlements.json"
fi
jq -e '
  (."com.apple.application-identifier" // null) as $identifier
  | (."keychain-access-groups" // null) as $groups
  | (has("com.apple.security.application-groups") | not)
    and (
      $groups == null
      or (
        ($identifier | type) == "string"
        and ($groups | type) == "array"
        and ($groups | length) == 1
        and $groups[0] == $identifier
      )
    )
' "$root/release-macOS-entitlements.json"
jq -n --arg artifact "$release_app" --arg status \
  'PASS: compile/link and absent-or-singleton-default-group inspection only; runtime Data Protection Keychain NOT TESTED' \
  '{artifact: $artifact, evidence: $status}' >"$root/gate-8-scope.json"
```

If `keychain-access-groups` exists while `com.apple.application-identifier` is absent, fail. If both identity/group are absent—as on the current ad-hoc/runtime artifact—the local rule passes only as compile/link/no-custom-sharing evidence. Never infer Team ID, default-group reachability, provisioning, or runtime success.

- [ ] **Step 5: Rerun Task 6 static guards and independently review the whole branch**

Rerun Task 6 Step 3 verbatim after all nine artifacts pass. Then dispatch an independent reviewer with the normative spec, this plan, the full diff from `fb683478a36736f5f062ab036bd956cb2faecd17`, all test/result summaries, compiler-negative log, entitlement JSON, and static-guard output. Require explicit answers for:

1. exact key identity/schema typing and codec/cancellation/redaction behavior;
2. exact status table and update-add-update-add bounds;
3. actor reentrancy, checked Sendable, synchronized recorder, CF lifetime/type/copy safety;
4. exact query key sets and no-extra-authorized-group invariant;
5. no real SecItem ordinary test and no eager composition call;
6. UserDefaults/AppState preservation and authorized path scope;
7. documentation's honest local/adopter gate distinction.

For any P0–P2 finding, add a focused RED, run one bounded fix round, get a scoped re-review, and rerun all of Task 7 from a new root. Documentation-only corrections rerun every affected static/doc guard and document why existing runtime artifacts remain applicable.

- [ ] **Step 6: Record local completion and the unresolved mandatory adopter blocker**

Write `.superpowers/sdd/2026-08-12-keychain-service/final-verification-report.md` with:

- commit and clean status;
- compiler diagnostic;
- gates 1–9 as PASS with bundle path, count, failures/skips/expected failures, and warning counts;
- exact Gate 8 entitlement JSON and the words `compile/link evidence only — runtime Data Protection Keychain not tested`;
- static/scope/hash guard output;
- independent review verdict;
- a separate section `Mandatory signed-and-provisioned adopter gate: NOT SATISFIED / RELEASE BLOCKER` unless the final-team, final-bundle physical-device and signed-macOS procedure below was actually run.

The adopter gate remains:

1. Build the final product identity signed and provisioned in a normal user context.
2. On iOS/iPadOS use `application-identifier`; on macOS use `com.apple.application-identifier`. Require `keychain-access-groups` absent or exactly `[platform application identifier]`, no additional/wildcard/legacy group, and no `com.apple.security.application-groups`.
3. Exercise missing, add, read, update, and Bool remove using an isolated fixed test service/account on supported physical iPhone/iPad and the signed macOS app.
4. Validate unlocked/locked behavior against the actual foreground execution model.
5. Review logout, retention, device transfer, backup, recovery, and incident policy with product/security owners.
6. Remove the integration item and record build, profile, identity, platforms, and result.

An ad-hoc app, unsigned build, simulator, unit suite, or command-line Security probe cannot change this blocker to PASS.

- [ ] **Step 7: Commit only a reviewed fix if one was necessary; otherwise finish clean**

```bash
set -euo pipefail
git diff --check
test -z "$(git status --porcelain)"
git log --oneline fb683478a36736f5f062ab036bd956cb2faecd17..HEAD
```

## Completion Conditions

- Tasks 1–6 are individually reviewed and committed; the final worktree is clean.
- Compiler-negative generic mismatch, focused six-suite gate, all unit/UI cross-platform gates, Release compile/link gates, artifact inspection, immutable hashes, source/scope guards, and independent review pass.
- No ordinary test made a real `SecItem` call, and no source/project/signing capability broadened Keychain reach.
- Local code verification is complete only with the report's nine PASS rows. Distribution remains blocked until the separately signed-and-provisioned adopter gate is genuinely satisfied and recorded.
