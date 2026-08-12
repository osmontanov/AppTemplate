# Typed UserDefaults Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a synchronous, typed, app-private `UserDefaultsService`, preserve the shipped `AppTemplate.AppState` record byte-for-byte, and keep the generic defaults boundary out of Features.

**Architecture:** `UserDefaultsKey<Value>` owns a fixed logical name and a closed codec; `UserDefaultsService` owns namespacing, strict physical-type validation, and lock-confined raw `UserDefaults` access. `UserDefaultsAppStateStorage` remains the semantic `IAppStateStorage` adapter, while `AppStateStore`, preview/UI-test storage, and all product flows remain unchanged.

**Tech Stack:** Swift 6.3, Foundation, CoreFoundation, Swift Testing, Xcode 26.6, iOS/iPadOS/macOS 26, filesystem-synchronized Xcode groups.

## Global Constraints

- Treat `docs/superpowers/specs/2026-08-12-userdefaults-service-design.md` as normative.
- Work only on branch `codex/userdefaults-service` in `/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database`.
- Commit this reviewed plan before Task 1 starts; the implementation tasks require a clean worktree and do not stage the plan themselves.
- Follow strict TDD: create the focused failing test, record the intended failure, then add the minimum implementation and rerun a fresh GREEN bundle.
- Every Swift declaration crossing the project boundary is explicitly `nonisolated`; all eight constrained key factory extensions are explicitly `nonisolated`.
- The public protocol has exactly generic `value`, `set`, and `remove`; it exposes no untyped API, default value, namespace override, logger, observer, or suite API.
- `UserDefaultsService` is synchronous, `final`, `@unchecked Sendable`, and protects every raw access through one private `NSLock`; codecs never execute while that lock is held.
- Numeric reads use CoreFoundation representation checks. Swift casts and typed fallback getters are forbidden.
- Before setting a physically incompatible value, remove the existing value while holding the same lock. Compatible same-kind writes do not remove first.
- Foundation-normalized URL-origin `Data` is indistinguishable from raw `Data`; never add a provenance envelope or a test that expects URL-origin `Data` to be rejected.
- Codable values use fresh default `JSONEncoder()`/`JSONDecoder()` instances inside the codec closure per operation; enforce this by implementation review plus reentrancy/concurrency behavior, not an identity test or production test hook.
- The exact live physical AppState key remains `AppTemplate.AppState`, with raw `Data` bytes and schema version `1`; no migration, double encoding, fallback key, alias, or eager rewrite is authorized.
- Do not edit `AppStateStore`, `AppState`, `IAppStateStorage`, `AppStateStorageLoadResult`, `InMemoryAppStateStorage`, `AppTemplateApp`, `PreviewFixtures`, the Xcode project, UI tests, Features, navigation, networking, SwiftData, signing, entitlements, or build settings.
- Preview and UI-test graphs continue using fresh `InMemoryAppStateStorage`; `AppDependencies` must not retain or expose `IUserDefaultsService`.
- Do not add `PrivacyInfo.xcprivacy`, App Groups, `UserDefaults(suiteName:)` to production, `synchronize()`, OSLog, Logger, secrets, or Keychain code.
- Every test that touches a backing defaults store uses a unique `UserDefaults(suiteName:)` and removes its persistent domain; never mutate `UserDefaults.standard` in tests.
- Every RED, GREEN, compiler proof, and final gate uses its own root returned by `mktemp -d` and both warning-as-error flags. Every GREEN and final gate also uses a new result bundle; its test result must be `Passed` and nonzero with zero failed/skipped/expected-failure tests, and its build result must contain zero build/analyzer warnings.
- Preserve these SHA-256 values:

```text
e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022  AppTemplate/App/ApplicationState/AppStateStore.swift
ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137  AppTemplate/App/ApplicationState/AppState.swift
f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043  AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift
30482218448299f2c2f0d7760454f78624f17d85f1cbfd03c35ea41d0703cbd4  AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift
56c1479cfdf852b90eab6a0cc4d9cecdfda5fcbb30e607de7be0daa58c3ab917  AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift
aed280f9ca12aecb9b720dd9e496a1d740d15f973a30f7cbebeeb3bdf6a0fce8  AppTemplate/App/Entry/AppTemplateApp.swift
dbe1ed75f049d7f96639661fb32aaea498ef84c782e33654ac80629f7071aa01  AppTemplate/App/PreviewSupport/PreviewFixtures.swift
bbd56931042546e0442fd1047896add039ad655f28f97de3bf885130c2c33dcb  AppTemplate.xcodeproj/project.pbxproj
```

## File Map

Create production files:

- `AppTemplate/App/Services/UserDefaults/IUserDefaultsService.swift` — the three-operation generic protocol.
- `AppTemplate/App/Services/UserDefaults/UserDefaultsServiceError.swift` — payload-free public errors.
- `AppTemplate/App/Services/UserDefaults/UserDefaultsEncodedValue.swift` — closed internal Sendable bridge and physical kind.
- `AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift` — component validation, typed factories, and codecs.
- `AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift` — namespace, lock, raw Foundation access, physical checks.

Modify production files:

- `AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift` — adapt the generic service to `IAppStateStorage`.
- `AppTemplate/App/AppDependencies/AppDependencies.swift` — add only an injection parameter to `live()`.

Create test files:

- `AppTemplateTests/App/Services/UserDefaults/UserDefaultsKeyTests.swift`
- `AppTemplateTests/App/Services/UserDefaults/UserDefaultsServiceTests.swift`
- `AppTemplateTests/App/Services/UserDefaults/Fixtures/UserDefaultsKeyTypeMismatchCompileFixture.swift`
- `AppTemplateTests/TestSupport/UserDefaults/UserDefaultsTestSupport.swift`
- `AppTemplateTests/TestSupport/UserDefaults/UserDefaultsServiceSpy.swift`

Modify test files:

- `AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

Modify active docs only:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CUSTOMIZATION.md`
- `docs/RELEASE_CHECKLIST.md`

---

### Task 1: Define Typed Keys, Errors, and the Closed Codec Boundary

**Files:**

- Create: `AppTemplate/App/Services/UserDefaults/IUserDefaultsService.swift`
- Create: `AppTemplate/App/Services/UserDefaults/UserDefaultsServiceError.swift`
- Create: `AppTemplate/App/Services/UserDefaults/UserDefaultsEncodedValue.swift`
- Create: `AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift`
- Create: `AppTemplateTests/App/Services/UserDefaults/UserDefaultsKeyTests.swift`
- Create: `AppTemplateTests/App/Services/UserDefaults/Fixtures/UserDefaultsKeyTypeMismatchCompileFixture.swift`

**Interfaces:**

- Produces the exact service contract, redacted errors, closed encoded representation, shared component validator, and all eight typed key factories used by Tasks 2–4.
- Does not create `UserDefaultsService`; an existential compile witness in this task uses a test-only no-op conformer.

- [ ] **Step 1: Write the contract RED**

Create `UserDefaultsKeyTests` with these exact tests:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct UserDefaultsKeyTests {
    @Test func nativeFactoriesExposeExpectedKinds() throws {
        constructEveryFactoryFromNonisolatedContext()
        #expect(UserDefaultsKey<Bool>.bool("Flag").physicalKind == .bool)
        #expect(UserDefaultsKey<Int>.int("Count").physicalKind == .int)
        #expect(UserDefaultsKey<Float>.float("Ratio32").physicalKind == .float)
        #expect(UserDefaultsKey<Double>.double("Ratio64").physicalKind == .double)
        #expect(UserDefaultsKey<String>.string("Name").physicalKind == .string)
        #expect(UserDefaultsKey<Data>.data("Blob").physicalKind == .data)
        #expect(UserDefaultsKey<Date>.date("Date").physicalKind == .date)
    }

    @Test func codableFactoryUsesRawJSONData() throws {
        let key = UserDefaultsKey<KeyFixture>.codable("Fixture")
        let encoded = try key.encode(KeyFixture(value: 7))
        guard case let .data(data) = encoded else {
            Issue.record("Codable key must encode to Data")
            return
        }
        #expect(try JSONDecoder().decode(KeyFixture.self, from: data) == .init(value: 7))
        #expect(try key.decode(.data(data)) == .init(value: 7))
    }

    @Test func componentsValidateWithoutNormalizingValidSpelling() {
        #expect(UserDefaultsComponent.isValid("  Exact Name  "))
        #expect(!UserDefaultsComponent.isValid(" \n\t "))
        #expect(UserDefaultsKey<String>.string("  Exact Name  ").logicalName == "  Exact Name  ")
    }

    #if os(macOS)
    @Test func blankLogicalNameTerminates() async {
        await #expect(processExitsWith: .failure) {
            _ = UserDefaultsKey<String>.string(" \n\t ")
        }
    }
    #endif

    @Test func genericContractWorksThroughExistential() throws {
        let service: any IUserDefaultsService = NoOpUserDefaultsService()
        let key = UserDefaultsKey<Bool>.bool("Flag")
        #expect(try service.value(for: key) == nil)
        try service.set(true, for: key)
        service.remove(key)
    }
}

nonisolated private struct KeyFixture: Codable, Equatable, Sendable { let value: Int }

nonisolated private func constructEveryFactoryFromNonisolatedContext() {
    _ = UserDefaultsKey<Bool>.bool("Flag")
    _ = UserDefaultsKey<Int>.int("Count")
    _ = UserDefaultsKey<Float>.float("Ratio32")
    _ = UserDefaultsKey<Double>.double("Ratio64")
    _ = UserDefaultsKey<String>.string("Name")
    _ = UserDefaultsKey<Data>.data("Blob")
    _ = UserDefaultsKey<Date>.date("Date")
    _ = UserDefaultsKey<KeyFixture>.codable("Fixture")
}

nonisolated private struct NoOpUserDefaultsService: IUserDefaultsService {
    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value? { nil }
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws {}
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {}
}
```

Create the compile fixture:

```swift
#if USER_DEFAULTS_KEY_TYPE_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

nonisolated func userDefaultsKeyMismatch(
    service: any IUserDefaultsService,
    key: UserDefaultsKey<Bool>
) throws {
    try service.set("wrong", for: key)
}
#endif
```

Expected RED: build fails because `UserDefaultsKey`, `IUserDefaultsService`, and encoded/error types do not exist.

- [ ] **Step 2: Run and retain the RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task1-RED.XXXXXX)"
test -d "$red_root"
set +e
xcodebuild test \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsKeyTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
red_status=$?
set -e
test "$red_status" -ne 0
rg -n 'cannot find.*UserDefaultsKey|cannot find.*IUserDefaultsService' \
  "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement the minimum typed boundary**

Use these exact public declarations:

```swift
nonisolated protocol IUserDefaultsService: Sendable {
    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value?
    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws
    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>)
}

nonisolated enum UserDefaultsServiceError: Error, Equatable, Sendable {
    case invalidStoredValue
    case encodingFailed
    case decodingFailed
}

nonisolated enum UserDefaultsPhysicalKind: Equatable, Sendable {
    case bool, int, float, double, string, data, date
}

nonisolated enum UserDefaultsEncodedValue: Sendable {
    case bool(Bool), int(Int), float(Float), double(Double)
    case string(String), data(Data), date(Date)
}

nonisolated enum UserDefaultsComponent {
    static func isValid(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

Define `UserDefaultsKey<Value: Sendable>` with internal read-only `logicalName`, `physicalKind`, and `@Sendable` encode/decode closures. Its private initializer performs `precondition(UserDefaultsComponent.isValid(logicalName))` and preserves the supplied spelling. Put the private initializer and all factories in the same file.

Every extension is explicitly nonisolated:

```swift
nonisolated extension UserDefaultsKey where Value == Bool {
    static func bool(_ name: String) -> Self {
        Self(name: name, kind: .bool, encode: UserDefaultsEncodedValue.bool) {
            guard case let .bool(value) = $0 else { throw UserDefaultsServiceError.invalidStoredValue }
            return value
        }
    }
}
```

Repeat the same closed pattern for Int/Float/Double/String/Data/Date. `.codable` catches any encode error and throws `.encodingFailed`, creates a fresh `JSONEncoder()` inside its encode closure, requires `.data` on decode, creates a fresh `JSONDecoder()` inside the decode closure, and maps any decode error to `.decodingFailed`.

- [ ] **Step 4: Run the GREEN and the compile-negative proof**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task1-GREEN.XXXXXX)"
test -d "$green_root"
xcodebuild test \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsKeyTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'

compile_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task1-COMPILE.XXXXXX)"
set +e
xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) USER_DEFAULTS_KEY_TYPE_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
compile_status=$?
set -e
test "$compile_status" -ne 0
rg -n "cannot convert value of type 'String' to expected argument type 'Bool'|conflicting arguments to generic parameter 'Value'.*String.*Bool" \
  "$compile_root/build.log"
```

- [ ] **Step 5: Mutation review and commit**

The Task 1 test target is a separately compiled consumer of `AppTemplate`. With the pinned Swift toolchain, default MainActor isolation introduced by removing `nonisolated` from a constrained extension is not serialized for that imported extension method, so this cross-module build cannot prove the annotation. Keep the explicit declaration requirement with this exact source guard; Task 3 supplies the same-module compiler mutation after `UserDefaultsAppStateStorage` exists:

```bash
set -euo pipefail
key_file='AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift'
test -f "$key_file"
test "$(rg -c '^nonisolated extension UserDefaultsKey where ' "$key_file")" -eq 8
for constraint in \
  'where Value == Bool' \
  'where Value == Int' \
  'where Value == Float' \
  'where Value == Double' \
  'where Value == String' \
  'where Value == Data' \
  'where Value == Date' \
  'where Value: Codable'
do
  rg -F -x "nonisolated extension UserDefaultsKey $constraint {" "$key_file" >/dev/null
done
```

Temporarily loosen the mismatch fixture to `UserDefaultsKey<String>` and confirm the negative build succeeds. Restore the mismatch, rerun the complete compile-negative block from Step 4 from a fresh root, require the exact `String`/`Bool` diagnostic again, and finally rerun GREEN.

```bash
set -euo pipefail
git diff --check
git add \
  AppTemplate/App/Services/UserDefaults \
  AppTemplateTests/App/Services/UserDefaults/UserDefaultsKeyTests.swift \
  AppTemplateTests/App/Services/UserDefaults/Fixtures/UserDefaultsKeyTypeMismatchCompileFixture.swift
git diff --cached --check
git commit -m "feat: define typed UserDefaults keys"
test -z "$(git status --porcelain)"
```

---

### Task 2: Implement the Lock-Confined Concrete Service

**Files:**

- Create: `AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift`
- Create: `AppTemplateTests/App/Services/UserDefaults/UserDefaultsServiceTests.swift`
- Create: `AppTemplateTests/TestSupport/UserDefaults/UserDefaultsTestSupport.swift`

**Interfaces:**

- Consumes Task 1 key/codec/protocol types.
- Produces `UserDefaultsService(namespace:userDefaults:)`, the live implementation used by Tasks 3–4.

- [ ] **Step 1: Write service behavior REDs and support**

Create an isolated-suite helper returning `(suiteName, UserDefaults)` and always clean it with `defer { defaults.removePersistentDomain(forName: suiteName) }`. Add `nonisolated final class RecordingUserDefaults: UserDefaults, @unchecked Sendable`, an `NSLock`-protected subclass that records `object`, `set`, and `remove` call counts while a `seed` method calls `super` without recording. Its only initializer is failable `init?(suiteName: String) { super.init(suiteName: suiteName) }`; every caller supplies a UUID-backed suite, unwraps it with `try #require`, and removes that exact persistent domain. The recorder also tracks `inFlightRawCalls` and `maxConcurrentRawCalls`; an opt-in 5 ms delay occurs after increment and before decrement so concurrent service calls overlap deterministically if the service lock is removed. Recorder state locking must wrap only counter/in-flight snapshots, never the delay or `super` call, or the recorder would mask a missing service lock. Add nonisolated `CodableFixture`, a `ThrowingCodable` whose `encode(to:)` throws and whose decoder is valid, and reentrant Codable fixtures. The decoder reentrancy fixture stores its synchronous callback in `Mutex<(@Sendable () throws -> Void)?>`, copies the callback out before invocation, and resets it with `defer`; the containing suite stays serialized.

Create `@Suite(.serialized) struct UserDefaultsServiceTests` with these exact test names. `blankNamespaceTerminates` is enclosed in `#if os(macOS)` because Swift Testing exit tests are unavailable on iOS/iPadOS; `UserDefaultsComponent.isValid` remains exercised on every platform:

```text
blankNamespaceTerminates
missingValueReturnsNil
nativeLifecycleCoversAllSevenPhysicalTypes
boolRoundTripsWithBooleanRepresentation
intRoundTripsWithNonfloatingNumberRepresentation
floatRoundTripsWithFloat32Representation
doubleRoundTripsWithFloat64Representation
stringRoundTrips
validNamespaceSpellingIsNotTrimmed
dataRoundTripsByteForByte
dateRoundTrips
codableRoundTripsWhileBackingValueIsRawJSONData
removeMakesValueMissing
readUsesExactlyOneRawObjectLookup
removeDoesNotReadOrDecode
wrongRepresentationsAreRejectedAndRetained
urlOriginDataIsAcceptedByDataKey
urlOriginDataReachesCodableDecoderAndRemainsUntouched
booleanIsNeverAcceptedAsInt
integerIsNeverAcceptedAsBool
floatIsNeverAcceptedAsDouble
doubleIsNeverAcceptedAsFloat
floatingNumberIsNeverAcceptedAsInt
outOfRangeIntegerIsRejected
outOfRangeIntegerToIntReplacementRemovesOldRepresentation
stringToDataReplacementRemovesOldRepresentation
equalBoolToIntReplacementRemovesOldRepresentation
equalIntToBoolReplacementRemovesOldRepresentation
equalFloatToDoubleReplacementRemovesOldRepresentation
equalDoubleToFloatReplacementRemovesOldRepresentation
equalIntToDoubleReplacementRemovesOldRepresentation
equalDoubleToIntReplacementRemovesOldRepresentation
sameKindReplacementDoesNotRemoveFirst
encodingFailureLeavesExistingBytesUntouched
encodingFailurePerformsNoRawAccess
malformedCodableDataThrowsDecodingFailedAndRemainsUntouched
codableEncodingCanReenterTheSameService
codableDecodingCanReenterTheSameService
concurrentCallsThroughOneServiceRemainValid
serviceErrorsArePayloadFree
```

Use literal expected values. `nativeLifecycleCoversAllSevenPhysicalTypes` explicitly performs missing → set/read → same-kind replacement/read → remove/missing for Bool, Int, Float, Double, String, Data, and Date; do not derive expectations through the production codec. `validNamespaceSpellingIsNotTrimmed` uses namespace `"  Exact Namespace  "` and asserts the only raw key is `"  Exact Namespace  .Flag"`. `wrongRepresentationsAreRejectedAndRetained` is a table whose rows cover each expected native kind against every other observable native kind plus an array and dictionary; each row asserts `.invalidStoredValue` and the same raw object/CF numeric kind remains. For cross-type tests seed an equal value of the old kind, set through the new typed key, then assert both the new CoreFoundation kind and `removeCallCount == 1`. The out-of-range integer replacement seeds `NSNumber(value: UInt64.max)`, writes a valid native Int through the same `.int` key, and requires one removal; the nonnumeric test seeds String, writes Data, and requires one removal. These prove compatibility uses the same complete validity rule as reads, not only a broad physical-kind guess. The same-kind test asserts `removeCallCount == 0`. Wrong-representation fixtures exclude URL. Instead, the two URL characterization tests seed `URL(string: "https://example.invalid/path")!`, capture the Foundation-normalized `Data` returned by `object(forKey:)`, prove `.data` returns those exact bytes, and prove `.codable` reaches JSON decoding, returns `.decodingFailed`, and leaves those bytes unchanged. `readUsesExactlyOneRawObjectLookup`, `removeDoesNotReadOrDecode`, and `encodingFailurePerformsNoRawAccess` assert exact recorder counts. The concurrent test enables recorder overlap delay, creates 100 distinct keys (`Concurrent-0` … `Concurrent-99`), and asserts `maxConcurrentRawCalls == 1`; it does not assume a transactional set/read pair on one key.

Representative required RED:

```swift
@Test func equalFloatToDoubleReplacementRemovesOldRepresentation() throws {
    let suiteName = "AppTemplateTests.UserDefaults.Replacement.\(UUID().uuidString)"
    let backing = try #require(RecordingUserDefaults(suiteName: suiteName))
    defer { backing.removePersistentDomain(forName: suiteName) }
    backing.seed(Float(1.25), forKey: "Tests.Number")
    let service = UserDefaultsService(namespace: "Tests", userDefaults: backing)

    try service.set(Double(1.25), for: .double("Number"))

    #expect(try service.value(for: .double("Number")) == 1.25)
    #expect(backing.removeCallCount == 1)
    #expect(backing.numericKind(forKey: "Tests.Number") == .float64)
}
```

Expected RED: compile failure because `UserDefaultsService` does not exist.

- [ ] **Step 2: Run and retain the RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task2-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsServiceTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
red_status=$?
set -e
test "$red_status" -ne 0
rg -n 'cannot find.*UserDefaultsService' "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement raw access and strict copying**

Implement this exact shape:

```swift
import CoreFoundation
import Foundation

nonisolated final class UserDefaultsService: IUserDefaultsService, @unchecked Sendable {
    private let namespace: String
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    init(namespace: String, userDefaults: UserDefaults = .standard) {
        precondition(UserDefaultsComponent.isValid(namespace))
        self.namespace = namespace
        self.userDefaults = userDefaults
    }

    func value<Value: Sendable>(for key: UserDefaultsKey<Value>) throws -> Value? {
        let encoded = try lock.withLock { () throws -> UserDefaultsEncodedValue? in
            guard let raw = userDefaults.object(forKey: physicalKey(for: key)) else { return nil }
            return try copyEncodedValue(raw, expected: key.physicalKind)
        }
        return try encoded.map(key.decode)
    }

    func set<Value: Sendable>(_ value: Value, for key: UserDefaultsKey<Value>) throws {
        let encoded = try key.encode(value)
        lock.withLock {
            let physicalKey = physicalKey(for: key)
            if let existing = userDefaults.object(forKey: physicalKey),
               !hasCompatibleRepresentation(existing, with: encoded) {
                userDefaults.removeObject(forKey: physicalKey)
            }
            set(encoded, forKey: physicalKey)
        }
    }

    func remove<Value: Sendable>(_ key: UserDefaultsKey<Value>) {
        lock.withLock { userDefaults.removeObject(forKey: physicalKey(for: key)) }
    }
}
```

`copyEncodedValue` must copy raw objects into Swift Bool/Int/Float/Double/String/Data/Date before returning from the lock. Bool requires `CFBooleanGetTypeID`; Int rejects Boolean and floating CFNumbers and uses `Int(exactly:)`; Float requires `.float32Type`; Double requires `.float64Type`. Never use typed `UserDefaults` getters or plain numeric casts as validation. `set(encoded:)` switches over every enum case and calls `UserDefaults.set` while locked.

- [ ] **Step 4: Run GREEN and mutation probes**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task2-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsKeyTests \
  -only-testing:AppTemplateTests/UserDefaultsServiceTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'

tests_json="$green_root/tests.json"
xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact >"$tests_json"
for suite in UserDefaultsKeyTests UserDefaultsServiceTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$tests_json"
done

```

Required mutation probes, one at a time with exact-method selectors, then restore and rerun GREEN:

- remove incompatible-value removal: `equalFloatToDoubleReplacementRemovesOldRepresentation()` fails;
- remove `Int(exactly:)`: `outOfRangeIntegerIsRejected()` fails;
- make compatibility accept every nonfloating CFNumber or every object: `outOfRangeIntegerToIntReplacementRemovesOldRepresentation()` and `stringToDataReplacementRemovesOldRepresentation()` fail;
- replace CF checks with Swift casts: Bool/Int and Float/Double separation tests fail;
- move codec execution under the lock: reentrant encode/decode tests hit their bounded time limit;
- always remove: `sameKindReplacementDoesNotRemoveFirst()` fails.
- remove the concrete service lock: `concurrentCallsThroughOneServiceRemainValid()` fails because `maxConcurrentRawCalls > 1`.

Both reentrancy tests use `@Test(.timeLimit(.minutes(1)))`. Run each exact quoted selector under a fresh xcodebuild root. A mutation that moves codec execution under `NSLock` must be treated as RED when the test reports failure/time-limit or the enclosing command fails to complete within the repository runner's 90-second command deadline; restore immediately before any other gate.

For every non-hanging mutation, run this exact helper with the named method from the list and require the intended case itself to be present and failed:

```bash
set -euo pipefail
expected_red_method="${EXPECTED_RED_METHOD:?include trailing parentheses}"
expected_red_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Mutation-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  "-only-testing:AppTemplateTests/UserDefaultsServiceTests/$expected_red_method" \
  -derivedDataPath "$expected_red_root/DerivedData" \
  -resultBundlePath "$expected_red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$expected_red_root/xcodebuild.log" 2>&1
mutation_status=$?
set -e
test "$mutation_status" -ne 0
xcrun xcresulttool get test-results tests \
  --path "$expected_red_root/Tests.xcresult" --compact \
| jq -e --arg method "$expected_red_method" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Case" and .name == $method and .result == "Failed")]
    | length == 1
  '
```

- [ ] **Step 5: Self-review and commit**

Inspect that `JSONEncoder()` and `JSONDecoder()` construction remains inside per-call codec closures, no codec runs under `lock.withLock`, and no raw `Any` returns from a critical section. Enforce the structure with exactly one `JSONEncoder()` and one `JSONDecoder()` constructor in `UserDefaultsKey.swift`, and no stored encoder/decoder type anywhere in the service folder:

```bash
set -euo pipefail
test "$(rg -n 'synchronize\(' AppTemplate/App/Services/UserDefaults | wc -l | tr -d ' ')" = 0
test "$(rg -n 'Logger|OSLog' AppTemplate/App/Services/UserDefaults | wc -l | tr -d ' ')" = 0
test "$(rg -o 'JSONEncoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
test "$(rg -o 'JSONDecoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
codec_files="$(rg -l 'JSONEncoder|JSONDecoder' AppTemplate/App/Services/UserDefaults)"
test "$codec_files" = 'AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift'
git diff --check
git add \
  AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift \
  AppTemplateTests/App/Services/UserDefaults/UserDefaultsServiceTests.swift \
  AppTemplateTests/TestSupport/UserDefaults/UserDefaultsTestSupport.swift
git diff --cached --check
git commit -m "feat: add typed UserDefaults service"
test -z "$(git status --porcelain)"
```

---

### Task 3: Preserve the AppState Adapter and Physical Record

**Files:**

- Modify: `AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift` — keep the live graph compiling with a concrete service; Task 4 adds the injection seam.
- Modify: `AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift`
- Create: `AppTemplateTests/TestSupport/UserDefaults/UserDefaultsServiceSpy.swift`

**Interfaces:**

- Consumes `any IUserDefaultsService` and `.data("AppState")`.
- Produces the existing `IAppStateStorage` contract without changing AppState types or logic.

- [ ] **Step 1: Replace the old adapter tests with REDs**

Add `nonisolated final class UserDefaultsServiceSpy: IUserDefaultsService, @unchecked Sendable`, a lock-protected generic spy that records the key logical name/kind, returns `Data?`, accepts only Data in set for adapter tests, and can throw a configured `UserDefaultsServiceError` or test sentinel.

Use these exact test names:

```text
missingServiceValueMapsToMissing
serviceDataLoadsByteForByteThroughFixedAppStateKey
invalidStoredValueMapsToInvalidValue
encodingFailurePropagatesUnchanged
decodingFailurePropagatesUnchanged
nonServiceFailurePropagatesUnchanged
saveForwardsExactBytesThroughFixedAppStateKey
removeDelegatesThroughFixedAppStateKey
existingStablePhysicalRecordLoadsByteForByte
saveKeepsStablePhysicalKeyAndRawDataRepresentation
wrongStablePhysicalRecordRemainsInvalidAndUnchanged
currentAppStateRecordRestoresWithoutRewritingPhysicalBytes
futureAppStateRecordRemainsByteForByteUntouched
```

Use hand-written byte fixtures:

```swift
let sentinel = Data([0x00, 0x01, 0x7F, 0x80, 0xFF])
let current = Data(#"{"schemaVersion":1,"isAuthenticated":true,"hasCompletedOnboarding":true,"isMaintenanceEnabled":false}"#.utf8)
let future = Data(#"{"schemaVersion":2,"future":"preserve-me"}"#.utf8)
```

Real-service compatibility tests use namespace `AppTemplate`, seed only `AppTemplate.AppState`, and assert `AppState` and `AppTemplate.AppTemplate.AppState` are absent. The current-schema integration asserts the decoded state and writable status; the future-schema integration asserts initial state and `.readOnly(.unsupportedFutureSchema(2))`. Both use `RecordingUserDefaults` and require raw `setCallCount == 0` and `removeCallCount == 0` after `AppStateStore` initialization, in addition to exact byte equality. Expected RED: the old initializer accepts `UserDefaults`, not `any IUserDefaultsService`, and the mapping tests do not compile.

- [ ] **Step 2: Run and retain RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task3-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
red_status=$?
set -e
test "$red_status" -ne 0
rg -n 'cannot convert|incorrect argument label|extra argument|IUserDefaultsService' "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Implement the semantic adapter**

```swift
import Foundation

nonisolated struct UserDefaultsAppStateStorage: IAppStateStorage, Sendable {
    private static let appStateKey: UserDefaultsKey<Data> = .data("AppState")
    private let userDefaults: any IUserDefaultsService

    init(userDefaults: any IUserDefaultsService) {
        self.userDefaults = userDefaults
    }

    func load() throws -> AppStateStorageLoadResult {
        do {
            guard let data = try userDefaults.value(for: Self.appStateKey) else { return .missing }
            return .data(data)
        } catch UserDefaultsServiceError.invalidStoredValue {
            return .invalidValue
        }
    }

    func save(_ data: Data) throws { try userDefaults.set(data, for: Self.appStateKey) }
    func remove() throws { userDefaults.remove(Self.appStateKey) }
}
```

Catch only the exact `.invalidStoredValue` case. Do not catch the enum broadly.

In the same GREEN step, replace the now-invalid live construction with:

```swift
appStateStorage: UserDefaultsAppStateStorage(
    userDefaults: UserDefaultsService(namespace: "AppTemplate")
)
```

Do not yet change the `live()` signature; that deliberate RED belongs to Task 4. Preview, UI-test, and test factories remain byte-for-byte unchanged.

- [ ] **Step 4: Run GREEN and mapping mutation**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task3-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'

focused_tests="$green_root/focused-tests.json"
xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact >"$focused_tests"
for suite in UserDefaultsAppStateStorageTests AppStateStoreTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$focused_tests"
done
```

Temporarily catch every `UserDefaultsServiceError` as `.invalidValue`; confirm `encodingFailurePropagatesUnchanged` or `decodingFailurePropagatesUnchanged` fails. Restore and rerun GREEN.

Temporarily remove `nonisolated` only from `nonisolated extension UserDefaultsKey where Value == Data`. Run this fresh same-module compiler mutation and require the actor-isolation error at `UserDefaultsAppStateStorage.appStateKey`:

```bash
set -euo pipefail
isolation_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task3-ISOLATION.XXXXXX)"
test -d "$isolation_root"
set +e
xcodebuild test \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -derivedDataPath "$isolation_root/DerivedData" \
  -resultBundlePath "$isolation_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$isolation_root/xcodebuild.log" 2>&1
isolation_status=$?
set -e
test "$isolation_status" -ne 0
rg -ni \
  'UserDefaultsAppStateStorage\.swift:.*error:.*(main actor-isolated.*data|data.*main actor-isolated)' \
  "$isolation_root/xcodebuild.log"
```

Restore `nonisolated` on the Data extension and rerun the complete GREEN block at the start of this step from a new root.

- [ ] **Step 5: Verify immutable boundaries and commit**

```bash
set -euo pipefail
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppStateStore.swift | awk '{print $1}')" = e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppState.swift | awk '{print $1}')" = ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift | awk '{print $1}')" = f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043
git diff --check
git add \
  AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift \
  AppTemplateTests/TestSupport/UserDefaults/UserDefaultsServiceSpy.swift
git diff --cached --check
git commit -m "refactor: route app state through typed defaults"
test -z "$(git status --porcelain)"
```

---

### Task 4: Inject the Live Service Without Exposing It

**Files:**

- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Consumes Task 3 adapter initializer.
- Produces one injection-only default parameter on `AppDependencies.live`; no stored property or Feature dependency.

- [ ] **Step 1: Add the composition RED**

Add:

```swift
@Test func liveGraphConsumesInjectedUserDefaultsServiceThroughAppStateAdapter() throws {
    let spy = UserDefaultsServiceSpy(value: Data([0x01, 0x02]))
    let dependencies = AppDependencies.live(userDefaultsService: spy)
    let storage = dependencies.appStateStorage

    #expect(try storage.load() == .data(Data([0x01, 0x02])))
    try storage.save(Data([0x03]))
    try storage.remove()
    #expect(spy.operations == [
        .read(name: "AppState", kind: .data),
        .set(name: "AppState", kind: .data, data: Data([0x03])),
        .remove(name: "AppState", kind: .data),
    ])
}
```

Retain all existing preview/UI/test injection tests. Expected RED: `extra argument 'userDefaultsService' in call`.

- [ ] **Step 2: Run RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task4-RED.XXXXXX)"
set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
red_status=$?
set -e
test "$red_status" -ne 0
rg -F "extra argument 'userDefaultsService'" "$red_root/xcodebuild.log"
```

- [ ] **Step 3: Add the injection-only parameter**

Use this exact signature and construction:

```swift
static func live(
    localDatabaseStoreLocationResolver:
        LocalDatabaseStoreLocationResolver = .live(),
    userDefaultsService: any IUserDefaultsService = UserDefaultsService(
        namespace: "AppTemplate"
    )
) -> AppDependencies {
    AppDependencies(
        localDatabase: LocalDatabaseService(
            configuration: .live(locationResolver: localDatabaseStoreLocationResolver)
        ),
        remote: RemoteService(),
        appStateStorage: UserDefaultsAppStateStorage(userDefaults: userDefaultsService),
        settings: SettingsDependencies(appInfo: AppInfoService())
    )
}
```

Do not alter `uiTesting`, `preview`, `test`, or the stored property list.

- [ ] **Step 4: Run GREEN and source-boundary review**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task4-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
test "$(rg -n 'let userDefaults|var userDefaults|IUserDefaultsService' AppTemplate/App/AppDependencies/AppDependencies.swift | wc -l | tr -d ' ')" = 1

tests_json="$green_root/tests.json"
xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact >"$tests_json"
for suite in AppDependenciesTests UserDefaultsAppStateStorageTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$tests_json"
done
```

The sole match must be the `live` parameter; inspect it before accepting the count.

- [ ] **Step 5: Commit**

```bash
set -euo pipefail
git diff --check
git add \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git diff --cached --check
git commit -m "refactor: inject live UserDefaults service"
test -z "$(git status --porcelain)"
```

---

### Task 5: Document the Boundary and Enforce Scope

**Files:**

- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Interfaces:**

- Documents the implemented service without altering code.
- Produces the scope/security/privacy assertions rerun in Task 6.

- [ ] **Step 1: Record documentation REDs**

```bash
set -euo pipefail
set +e
rg -q 'typed app-private UserDefaults' README.md
readme_status=$?
rg -q 'NSPrivacyAccessedAPICategoryUserDefaults' docs/RELEASE_CHECKLIST.md
privacy_status=$?
rg -q 'CA92\.1' docs/RELEASE_CHECKLIST.md
reason_status=$?
set -e
test "$readme_status" -ne 0
test "$privacy_status" -ne 0
test "$reason_status" -ne 0
```

- [ ] **Step 2: Update the four active documents**

Make these exact semantic changes:

- `README.md`: replace “future UserDefaultsService” with a concise statement that the template now provides a synchronous typed app-private defaults boundary for `AppStateStore`; retain the separate warning that secrets belong in a future Keychain service.
- `docs/ARCHITECTURE.md`: document `UserDefaultsKey -> UserDefaultsService -> UserDefaultsAppStateStorage -> AppStateStore`, one locked raw boundary, exact `AppTemplate.AppState` Data compatibility, and “accepted/enqueued, not fsynced”.
- `docs/CUSTOMIZATION.md`: give a fixed-key example, require stable namespaces/logical names after release, explain native versus Codable-Data choice, prohibit user-generated keys and secrets, and keep AppState synchronous unless startup is redesigned.
- `docs/RELEASE_CHECKLIST.md`: require physical-key compatibility, absence of App Group entitlement, review of `NSPrivacyAccessedAPICategoryUserDefaults`, and `CA92.1` as the app-private example; retain the product-specific privacy-manifest distribution blocker.

- [ ] **Step 3: Run scope, security, and immutable-file guards**

```bash
set -euo pipefail
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppStateStore.swift | awk '{print $1}')" = e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppState.swift | awk '{print $1}')" = ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift | awk '{print $1}')" = f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift | awk '{print $1}')" = 30482218448299f2c2f0d7760454f78624f17d85f1cbfd03c35ea41d0703cbd4
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift | awk '{print $1}')" = 56c1479cfdf852b90eab6a0cc4d9cecdfda5fcbb30e607de7be0daa58c3ab917
test "$(shasum -a 256 AppTemplate/App/Entry/AppTemplateApp.swift | awk '{print $1}')" = aed280f9ca12aecb9b720dd9e496a1d740d15f973a30f7cbebeeb3bdf6a0fce8
test "$(shasum -a 256 AppTemplate/App/PreviewSupport/PreviewFixtures.swift | awk '{print $1}')" = dbe1ed75f049d7f96639661fb32aaea498ef84c782e33654ac80629f7071aa01
test "$(shasum -a 256 AppTemplate.xcodeproj/project.pbxproj | awk '{print $1}')" = bbd56931042546e0442fd1047896add039ad655f28f97de3bf885130c2c33dcb

test "$(rg -n 'REGISTER_APP_GROUPS = YES;' AppTemplate.xcodeproj/project.pbxproj | wc -l | tr -d ' ')" = 2
test -z "$(find . \( -name '*.entitlements' -o -name 'PrivacyInfo.xcprivacy' \) -print)"
test "$(rg -n 'synchronize\(|Logger|OSLog|suiteName:' AppTemplate/App/Services/UserDefaults | wc -l | tr -d ' ')" = 0
test "$(rg -o 'JSONEncoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
test "$(rg -o 'JSONDecoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
test "$(rg -l 'JSONEncoder|JSONDecoder' AppTemplate/App/Services/UserDefaults)" = \
  'AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift'
if rg -n 'IUserDefaultsService|UserDefaultsService|UserDefaultsKey' \
  AppTemplate/Features AppTemplate/App/PreviewSupport AppTemplateUITests; then
  exit 1
fi
rg -q 'NSPrivacyAccessedAPICategoryUserDefaults' docs/RELEASE_CHECKLIST.md
rg -q 'CA92\.1' docs/RELEASE_CHECKLIST.md
git diff --check
```

Inspect all production `UserDefaults` tokens; only the service folder may touch the type directly, while `UserDefaultsAppStateStorage` may mention the semantic service name but not Foundation `UserDefaults`.

```bash
set -euo pipefail
actual_raw_files="$(rg -l '\bUserDefaults\b' AppTemplate --glob '*.swift' | LC_ALL=C sort)"
expected_raw_files="$(printf '%s\n' \
  AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift \
  | LC_ALL=C sort)"
test "$actual_raw_files" = "$expected_raw_files"

changed_paths="$({
  git diff 31e79d156dd042b97b1f436152f17a7d4d669d12 --name-only
  git ls-files --others --exclude-standard
} | LC_ALL=C sort -u)"
while IFS= read -r path; do
  test -n "$path" || continue
  case "$path" in
    docs/superpowers/plans/2026-08-12-userdefaults-service.md | \
    README.md | docs/ARCHITECTURE.md | docs/CUSTOMIZATION.md | \
    docs/RELEASE_CHECKLIST.md | \
    AppTemplate/App/Services/UserDefaults/* | \
    AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift | \
    AppTemplate/App/AppDependencies/AppDependencies.swift | \
    AppTemplateTests/App/Services/UserDefaults/* | \
    AppTemplateTests/TestSupport/UserDefaults/* | \
    AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift | \
    AppTemplateTests/App/Composition/AppDependenciesTests.swift) ;;
    *) printf 'Out-of-scope path: %s\n' "$path" >&2; exit 1 ;;
  esac
done <<<"$changed_paths"
```

- [ ] **Step 4: Run the focused five-suite gate**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-Task5-GREEN.XXXXXX)"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsKeyTests \
  -only-testing:AppTemplateTests/UserDefaultsServiceTests \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'

focused_tests="$green_root/focused-tests.json"
xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact >"$focused_tests"
for suite in UserDefaultsKeyTests UserDefaultsServiceTests \
  UserDefaultsAppStateStorageTests AppStateStoreTests AppDependenciesTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$focused_tests"
done
```

- [ ] **Step 5: Commit documentation**

```bash
set -euo pipefail
git add README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md
git diff --cached --check
git commit -m "docs: explain typed UserDefaults storage"
test -z "$(git status --porcelain)"
```

---

### Task 6: Run the Compiler Proof, Nine Final Gates, and Whole-Branch Review

**Files:**

- Verify only; edit only through a reviewed fix round if a gate exposes a defect.
- Evidence: `.superpowers/sdd/2026-08-12-userdefaults-service/final-verification-report.md` (ignored, never committed).

**Interfaces:**

- Consumes the complete Tasks 1–5 branch.
- Produces retained cross-platform evidence and an independent final verdict.

- [ ] **Step 1: Run preflight and compile-negative proof**

```bash
set -euo pipefail
test "$(pwd -P)" = '/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database'
test "$(git branch --show-current)" = 'codex/userdefaults-service'
test "$(git merge-base 31e79d156dd042b97b1f436152f17a7d4d669d12 HEAD)" = \
  '31e79d156dd042b97b1f436152f17a7d4d669d12'
test -z "$(git status --porcelain)"
xcodebuild -version
xcrun swift --version
jq --version
destinations="$(xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate -showdestinations)"
rg 'OS:26\.5, name:iPhone 17' <<<"$destinations"
rg 'OS:26\.5, name:iPad \(A16\)' <<<"$destinations"

compile_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-FinalCompile.XXXXXX)"
set +e
xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) USER_DEFAULTS_KEY_TYPE_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
compile_status=$?
set -e
test "$compile_status" -ne 0
rg -n "cannot convert value of type 'String' to expected argument type 'Bool'|conflicting arguments to generic parameter 'Value'.*String.*Bool" \
  "$compile_root/build.log"
```

- [ ] **Step 2: Verify macOS UI automation authorization**

```bash
set -euo pipefail
ui_auth_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-UIAuth.XXXXXX)"
test -d "$ui_auth_root"
test ! -L "$ui_auth_root"
xcodebuild test \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  '-only-testing:AppTemplateUITests/AppTemplateUITests/testOnboardingRootIsVisible' \
  -derivedDataPath "$ui_auth_root/DerivedData" \
  -resultBundlePath "$ui_auth_root/UIAuth.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary \
  --path "$ui_auth_root/UIAuth.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount == 1 and .passedTests == 1 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
```

If the runner cannot enable UI automation, preserve the bundle and report that exact environmental blocker; do not skip, allowlist, or weaken the complete macOS gate.

- [ ] **Step 3: Run all nine gates under one validated root**

```bash
set -euo pipefail
verification_root="$(mktemp -d /tmp/AppTemplate-UserDefaults-final.XXXXXX)"
test -d "$verification_root"
test ! -L "$verification_root"
case "$verification_root" in /tmp/AppTemplate-UserDefaults-final.*) ;; *) exit 1 ;; esac
trap 'printf "Artifacts retained at %s\n" "$verification_root"' EXIT

assert_build() {
  local bundle="${1:?}"
  xcrun xcresulttool get build-results --path "$bundle" --compact \
  | jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0 and (.errors | length) == 0 and (.warnings | length) == 0 and (.analyzerWarnings | length) == 0'
}

assert_test() {
  local bundle="${1:?}"
  assert_build "$bundle"
  xcrun xcresulttool get test-results summary --path "$bundle" --compact \
  | jq -e '.result == "Passed" and .totalTestCount > 0 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0 and .passedTests == .totalTestCount'
}

run_test() {
  local name="${1:?}" destination="${2:?}"
  shift 2
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -configuration Debug -destination "$destination" \
    -derivedDataPath "$verification_root/DerivedData-$name" \
    -resultBundlePath "$verification_root/$name.xcresult" "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_test "$verification_root/$name.xcresult"
}

run_build() {
  local name="${1:?}" destination="${2:?}"
  shift 2
  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
    -configuration Release -destination "$destination" \
    -derivedDataPath "$verification_root/DerivedData-$name" \
    -resultBundlePath "$verification_root/$name.xcresult" "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_build "$verification_root/$name.xcresult"
}

run_test focused-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests/UserDefaultsKeyTests \
  -only-testing:AppTemplateTests/UserDefaultsServiceTests \
  -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
  -only-testing:AppTemplateTests/AppStateStoreTests \
  -only-testing:AppTemplateTests/AppDependenciesTests
run_test units-macOS 'platform=macOS' -only-testing:AppTemplateTests
run_test units-iPhone17 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -only-testing:AppTemplateTests
run_test units-iPadA16 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' -only-testing:AppTemplateTests
run_test scheme-macOS 'platform=macOS'
run_test ui-iPhone17 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -only-testing:AppTemplateUITests
run_test ui-iPadA16 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' -only-testing:AppTemplateUITests
run_build release-macOS 'generic/platform=macOS'
run_build release-iOS 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

tests_json="$verification_root/focused-tests.json"
xcrun xcresulttool get test-results tests \
  --path "$verification_root/focused-macOS.xcresult" --compact >"$tests_json"
for suite in UserDefaultsKeyTests UserDefaultsServiceTests \
  UserDefaultsAppStateStorageTests AppStateStoreTests AppDependenciesTests; do
  jq -e --arg suite "$suite" '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants | select(.nodeType == "Test Suite" and .name == $suite and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$tests_json"
done

for mobile_gate in units-iPhone17 units-iPadA16; do
  mobile_tests="$verification_root/$mobile_gate-tests.json"
  xcrun xcresulttool get test-results tests \
    --path "$verification_root/$mobile_gate.xcresult" --compact >"$mobile_tests"
  jq -e '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite"
          and .name == "UserDefaultsServiceTests"
          and .result == "Passed")
      | ([. | descendants | select(.nodeType == "Test Case")] | length)]
    | length == 1 and .[0] > 0
  ' "$mobile_tests"
  jq -e --argjson required '[
      "boolRoundTripsWithBooleanRepresentation()",
      "intRoundTripsWithNonfloatingNumberRepresentation()",
      "floatRoundTripsWithFloat32Representation()",
      "doubleRoundTripsWithFloat64Representation()",
      "concurrentCallsThroughOneServiceRemainValid()"
    ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Case" and .result == "Passed")
      | .name] as $passed
    | all($required[]; . as $name | $passed | index($name) != null)
  ' "$mobile_tests"
done

release_apps="$(
  find "$verification_root/DerivedData-release-macOS/Build/Products/Release" \
    -maxdepth 1 -type d -name 'AppTemplate.app' -print
)"
test -n "$release_apps"
test "$(printf '%s\n' "$release_apps" | wc -l | tr -d ' ')" = 1
release_app="$release_apps"
codesign --verify --deep --strict --verbose=2 "$release_app"
codesign -d --entitlements - --xml "$release_app" 2>/dev/null \
  >"$verification_root/release-macOS-entitlements.plist"
plutil -convert json -o - \
  "$verification_root/release-macOS-entitlements.plist" \
| jq -e '
    ."com.apple.security.app-sandbox" == true
    and ."com.apple.security.network.client" == true
    and (has("com.apple.security.network.server") | not)
    and (has("com.apple.security.application-groups") | not)
  '

actual_raw_files="$(rg -l '\bUserDefaults\b' AppTemplate --glob '*.swift' | LC_ALL=C sort)"
test "$actual_raw_files" = 'AppTemplate/App/Services/UserDefaults/UserDefaultsService.swift'
test "$(rg -n 'REGISTER_APP_GROUPS = YES;' AppTemplate.xcodeproj/project.pbxproj | wc -l | tr -d ' ')" = 2
test -z "$(find . \( -name '*.entitlements' -o -name 'PrivacyInfo.xcprivacy' \) -print)"
test "$(rg -n 'synchronize\(|Logger|OSLog|suiteName:' AppTemplate/App/Services/UserDefaults | wc -l | tr -d ' ')" = 0
test "$(rg -o 'JSONEncoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
test "$(rg -o 'JSONDecoder\(\)' AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift | wc -l | tr -d ' ')" = 1
test "$(rg -l 'JSONEncoder|JSONDecoder' AppTemplate/App/Services/UserDefaults)" = \
  'AppTemplate/App/Services/UserDefaults/UserDefaultsKey.swift'
if rg -n 'IUserDefaultsService|UserDefaultsService|UserDefaultsKey' \
  AppTemplate/Features AppTemplate/App/PreviewSupport AppTemplateUITests; then
  exit 1
fi
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppStateStore.swift | awk '{print $1}')" = e2846b7a0fa63db4938346aac5b81c4b700b0a42f668cc9e22dba02040f67022
test "$(shasum -a 256 AppTemplate/App/ApplicationState/AppState.swift | awk '{print $1}')" = ea6969c168898605add197897825df01f01ff45d42d7c089149249a89ac95137
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/IAppStateStorage.swift | awk '{print $1}')" = f2376d470c671f167e95d7b7286925cd5c8283ab9ffc2ac6ac2e6d4c19bbd043
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/AppStateStorageLoadResult.swift | awk '{print $1}')" = 30482218448299f2c2f0d7760454f78624f17d85f1cbfd03c35ea41d0703cbd4
test "$(shasum -a 256 AppTemplate/App/ApplicationState/Persistence/InMemoryAppStateStorage.swift | awk '{print $1}')" = 56c1479cfdf852b90eab6a0cc4d9cecdfda5fcbb30e607de7be0daa58c3ab917
test "$(shasum -a 256 AppTemplate/App/Entry/AppTemplateApp.swift | awk '{print $1}')" = aed280f9ca12aecb9b720dd9e496a1d740d15f973a30f7cbebeeb3bdf6a0fce8
test "$(shasum -a 256 AppTemplate/App/PreviewSupport/PreviewFixtures.swift | awk '{print $1}')" = dbe1ed75f049d7f96639661fb32aaea498ef84c782e33654ac80629f7071aa01
test "$(shasum -a 256 AppTemplate.xcodeproj/project.pbxproj | awk '{print $1}')" = bbd56931042546e0442fd1047896add039ad655f28f97de3bf885130c2c33dcb
rg -q 'NSPrivacyAccessedAPICategoryUserDefaults' docs/RELEASE_CHECKLIST.md
rg -q 'CA92\.1' docs/RELEASE_CHECKLIST.md

changed_paths="$({
  git diff 31e79d156dd042b97b1f436152f17a7d4d669d12 --name-only
  git ls-files --others --exclude-standard
} | LC_ALL=C sort -u)"
while IFS= read -r path; do
  test -n "$path" || continue
  case "$path" in
    docs/superpowers/plans/2026-08-12-userdefaults-service.md | \
    README.md | docs/ARCHITECTURE.md | docs/CUSTOMIZATION.md | \
    docs/RELEASE_CHECKLIST.md | AppTemplate/App/Services/UserDefaults/* | \
    AppTemplate/App/ApplicationState/Persistence/UserDefaultsAppStateStorage.swift | \
    AppTemplate/App/AppDependencies/AppDependencies.swift | \
    AppTemplateTests/App/Services/UserDefaults/* | \
    AppTemplateTests/TestSupport/UserDefaults/* | \
    AppTemplateTests/App/ApplicationState/Persistence/UserDefaultsAppStateStorageTests.swift | \
    AppTemplateTests/App/Composition/AppDependenciesTests.swift) ;;
    *) printf 'Out-of-scope path: %s\n' "$path" >&2; exit 1 ;;
  esac
done <<<"$changed_paths"
git diff --check
test -z "$(git status --porcelain)"
```

- [ ] **Step 4: Independent review and evidence report**

Request a whole-branch review of `31e79d156dd042b97b1f436152f17a7d4d669d12...HEAD` against the normative spec and this plan. It must inspect generic existential usability, explicit nonisolated factories, numeric representation checks, lock confinement, reentrancy, incompatible replacement, redacted errors, AppState bytes/key, composition isolation, docs/privacy/entitlements, and all retained results.

For any P0–P2 source/test finding, write a focused RED, dispatch one fix round, rerun its focused GREEN, obtain a scoped re-review, then rerun Task 6 Step 3 in full from a new root, including all nine gates, the five-suite assertion, signed entitlement extraction, immutable hashes, source guards, and clean status. For a docs-only correction, rerun every affected Task 5/6 guard and record why runtime artifacts remain valid. Record commits, commands, test counts, warning counts, result paths, entitlement output, final guard output, and final clean status in the ignored report.

---

## Definition of Done

- Typed native and Codable keys compile through `any IUserDefaultsService`; a mismatched key/value does not compile.
- Missing, invalid, encode, and decode outcomes match the public contract and expose no payload.
- All raw access is lock-confined; codecs are outside the lock; numeric physical representations and equal cross-type replacement are proven.
- `AppTemplate.AppState` remains exactly raw Data under the same key and schema, with current/future bytes preserved.
- Live composition injects the generic service only into the semantic adapter; preview/UI/Features do not consume it.
- Documentation accurately covers stability, accepted/enqueued durability, secrets, App Groups, and required-reason review.
- The compiler-negative proof, nine gates, entitlement inspection, immutable-source guards, and independent review are green with a clean worktree.
