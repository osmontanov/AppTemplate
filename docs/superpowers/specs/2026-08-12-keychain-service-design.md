# App-Private Keychain Service Design

## Status

The user approved the selected direction and its security constraints in the
preceding design discussion on 2026-08-12 and instructed implementation work to
continue without another confirmation gate. This document is the normative
input to the Keychain implementation plan.

This is the persistence cycle immediately after the typed UserDefaults service.
The implementation must preserve that cycle's completed application-state
adapter and composition changes. It adds a separate secrets boundary; it does
not move `AppState`, SwiftData records, or ordinary preferences into Keychain.

## Goal

Add a practical, testable `KeychainService` that:

- stores small secrets as generic-password items in the Data Protection
  Keychain on iOS, iPadOS, and macOS;
- uses the app's private default keychain access group, with no project-
  configured sharing capability, custom access-group entitlement, or explicit
  access-group query;
- keeps every item nonsynchronizable and protected by
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`;
- exposes raw `Data` as the canonical service contract, with UTF-8 `String`
  and versioned `Codable` conveniences layered above it;
- distinguishes absence, invalid returned data, codec failures, security
  policy failures, cancellation, and bounded concurrent-mutation failure;
- keeps synchronous Security-framework calls off the MainActor behind an
  async actor boundary;
- never performs a real `SecItem` call in the ordinary unit-test suite; and
- provides fresh in-memory preview and UI-test composition.

The service is infrastructure for later semantic repositories. This cycle
stores no real credential or token and adds no Feature or ViewModel consumer.

## Current Baseline

The project supports iOS, iPadOS, and macOS 26.0, uses Swift 6 with MainActor
default isolation, has no package dependencies, and uses
filesystem-synchronized Xcode groups. `AppDependencies` is an immutable
`Sendable` graph with `live`, `uiTesting`, `preview`, and `test` factories.

At the start of this cycle, the preceding UserDefaults cycle owns only
nonsensitive launch-state persistence. SwiftData owns explicitly registered
local records. The networking layer contains no authorization token source.
Keychain therefore remains a new, independent service boundary.

The app target currently:

- is sandboxed on macOS and uses the hardened runtime;
- uses automatic signing for normal Xcode builds;
- has no entitlements file;
- declares no Keychain Sharing capability;
- declares no App Group capability or application-groups entitlement;
- contains no `PrivacyInfo.xcprivacy`; and
- uses filesystem-synchronized groups, so new Swift files do not need manual
  `project.pbxproj` membership entries.

`REGISTER_APP_GROUPS = YES` is present in Debug and Release build settings. As
documented by the preceding UserDefaults design, that project setting is not
itself an entitlement. This work leaves it byte-for-byte unchanged.

## Selected Direction and Rejected Alternatives

The selected direction is an async raw-Data protocol, a concrete actor, and a
separate actor that translates semantic requests into synchronous `SecItem`
calls. `String` and `Codable` support are protocol extensions, so spies and the
in-memory implementation automatically share the same codecs.

This is preferred because raw `Data` is the Security framework's native secret
value, while a generic Codable-only protocol would hide representation and
migration decisions. It also keeps all untyped Core Foundation dictionaries
inside one internal executor rather than exposing `[String: Any]` or
`CFDictionary` to application code.

The following alternatives are rejected:

1. A synchronous service is rejected because Apple documents `SecItem` update
   and delete operations as blocking and recommends a background queue or
   async function. A synchronous app-facing API would make MainActor misuse
   easy.
2. A Codable-only service is rejected because credentials and tokens already
   arrive as bytes or strings, and not every secret has or needs a model
   schema.
3. A public generic property-list or query-dictionary wrapper is rejected
   because it leaks Security-framework mechanics, non-Sendable values, access
   policy, and primary-key construction into callers.
4. A third-party Keychain package is rejected because the required surface is
   small, the project has no package dependencies, and the Security API must
   remain directly testable through a narrow local seam.
5. Synchronizable Keychain, shared access groups, App Groups, and extension
   sharing are rejected for this cycle. They require different identity,
   entitlement, migration, conflict, and product-policy decisions.
6. File-based macOS Keychain support is rejected. Apple recommends the Data
   Protection Keychain for consistent current behavior across platforms.

## Responsibility Split

| Component | Owns | Must not own |
| --- | --- | --- |
| `KeychainKey` | One validated raw-Data logical account | Service namespace, default value, schema, Security query |
| `KeychainCodableKey<Value>` | Compile-time value type, logical account, positive schema version, derived physical account | Migration code, cached codec, default value |
| `IKeychainService` | Async raw-Data read, set, and remove contract | Security dictionaries, logging, Feature semantics |
| Protocol conveniences | UTF-8 and JSON encode/decode behavior | Raw `SecItem` access or retries |
| `KeychainService` | Cancellation, status mapping, bounded set state machine | CF dictionaries, logging, product credential policy |
| `SecurityKeychainSecItemExecutor` | Exact query construction and one synchronous Security call per method | Public errors, retries, codecs, application state |
| `KeychainSecurityAPI` | Internal checked-`Sendable` table of four explicitly `@Sendable` `SecItem` closures | Query policy, mutable state, or unchecked conformance |
| `InMemoryKeychainService` | Fresh isolated preview/UI-test storage | Security emulation, persistence, fault injection |
| `AppDependencies` | Live/in-memory/test ownership and injection | Secret values or credential lifecycle |

## Public Contract

All value types, errors, protocol declarations, and protocol extensions are
explicitly `nonisolated` because the project uses MainActor default isolation.

```swift
nonisolated
protocol IKeychainService: Sendable {
    func data(for key: KeychainKey) async throws -> Data?

    func set(
        _ data: Data,
        for key: KeychainKey
    ) async throws

    @discardableResult
    func remove(_ key: KeychainKey) async throws -> Bool
}
```

The semantics are exact:

- `data(for:)` returns `nil` only for `errSecItemNotFound`;
- `set(_:for:)` returns only after one update or add call succeeds;
- `remove(_:)` returns `true` for `errSecSuccess` and `false` for
  `errSecItemNotFound`;
- every other Security status is mapped to a typed error;
- `CancellationError` remains `CancellationError`; and
- none of these results claims crash-level durability, remote synchronization,
  backup migration, or erasure of copies already held in process memory.

`remove(_:)` deliberately returns `Bool`. A caller implementing logout can
distinguish “an item was removed” from an idempotent “already absent” result
without converting absence into an error.

## Keys and Physical Identity

### Raw Data key

```swift
nonisolated
struct KeychainKey: Hashable, Sendable {
    static func data(_ name: String) -> Self
}
```

There is no public initializer and no public raw account property. The factory
validates a developer-defined logical name and stores its exact spelling. It
does not trim, normalize, localize, case-fold, hash, or derive the name from a
bundle identifier.

A logical name must:

- contain at least one non-whitespace-and-newline character;
- contain no NUL scalar; and
- not contain the reserved marker `.schema-`.

Violation is a precondition failure because keys are fixed program constants,
not expected runtime input. Validation does not transform valid input. Every
diagnostic is a fixed, noninterpolating literal so an invalid component is
never reflected into a crash report. The exact messages are:

```text
Keychain key must not be blank.
Keychain key must not contain NUL.
Keychain key must not contain '.schema-'.
Keychain schema version must be greater than zero.
Keychain service must not be blank.
Keychain service must not contain NUL.
```

The first three apply to both key factories, the fourth applies to the Codable
factory, and the last two apply to the concrete service namespace. A static
source guard requires these exact literals and rejects string interpolation in
every production Keychain precondition. The same nonblank and no-NUL
validation applies to the concrete service namespace.

The raw key's physical `kSecAttrAccount` is exactly its logical name. One raw
logical key may be interpreted either as arbitrary Data or UTF-8 String for its
whole shipped lifetime. Switching interpretation is an explicit migration,
not a fallback performed by the service.

### Versioned Codable key

```swift
nonisolated
struct KeychainCodableKey<Value: Codable & Sendable>: Sendable {
    static func codable(
        _ name: String,
        schemaVersion: UInt
    ) -> Self
}
```

The key binds one compile-time `Value` type to one positive schema version.
`schemaVersion == 0` is a precondition failure. The logical name follows the
same validation rules as a raw key.

The physical account is derived exactly as:

```text
<logical name>.schema-<positive base-10 schema version>
```

For example:

```swift
let key: KeychainCodableKey<SessionSecret> =
    .codable("Session", schemaVersion: 2)
```

uses the physical account `Session.schema-2`. Reserving `.schema-` in logical
names makes the pair `(logical name, schema version)` unambiguous and prevents
a raw factory from accidentally constructing a Codable physical account.

The Swift type name is not stored in Keychain and is not used as an identity
string. Renaming a Swift type without changing its encoded schema therefore
does not orphan an item. Changing the encoded shape incompatibly requires a
schema-version increment and an explicit migration.

Neither key type contains a default value, access group, synchronizability
flag, accessibility policy, encoder instance, decoder instance, or secret.

### Generic-password identity

Every item uses `kSecClassGenericPassword`. The physical identity is:

```text
class:                     kSecClassGenericPassword
service:                   KeychainService.service
account:                   key physical account
synchronizable:            false
access-group query field:  omitted
add placement:             signed default private access group
match scope:               every group the signed process is authorized to use
```

Apple documents service, account, synchronizability, and access group as
generic-password composite primary-key attributes. Omitting
`kSecAttrAccessGroup` has operation-specific semantics: add places a new item
in the default access group, while copy, update, and delete may match items in
any access group authorized by the signed process. This design is app-private
only because its source, project, signing, and release gates permit no
additional authorized group. Under that invariant, the match scope contains
only the default private group. The service never uses `kSecAttrLabel`,
`kSecAttrDescription`, `kSecAttrComment`, or `kSecAttrGeneric` as an additional
identity channel.

The live service string is exactly `AppTemplate`. An adopter changes that
fixed namespace before the first product release. After release, changing the
service or account requires an explicit migration because the old item will no
longer match.

Service and account are searchable metadata, not secret payload. Product code
must not place an email address, user identifier, access token, password, or
other sensitive content in either attribute. Use fixed opaque semantic names
and put the secret only in `kSecValueData`.

## String and Codable Conveniences

The conveniences live on `IKeychainService`, so concrete, in-memory, and spy
implementations cannot drift in encoding behavior.

```swift
nonisolated extension IKeychainService {
    func string(for key: KeychainKey) async throws -> String?

    func set(
        _ string: String,
        for key: KeychainKey
    ) async throws

    func value<Value: Codable & Sendable>(
        for key: KeychainCodableKey<Value>
    ) async throws -> Value?

    func set<Value: Codable & Sendable>(
        _ value: Value,
        for key: KeychainCodableKey<Value>
    ) async throws

    @discardableResult
    func remove<Value: Codable & Sendable>(
        _ key: KeychainCodableKey<Value>
    ) async throws -> Bool
}
```

The String codec is exact UTF-8:

- setting uses `Data(string.utf8)`, which cannot fail;
- reading `nil` returns `nil`;
- bytes that are not valid UTF-8 throw `.invalidUTF8`; and
- invalid bytes remain untouched.

The Codable codec uses raw JSON bytes:

- every set creates a fresh default-configured `JSONEncoder`;
- encoding completes before raw `set` can make a Security call;
- every successful non-nil read creates a fresh default-configured
  `JSONDecoder`;
- JSON or model decoding failure throws `.decodingFailed` without mutation;
- encoder failure throws `.encodingFailed` without mutation; and
- no encoder, decoder, container, or user-written Codable implementation is
  cached or shared across tasks.

The schema version is represented by the physical account, not by a second
envelope inside the secret bytes. This keeps stored data as the model's direct
JSON and permits old and new schemas to coexist during a migration. It also
means changing `Value` incompatibly without incrementing `schemaVersion` is a
caller error that normally surfaces as `.decodingFailed`.

Conveniences check task cancellation before running a codec. Codable code that
throws `CancellationError` propagates cancellation unchanged; other codec
errors map to the corresponding redacted category. After a raw mutation
returns success, a convenience returns immediately and performs no
post-success cancellation check.

## Public Errors and Status Mapping

```swift
nonisolated
enum KeychainServiceError: Error, Equatable, Sendable {
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

Special statuses are interpreted in the operation that receives them:

| Status | Read | Remove | Set state machine |
| --- | --- | --- | --- |
| `errSecSuccess` | Executor must return `.data` or `.invalid`; injected `.status(errSecSuccess)` is `.internalFailure` | `true` | Current update/add step succeeds and returns |
| `errSecItemNotFound` | `nil` | `false` | Update step advances to add; an add returning this status is unexpected |
| `errSecDuplicateItem` | Unexpected status | Unexpected status | First add advances to the second update; second add throws `.concurrentMutation` |

Every other terminal status maps exactly as follows:

| Security status | Public error |
| --- | --- |
| `errSecDecode`, `errSecInvalidData`, `errSecInvalidEncoding` | `.invalidStoredData` |
| `errSecNotAvailable`, `errSecServiceNotAvailable`, `errSecDataNotAvailable`, `errSecNoSuchKeychain` | `.unavailable` |
| `errSecInteractionNotAllowed`, `errSecInteractionRequired` | `.interactionNotAllowed` |
| `errSecAuthFailed` | `.authenticationFailed` |
| `errSecUserCanceled` | `.interactionCancelled` |
| `errSecWrPerm`, `errSecReadOnly`, `errSecNoAccessForItem` | `.permissionDenied` |
| `errSecMissingEntitlement` | `.missingEntitlement` |
| `errSecDataTooLarge` | `.dataTooLarge` |
| `errSecParam`, `errSecInvalidQuery`, `errSecMissingValue`, `errSecBadReq`, `errSecReadOnlyAttr` | `.invalidRequest` |
| Any other non-success status | `.unexpectedStatus(status)` |

A successful copy call that returns no object or a non-Data object becomes
`.invalidStoredData`; it is not an unexpected OSStatus because the status was
success and the returned representation violated the query contract.
`KeychainSecItemCopyResult.status(errSecSuccess)` is likewise an executor
contract violation: a successful copy must be represented as `.data` or
`.invalid`, never as `.status`. The service maps that impossible injected
result to `.internalFailure`, not `.unexpectedStatus(errSecSuccess)`.

The live executor may throw only `CancellationError` before invoking Security.
The service propagates that error unchanged. If an injected executor violates
its internal contract by throwing another Swift error, the service maps it to
`.internalFailure` and does not expose the underlying error or description.

Security's `errSecUserCanceled` is not Swift task cancellation. It maps to
`.interactionCancelled`, even though the selected policy does not request an
authentication prompt. This preserves the distinction if the platform
returns that status.

## Concrete Service

```swift
actor KeychainService: IKeychainService {
    private let service: String
    private let executor: any KeychainSecItemExecuting

    init(service: String)

    // Internal test/composition seam.
    init(
        service: String,
        executor: any KeychainSecItemExecuting
    )
}
```

The primary initializer creates one `SecurityKeychainSecItemExecutor`. The
executor-injecting initializer remains internal. The actor stores no cached
secret, query dictionary, encoder, decoder, retry counter, or last error.

The service actor owns status semantics and the bounded multi-call set
operation. The executor actor owns blocking calls and exact Security
dictionaries. Awaiting the executor makes `KeychainService` reentrant between
individual Security calls; another task, process, or authorized actor can also
mutate the item. The set algorithm therefore cannot assume that one
update/add observation stays true for the next call.

## Exact Security Queries

All four operations start from this base identity dictionary:

| Query key | Exact value |
| --- | --- |
| `kSecClass` | `kSecClassGenericPassword` |
| `kSecAttrService` | Fixed service string |
| `kSecAttrAccount` | Key's derived physical account |
| `kSecAttrSynchronizable` | `requiredCFBoolean(false)` (`kCFBooleanFalse!`) |
| `kSecUseDataProtectionKeychain` | `requiredCFBoolean(true)` (`kCFBooleanTrue!`) |

`kSecUseDataProtectionKeychain = true` is supplied on every operation. Apple
documents that it selects the iOS-style Data Protection Keychain on macOS, is
safe on other platforms, and avoids enabling iCloud synchronization.

`kSecAttrSynchronizable = false` is explicit on every identity query. The
service never uses `kSecAttrSynchronizableAny`, so it cannot accidentally
read, update, or remove a separately created synchronizable item.

The service intentionally omits `kSecAttrAccessGroup`. Apple then assigns a
new item to the app's default access group. For copy, update, and delete,
omission searches across every access group the signed process is authorized
to use; it does not itself constrain matching to the default group. The
no-extra-groups source, project, signature, and release invariant below is
therefore a safety property of every mutation, not merely a packaging
preference. With only the default group authorized, all four operations remain
confined to the app-private group derived from the signed application
identifier.

Every Core Foundation Boolean placed in a dictionary is obtained through one
nonoptional helper with this exact construction:

```swift
private func requiredCFBoolean(_ value: Bool) -> CFBoolean {
    value ? kCFBooleanTrue! : kCFBooleanFalse!
}
```

The executor uses `requiredCFBoolean(true)` for
`kSecUseDataProtectionKeychain` and `kSecReturnData`, and
`requiredCFBoolean(false)` for `kSecAttrSynchronizable`. It never inserts an
optional `CFBoolean`, Swift `Bool`, or a separately constructed `NSNumber`.
Executor tests inspect each stored object's `CFGetTypeID` and `CFBoolean`
value, so source-level equality or bridgeable truthiness is insufficient. The
helper and those tests must compile with Swift and Clang warnings as errors.

No operation includes authentication prompt text, `SecAccessControl`,
biometric flags, `kSecUseAuthenticationUI`, a persistent reference, an item
reference, a label, or a comment.

### Copy query

The copy query is base identity plus:

| Query key | Exact value |
| --- | --- |
| `kSecReturnData` | `requiredCFBoolean(true)` (`kCFBooleanTrue!`) |
| `kSecMatchLimit` | `kSecMatchLimitOne` |

It requests neither attributes nor references. `SecItemCopyMatching` is called
once. On success the executor validates that the result is `CFData`, copies
its bytes into a new Swift `Data`, and returns only that copy.

### Update query and attributes

The update query is exactly the base identity and contains no return-result
keys. The attributes-to-update dictionary is exactly:

| Attribute key | Exact value |
| --- | --- |
| `kSecValueData` | Proposed Data |
| `kSecAttrAccessible` | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |

Updating accessibility together with the bytes means every successful set
reasserts the selected protection policy. Neither a primary-key attribute nor
synchronizability is changed through the update dictionary.

### Add attributes

The add dictionary is base identity plus:

| Attribute key | Exact value |
| --- | --- |
| `kSecValueData` | Proposed Data |
| `kSecAttrAccessible` | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |

`SecItemAdd` requests no return value.

### Delete query

The delete query is exactly the base identity and contains no return-result
keys. Under the current no-extra-groups invariant the composite identity
selects at most one app-private item. Because an omitted group would make
delete search all authorized groups, adding even one additional group would
broaden this operation. All identity, collision, migration, and query
assumptions must be redesigned before enabling that capability.

## Read Algorithm

`data(for:)` follows this exact sequence:

1. Call `Task.checkCancellation()`.
2. Await one executor copy call.
3. If the executor returns `.data(data)`, return its copied Data immediately.
4. If it returns `.invalid`, throw `.invalidStoredData`.
5. If it returns `.status(errSecItemNotFound)`, return `nil`.
6. If it returns `.status(errSecSuccess)`, throw `.internalFailure` because the
   executor violated its success-result contract.
7. Map every other status through the exact table above.

There is no fallback query, synchronizable-any query, legacy macOS keychain
query, repair, deletion, or rewrite after an invalid result.

## Remove Algorithm

`remove(_:)` follows this exact sequence:

1. Call `Task.checkCancellation()`.
2. Await one executor delete call.
3. Return `true` for `errSecSuccess`.
4. Return `false` for `errSecItemNotFound`.
5. Map every other status through the exact table above.

There is no read-before-delete call. If cancellation occurs after the Security
call begins and deletion succeeds, the method returns `true`; it does not turn
a completed deletion into `CancellationError` with a post-success check.

## Bounded Set State Machine

Keychain has no atomic upsert. An update-first strategy avoids a read-before-
write race, but an item may disappear before update or appear before add. The
actor therefore uses this exact bounded convergence sequence:

```text
update #1
  success       -> return
  itemNotFound  -> add #1

add #1
  success       -> return
  duplicate     -> update #2

update #2
  success       -> return
  itemNotFound  -> add #2

add #2
  success       -> return
  duplicate     -> concurrentMutation
```

Any status not shown as a transition is terminal and maps immediately through
the operation-specific status rules. The algorithm never loops and makes at
most four Security calls. A duplicate from the second add means another writer
won both alternating races; the service throws `.concurrentMutation` rather
than retrying indefinitely.

Before every possible executor invocation, `KeychainService` calls
`Task.checkCancellation()`. The live executor repeats the cancellation check
immediately before its synchronous `SecItem` function call. This second check
closes the suspension window while a task waits for executor isolation.

There is no cancellation check after a successful update or add. Once Security
reports success, the mutation happened and the API reports success even if the
task became cancelled while that blocking call was in progress. A cancellation
observed before a later retry prevents that later Security call.

The state machine gives bounded last-successful-writer behavior, not a
transaction, compare-and-swap, or guarantee against another writer changing
the item immediately after return.

## Internal Executor and Security API Seam

The internal protocol carries only Sendable semantic inputs:

```swift
nonisolated
protocol KeychainSecItemExecuting: Sendable {
    func copy(
        service: String,
        account: String
    ) async throws -> KeychainSecItemCopyResult

    func update(
        service: String,
        account: String,
        data: Data
    ) async throws -> OSStatus

    func add(
        service: String,
        account: String,
        data: Data
    ) async throws -> OSStatus

    func delete(
        service: String,
        account: String
    ) async throws -> OSStatus
}

nonisolated
enum KeychainSecItemCopyResult: Equatable, Sendable {
    case data(Data)
    case invalid
    case status(OSStatus)
}
```

`SecurityKeychainSecItemExecutor` is an actor. Each method:

1. builds its `[CFString: Any]` dictionaries inside actor isolation;
2. performs its final cancellation check;
3. invokes exactly one synchronous closure from `KeychainSecurityAPI`;
4. copies or reduces the result to Data, invalid, or OSStatus; and
5. returns without retaining a dictionary, pointer, `CFTypeRef`, or `Any`.

There is no `await` between dictionary construction and the Security closure.
Core Foundation dictionaries and result pointers therefore stay synchronous
and executor-actor-local. They never cross an actor, task, or continuation
boundary.

`KeychainSecurityAPI` is an internal immutable, checked-`Sendable` closure
table. Every stored function type is explicitly `@Sendable`; the struct uses
synthesized `Sendable` conformance and never declares `@unchecked Sendable`:

```swift
nonisolated
struct KeychainSecurityAPI: Sendable {
    typealias CopyMatching = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus

    typealias Update = @Sendable (
        CFDictionary,
        CFDictionary
    ) -> OSStatus

    typealias Add = @Sendable (
        CFDictionary,
        UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus

    typealias Delete = @Sendable (CFDictionary) -> OSStatus

    let copyMatching: CopyMatching
    let update: Update
    let add: Add
    let delete: Delete
}
```

The live closures contain no captured mutable state, and every closure is
invoked synchronously within executor isolation. No Core Foundation argument
or pointer is retained after a closure returns. A production source guard
rejects `@unchecked Sendable` anywhere under
`AppTemplate/App/Services/Keychain`; test-only recorders do not justify
weakening a production conformance.

The live table is the only production location that references the four
global Security functions. Tests inject a closure table that snapshots the
query synchronously and returns controlled values. Because the injected
closures are `@Sendable`, every captured recorder is synchronized. The
preferred test shape is a checked-`Sendable` reference whose mutable snapshot
state is held in `Synchronization.Mutex`; every read and write uses
`withLock`. A plain captured array, dictionary, counter, or unsynchronized
class property is forbidden. This permits exact query tests without touching
a user's Keychain or introducing a data race into the test seam.

On a successful copy, the executor checks the Core Foundation type and makes
an owned byte copy before returning. After casting to `CFData`, it obtains the
length first. A zero length returns `.data(Data())` before asking
`CFDataGetBytePtr` for a pointer, because a valid empty `CFData` may have a nil
byte pointer. For a positive length, a nil byte pointer returns `.invalid`;
otherwise the executor copies exactly that many bytes into a new `Data`. Tests
cover the zero-length result explicitly and mutate a nonempty source
`NSMutableData` after another call to prove the returned Data does not alias
test-owned storage.

## Concurrency Contract

`KeychainKey`, `KeychainCodableKey`, errors, copy results, and protocol
contracts are Sendable. Both production layers are actors:

- `KeychainService` serializes its own state access and owns one operation's
  state machine across actor reentrancy;
- `SecurityKeychainSecItemExecutor` serializes individual blocking Security
  calls and contains all non-Sendable query state; and
- `InMemoryKeychainService` serializes its dictionary.

`KeychainSecurityAPI` is an immutable checked-`Sendable` value. Its live
closures capture no mutable state; fake closures may capture only a recorder
whose state is synchronized for every access. This closure-table rule does not
relax executor actor isolation for Core Foundation values.

Actor serialization does not make a multi-call set atomic. Awaiting the
executor permits reentrancy, and other processes or authorized code can bypass
the instance. The bounded retry sequence is required even when most callers
share one service.

There is no detached unstructured task, semaphore, `NSLock`, global queue,
global mutable cache, callback API, or synchronous bridge. Callers await the
service directly. The concrete service performs no work in its initializer;
creating live dependencies cannot access Keychain.

## In-Memory Service

```swift
actor InMemoryKeychainService: IKeychainService {
    init()

    func data(for key: KeychainKey) async throws -> Data?
    func set(_ data: Data, for key: KeychainKey) async throws
    func remove(_ key: KeychainKey) async throws -> Bool
}
```

The actor stores `[KeychainKey: Data]`. Every operation checks cancellation at
entry. `remove` returns the dictionary removal result, so its Bool semantics
match the live service. Protocol extensions provide identical String and
Codable behavior.

This implementation is deterministic process memory, not a Security-framework
emulator. It does not model device lock, entitlements, OSStatus, persistence,
backup, synchronization, access groups, size limits, or concurrency with
another process. Fault tests use the scripted executor rather than adding
failure knobs to the in-memory service.

Every preview and UI-test dependency graph receives a fresh instance. The test
factory retains exactly the injected instance. No static singleton or shared
preview secret exists.

## Application Composition

The Keychain cycle begins from the completed UserDefaults composition. The
final graph adds one property:

```swift
nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
    let appStateStorage: any IAppStateStorage
    let keychain: any IKeychainService
    let settings: SettingsDependencies
}
```

The live signature retains the preceding cycle's exact parameters and appends
the Keychain injection seam:

```swift
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
```

`live` stores `keychainService` as `keychain`. It does not read, seed, migrate,
or delete an item while building the graph.

`uiTesting(initialState:)` constructs a fresh `InMemoryKeychainService`.
`preview(...)` gains an injectable
`keychainService: any IKeychainService = InMemoryKeychainService()` parameter.
`test(...)` requires `keychainService: any IKeychainService` with no default.

No Feature dependency slice changes in this cycle. A later authentication or
session feature must define a semantic credential repository over domain
values and inject that narrower protocol into its ViewModel. Feature code must
not receive all of `AppDependencies`, build a `KeychainKey`, or depend directly
on `IKeychainService`.

## Compatibility, Versioning, and Migration

This is a new service with no template-owned legacy item and no startup
migration. It never enumerates all Keychain records, probes alternative service
names, searches the legacy file-based macOS Keychain, or deletes unknown data.

Raw and String keys have an implicit schema selected by their owner. An
incompatible change requires a new fixed logical name and explicit migration.

Codable migration is deliberate and transactional only at the application
sequence level:

1. Declare the old `KeychainCodableKey<OldValue>` with its old schema version.
2. Declare the new `KeychainCodableKey<NewValue>` with an incremented version.
3. Read the new key first; if present, it is authoritative.
4. Otherwise read the old key and map its value in product-owned code.
5. Set the new value and await success.
6. Only after successful new write, remove the old key.

Different schema versions have different physical accounts and can coexist,
so a failed new write leaves the old item intact. Removal failure after a
successful new write leaves both versions; the new-first rule keeps behavior
deterministic and cleanup can be retried. The generic service performs none of
these steps automatically because it cannot know product mapping or rollback
policy.

Schema versions are monotonically increasing positive integers per logical
Codable key. They describe encoded model compatibility, not app version or
database schema. A type rename with compatible Codable fields need not bump
the version; an incompatible representation change must.

Changing `AppTemplate`, logical account spelling, `.schema-` formatting,
synchronizability, access group, item class, or accessibility policy after
shipping is a storage migration and requires a separate design with fixtures
for every shipped identity.

The signing identity is also part of physical reachability even though this
service does not place it in a query. The migration-sensitive identity set
therefore includes the platform application identifier, App ID prefix, Team
ID, and bundle ID. On iOS/iPadOS the signed application-identifier entitlement
key is `application-identifier`; on macOS it is
`com.apple.application-identifier`. The App ID prefix embedded in that value
must not be assumed to equal `com.apple.developer.team-identifier` for every
legacy or transferred app.

A bundle-ID change, signing-team change, App ID prefix change, or team transfer
may change the default access group or the set of groups the new build can
reach. None is a transparent rename. Before such a release, the adopter must
design and test a platform-appropriate signed migration/continuity strategy
with the old and new identities and provisioning profiles; this generic
service neither discovers the old identity nor promises automatic access to
its items.

## Security and Privacy Contract

### Protection policy

Every successful set establishes
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Apple documents that the item
is accessible only while the device is unlocked and does not migrate to a new
device through restoration of another device's backup. This is appropriate for
foreground session secrets that should not roam.

The service is not suitable for a background task that must read while the
device is locked. Such a product requirement needs a separate review of
`AfterFirstUnlock` policy and threat trade-offs. The service also does not
require a passcode, user presence, Face ID, Touch ID, Secure Enclave, or an
application password.

Keychain encrypts stored password data, but the returned Data and decoded
values exist in ordinary process memory. The service cannot prevent callers,
debuggers, crash reporters, swap, copies, or logs outside this boundary from
exposing a value. Callers keep plaintext lifetime short and never interpolate
it into diagnostics.

Keychain is for small secrets such as credentials, tokens, or cryptographic
material appropriate to generic-password storage. It is not a general database
for documents, media, application state, navigation, preferences, caches, or
large blobs.

### Diagnostics and redaction

The service and executor define no `Logger` and emit no log. Public errors may
reveal only a fixed category and, for `.unexpectedStatus`, the numeric OSStatus.
They never carry or format:

- service or account;
- raw or decoded value;
- byte count or bytes;
- String content;
- Swift model type name;
- coding path;
- underlying Swift error or description;
- query dictionary or access-group value; or
- `SecCopyErrorMessageString` output.

Tests use sentinel metadata, payload, model names, coding paths, and underlying
error descriptions and assert none appears in `String(describing:)`, reflected
error output, or localized error text. Executor query snapshots are test-only
objects and must not be logged.

### App-private access and entitlements

No `kSecAttrAccessGroup` is supplied. For add, omission places the item in the
app's default group. For copy, update, and delete, omission permits matching
across all groups authorized by the process. This cycle is safe only while the
authorized set contains no group beyond the default application-identifier
group. Source and project inspection therefore require every item in the
following list to remain absent:

- Keychain Sharing capability;
- custom `keychain-access-groups` entitlement or entitlement source;
- App Group capability;
- `com.apple.security.application-groups` entitlement;
- entitlements file; or
- extension-sharing configuration.

Every bullet above must remain absent; the list names forbidden additions, not
requirements to create them. Project inspection also rejects additional
authorized-group build settings or capability metadata.

Signing may materialize the default group even though source and project files
contain no sharing configuration. Final signed-artifact inspection therefore
uses this exact rule:

- identify the platform application identifier from `application-identifier`
  on iOS/iPadOS and `com.apple.application-identifier` on macOS;
- `keychain-access-groups` may be absent, or it must be an array containing
  exactly one string equal to that platform application identifier;
- no second, wildcard, legacy, shared, or otherwise additional keychain group
  is permitted; and
- `com.apple.security.application-groups` must be absent.

A final signed-and-provisioned distribution artifact must contain the expected
platform application identifier. The absent application-identifier case is
accepted only for generic/ad-hoc compile evidence, never for the mandatory
runtime gate. If `keychain-access-groups` is present, the applicable platform
application-identifier key must also be present so equality can be proved.

The automatically signed singleton default group, platform application
identifier, and `com.apple.developer.team-identifier` are identity metadata,
not evidence that Keychain Sharing or App Groups were added. Conversely, a
singleton group with a value different from the applicable platform
application identifier fails the gate. An ad-hoc artifact that omits identity
entitlements remains compile/link evidence only and cannot satisfy the runtime
gate.

On macOS, Data Protection Keychain access depends on the host executable's
signed entitlements, provisioning, and user login context. Apple explicitly
notes that library code inherits the host process's access and that this
keychain is unavailable outside a user context.

An ad-hoc macOS build and an unsigned generic iOS build prove only that the
code compiles, links Security, and introduces no source/project sharing
configuration; an available ad-hoc signature is still checked by the exact
rule above. They are never accepted as evidence that Data Protection Keychain
operations work at runtime. Ordinary unit tests also make no such claim.

Before distribution, the adopter must run a separately identified
signed-and-provisioned integration gate using the final team, bundle ID,
profiles, app-like bundle, and a real user login context. That gate inspects the
final code-signing entitlements against the platform-specific identifier and
singleton-or-absent group rule, then exercises missing, add, read, update, and
remove on supported physical iPhone/iPad hardware and the signed macOS app. It
uses an isolated product test service/account and cleans it up explicitly.

If a product later needs an extension, companion app, shared group, iCloud
Keychain synchronization, background-locked access, biometric prompt, or
passcode-bound deletion, it must not toggle a capability around this service.
It requires a new design covering entitlement authorization, query identity,
migration, denial behavior, tests, and release validation.

### Privacy manifest

This cycle does not add `PrivacyInfo.xcprivacy`. The template's existing
distribution blocker remains: the adopter must create and validate a manifest
matching the final product and all SDKs. The Security Keychain API is not used
as a reason to invent a manifest declaration in the template. The release
review still covers secret purpose, retention, deletion, account logout,
backup, device transfer, and incident policy.

## Testing and Fault Seams

### No real SecItem calls in ordinary tests

No normal unit, composition, preview, or UI test invokes the live
`KeychainSecurityAPI`. Concrete-service tests inject a scripted
`KeychainSecItemExecuting`. Query-construction tests instantiate the real
executor with fake synchronous Security closures. The closures record a safe
snapshot and return controlled status/result values without calling Security.

No test creates a temporary real keychain item, relies on the developer's login
Keychain, deletes by a broad query, prompts for access, or assumes CI signing.
Runtime Data Protection Keychain coverage belongs only to the adopter gate
described above.

### Key and codec tests

Focused tests cover:

- raw and Codable fixed-name construction from nonisolated contexts;
- component validation, the reserved `.schema-` marker, and every exact fixed
  noninterpolating precondition message;
- positive schema-version precondition with its exact fixed message;
- exact raw account and derived `name.schema-<version>` accounts;
- different schema versions coexist and never address the same item;
- compile-negative rejection of reading a
  `KeychainCodableKey<FirstModel>` as `SecondModel`;
- Data pass-through without transformation;
- UTF-8 empty, Unicode, and invalid-byte behavior;
- Codable round trip for several unrelated Sendable models;
- fresh JSON encoder and decoder per call;
- encoding failure makes zero raw-service calls;
- decoding failure leaves stored bytes unchanged;
- codec-thrown cancellation remains `CancellationError`; and
- codec and error descriptions contain none of the sentinel secret metadata.

### Service state-machine tests

A scripted actor executor records semantic operation, fixed service, physical
account, and call order while returning statuses or suspending at controlled
barriers. Tests prove:

- read Data, invalid result, missing result, every mapped status, and unexpected
  status behavior;
- an injected `.status(errSecSuccess)` copy result throws exactly
  `.internalFailure` and makes no additional executor call;
- blank and NUL service namespaces fail with their exact fixed,
  noninterpolating precondition messages;
- remove returns true on success and false on absence;
- set update success uses one call;
- update-not-found then add success uses two calls;
- add duplicate then second update success uses three calls;
- second update not-found then second add success uses four calls;
- a second add duplicate throws `.concurrentMutation` after exactly four calls;
- every terminal status stops with no extra call;
- cancellation before the first call invokes nothing;
- cancellation while waiting between each retry prevents the next call;
- the live-executor-side cancellation check prevents a call after executor
  scheduling; and
- cancellation during a successful update, add, or delete is not converted by
  a post-success check.

Concurrent task tests drive many keys and one shared key through the scripted
executor. They assert bounded completion and valid call sequences, not a
nondeterministic final winner.

### Executor query tests

Tests inject `KeychainSecurityAPI` closures and synchronously snapshot only the
expected query fields. They prove:

- all four closure typealiases are explicitly `@Sendable`, the table has
  checked `Sendable` conformance, and a lock-protected recorder survives a
  concurrent stress run without unsynchronized mutation;
- all operations use generic-password class, exact service/account,
  synchronizable false, and Data Protection Keychain true;
- every Boolean query value satisfies
  `CFGetTypeID(value) == CFBooleanGetTypeID()` and `CFEqual` against the
  required `kCFBooleanTrue!` or `kCFBooleanFalse!` value, rather than merely
  bridging to an equal Swift value;
- no operation supplies access group, synchronization-any, prompt, access
  control, label, description, comment, or persistent reference;
- copy alone requests return Data and match-limit one;
- update's query has no return keys and its update attributes contain only
  Data and WhenUnlockedThisDeviceOnly;
- add contains Data and WhenUnlockedThisDeviceOnly and requests no result;
- delete contains only base identity;
- every executor method checks cancellation before its fake Security closure;
- each method invokes exactly one closure;
- success with nil or a wrong Core Foundation type returns `.invalid`;
- successful zero-length `CFData` returns `.data(Data())` even when its byte
  pointer is nil;
- non-success returns `.status` and ignores any result object; and
- successful returned Data is an owned copy that does not change when the fake
  source mutable bytes change later.

### In-memory and composition tests

Tests prove:

- missing, set, overwrite, read, and Bool removal semantics;
- fresh preview graphs do not share values;
- fresh UI-test graphs do not share values;
- the test and preview injection seams retain the exact supplied actor;
- live composition creates `KeychainService` without making a Security call;
- an injected live service is stored as `dependencies.keychain` unchanged;
- existing UserDefaults, AppState, LocalDatabase, remote, and settings
  composition behavior remains unchanged; and
- no Feature or ViewModel references the generic Keychain boundary.

Static source checks confine `SecItemCopyMatching`, `SecItemUpdate`,
`SecItemAdd`, and `SecItemDelete` to the live Security closure table. They also
reject logging, `kSecAttrSynchronizableAny`, `kSecAttrAccessGroup`, biometric or
prompt keys, file-based `SecKeychain` APIs, `@unchecked Sendable` in production
Keychain source, any interpolated Keychain precondition message, entitlement
or capability source changes, and direct Feature consumption. They require the
six exact fixed precondition literals and the `kCFBooleanTrue!` /
`kCFBooleanFalse!` helper construction. All focused and stress tests compile
and run with Swift and Clang warnings treated as errors.

## File Map

Expected implementation changes are:

```text
AppTemplate/
├── App/
│   ├── AppDependencies/
│   │   └── AppDependencies.swift
│   └── Services/
│       └── Keychain/
│           ├── IKeychainService.swift
│           ├── InMemoryKeychainService.swift
│           ├── KeychainKey.swift
│           ├── KeychainService.swift
│           ├── KeychainServiceError.swift
│           └── Internal/
│               ├── KeychainSecItemExecuting.swift
│               ├── KeychainSecurityAPI.swift
│               └── SecurityKeychainSecItemExecutor.swift
AppTemplateTests/
├── App/
│   ├── Composition/
│   │   └── AppDependenciesTests.swift
│   └── Services/
│       └── Keychain/
│           ├── Fixtures/
│           │   └── KeychainCodableTypeMismatchCompileFixture.swift
│           ├── InMemoryKeychainServiceTests.swift
│           ├── KeychainConvenienceTests.swift
│           ├── KeychainKeyTests.swift
│           ├── KeychainServiceTests.swift
│           └── SecurityKeychainSecItemExecutorTests.swift
└── TestSupport/
    └── Keychain/
        ├── KeychainServiceSpy.swift
        ├── KeychainTestModels.swift
        └── ScriptedKeychainSecItemExecutor.swift
README.md
docs/ARCHITECTURE.md
docs/CUSTOMIZATION.md
docs/RELEASE_CHECKLIST.md
```

The exact internal test-support split may combine small fixtures, but no
responsibility may cross the boundaries above. The Xcode project uses
filesystem-synchronized groups, and `import Security` links the SDK framework;
no package, project group, capability, entitlement, or deployment-setting edit
is required.

## Documentation Changes During Implementation

- `README.md` describes the app-private Data Protection Keychain boundary and
  no longer calls Keychain a future cycle.
- `docs/ARCHITECTURE.md` documents the Data-first protocol, service/executor
  actors, exact policy, bounded set state machine, and in-memory graph.
- `docs/CUSTOMIZATION.md` explains fixed service/account naming, raw versus
  String versus versioned Codable keys, explicit migration, semantic
  repository wrapping, and when this policy is insufficient.
- `docs/RELEASE_CHECKLIST.md` adds signed/provisioned Data Protection Keychain
  runtime validation, final-entitlement inspection, migration/retention/logout
  review, and a warning that ad-hoc builds are compile/link evidence only.

`docs/README.md` needs no change because its historical-document policy and
links remain correct. The UserDefaults design remains authoritative for launch
state; this document is authoritative only for the new secrets boundary.

## Scope Guard

Authorized production work is limited to:

- the new `App/Services/Keychain` boundary;
- adding `keychain` ownership and factory injection to `AppDependencies`;
- matching service, executor, codec, in-memory, composition, redaction, and
  scope tests;
- the compile-negative typed-key fixture;
- the four active documentation files listed above; and
- this specification and its later implementation plan.

Implementation must preserve all completed UserDefaults changes when editing
shared composition and documentation files.

No implementation change is authorized in:

- `AppState`, `AppStateStore`, any application-state persistence protocol or
  adapter, or its schema;
- SwiftData/local database implementation or models;
- networking implementation, adapters, monitors, requests, or models;
- Features, ViewModels, views, navigation, routers, previews, or UI-test
  source beyond dependency construction;
- packages, schemes, deployment targets, build settings, project-file
  structure, hosted automation, or signing configuration;
- entitlements, capabilities, or an entitlements file; or
- `PrivacyInfo.xcprivacy`.

`REGISTER_APP_GROUPS = YES` remains byte-for-byte unchanged.

## Explicitly Out of Scope

- Keychain Sharing, access-group configuration, App Groups, extensions,
  companion apps, or cross-team sharing;
- synchronizable/iCloud Keychain items or cross-device conflict policy;
- file-based macOS Keychain, `SecKeychain` APIs, ACLs, custom keychain files,
  daemons, or execution outside a user login context;
- Internet-password items, certificates, identities, asymmetric keys, Secure
  Enclave keys, or persistent references;
- biometrics, user presence, passcode-required policy, application passwords,
  prompt text, or LocalAuthentication integration;
- background access while the device is locked;
- enumeration, prefix deletion, delete-all, bulk migration, transactions,
  compare-and-swap, or an unbounded retry loop;
- default-bearing keys, property wrappers, Combine, observation, or change
  notifications;
- dynamic service names or account names derived from secrets, user IDs,
  server responses, localized text, or bundle metadata;
- a product authentication/session repository, real token, login/logout flow,
  authorization header adapter, or Feature consumer;
- general documents, application state, settings, caches, or large-blob
  storage;
- zeroization guarantees for Swift `Data`, `String`, Codable values, process
  memory, or caller copies;
- real `SecItem` calls from ordinary tests; and
- adding a privacy manifest before product-specific adoption review.

## Nine-Gate Final Verification Matrix

Every automated gate uses a unique Derived Data directory and result-bundle
path. Swift and Clang warnings are treated as errors. Every test result bundle
must report `Passed`, a nonzero executed-test count, and zero failed, skipped,
or expected-failure tests. Existing macOS UI-automation authorization remains
an environment prerequisite, not a reason to weaken a gate.

| Gate | Final verification | Keychain-specific evidence |
| ---: | --- | --- |
| 1 | Focused Keychain service, executor, codec, in-memory, and composition tests on macOS | Exact queries, status mapping, bounded retries, cancellation, redaction, and graph ownership pass without real SecItem calls |
| 2 | All unit tests on macOS | No regression across UserDefaults/AppState, database, networking, navigation, or Features |
| 3 | All unit tests on iPhone 17 / iOS 26.5 | Sendability, codecs, state machine, and in-memory behavior pass without real SecItem calls |
| 4 | All unit tests on iPad (A16) / iOS 26.5 | The same deterministic contract passes on iPadOS |
| 5 | Complete macOS scheme | Unit and UI behavior pass together; live service construction performs no Keychain access |
| 6 | Complete UI-test bundle on iPhone 17 / iOS 26.5 | UI-test launch uses fresh in-memory Keychain only |
| 7 | Complete UI-test bundle on iPad (A16) / iOS 26.5 | iPad UI-test launch uses fresh in-memory Keychain only |
| 8 | Generic/ad-hoc macOS Release build | Security imports compile/link warning-free; any available identity/group entitlements satisfy the platform-key and absent-or-singleton-default rule; no runtime Keychain claim or call |
| 9 | Unsigned generic iOS Release build with `CODE_SIGNING_ALLOWED=NO` | Security imports compile/link warning-free without capabilities, entitlements, project edits, or runtime claim |

After the nine builds/tests, deterministic source and artifact checks require:

- all live queries contain Data Protection Keychain true and synchronizable
  false;
- all query Booleans are physically nonoptional `CFBoolean` values produced by
  the required `kCFBooleanTrue!` / `kCFBooleanFalse!` helper;
- every add/update establishes WhenUnlockedThisDeviceOnly;
- access-group, synchronizable-any, biometric, prompt, persistent-reference,
  file-based Keychain, and logging APIs are absent;
- all four global `SecItem` calls are confined to the live closure table;
- all Security closure typealiases are `@Sendable`, production Keychain source
  contains no `@unchecked Sendable`, and test recorders synchronize every
  captured mutation;
- ordinary tests do not invoke any closure from that live table;
- no Feature or ViewModel references `IKeychainService`, `KeychainService`, or
  either key type;
- no entitlements file, Keychain Sharing or App Group capability, custom
  `keychain-access-groups`, `com.apple.security.application-groups`, or
  additional-group configuration was added to source or project files;
- any inspected signed `keychain-access-groups` value is absent or an exact
  singleton equal to `application-identifier` on iOS/iPadOS or
  `com.apple.application-identifier` on macOS, and no additional group or App
  Group is present;
- production Keychain preconditions use only the six exact fixed messages and
  contain no interpolation;
- `REGISTER_APP_GROUPS = YES` is unchanged;
- no `PrivacyInfo.xcprivacy` was added; and
- release documentation names the separate signed/provisioned runtime gate
  and explicitly rejects ad-hoc runtime evidence.

### Mandatory adopter gate

The automated matrix is necessary but insufficient for shipping Keychain.
Using the final product identity, the adopter must additionally:

1. Build and run a signed, provisioned app in a normal user context.
2. Inspect final app and archive entitlements using `application-identifier`
   on iOS/iPadOS and `com.apple.application-identifier` on macOS. Confirm that
   `keychain-access-groups` is absent or exactly a singleton containing that
   identifier, and that no additional keychain group or
   `com.apple.security.application-groups` value is present.
3. Exercise missing, add, read, update, and Bool remove using an isolated test
   key on supported physical iPhone/iPad devices and the signed macOS app.
4. Confirm locked-device and foreground availability match the product's real
   execution model.
5. Confirm logout, retention, device-transfer, backup, account recovery, and
   incident-response behavior with product/security owners.
6. Remove the integration test item and record the tested build, profile,
   platforms, and result.

An ad-hoc app, unsigned build, simulator-only run, command-line probe, or unit
test substitute does not satisfy this gate.

## Acceptance Criteria

Implementation is complete only when all of the following are true:

1. `IKeychainService` has exactly the async raw Data read/set/remove contract,
   and public remove returns Bool with success/absence semantics.
2. `KeychainKey` owns a validated fixed raw account, while
   `KeychainCodableKey<Value>` binds one Codable Sendable type to one positive
   schema and exact `.schema-<version>` physical account.
3. UTF-8 String and direct-JSON Codable conveniences share the raw protocol,
   use fresh codecs, preserve cancellation, and never mutate after a codec
   failure.
4. Public errors and every Security status follow the exact mapping in this
   design without leaking service, account, payload, codec details, or
   underlying errors; an impossible copy `.status(errSecSuccess)` maps exactly
   to `.internalFailure`.
5. Every operation targets generic-password Data Protection Keychain with
   synchronizable false and no explicit access group.
6. Every successful add or update establishes
   WhenUnlockedThisDeviceOnly; no synchronizable, shared, biometric, prompt,
   background, or file-based fallback exists.
7. Reads make one copy call and return copied Data/nil/typed error; remove makes
   one delete call and returns true/false/typed error.
8. Set implements only update-add-update-add, checks cancellation before every
   possible call, treats the second duplicate as `.concurrentMutation`, and
   performs no post-success mutation check.
9. The live executor keeps all CF dictionaries, pointers, and Any values
   synchronous and actor-local and returns only copied Data, invalid, or
   status; valid zero-length `CFData` returns empty Data before pointer
   validation.
10. `KeychainSecurityAPI` uses only explicitly `@Sendable` closure properties
    and checked `Sendable` conformance, production Keychain source contains no
    `@unchecked Sendable`, and every injected recorder synchronizes mutation.
11. Every query Boolean is a nonoptional physical `CFBoolean` obtained from the
    exact forced system constants and is verified with warnings as errors.
12. No ordinary test calls a real `SecItem` function; exact dictionaries are
    verified through injected synchronous fake Security closures.
13. Preview and UI-test graphs own fresh in-memory services, while live and
    test injection retain the exact supplied service without eager access.
14. `AppDependencies` exposes the low-level service only at the app graph; no
    Feature consumes it until a semantic repository is independently designed.
15. Codable schema migration is explicit, new-first, and old-remove-after-new-
    success; there is no startup scan or automatic destructive migration.
16. The migration contract treats the platform application identifier, App ID
    prefix, Team ID, bundle ID, and team transfer as identity-sensitive and
    never promises transparent access after any of them changes.
17. No capability, custom entitlement, entitlements file, privacy manifest,
    package, project setting, or project membership change is introduced.
18. A signed `keychain-access-groups` value is absent or exactly the singleton
    default application identifier for its platform; source/project files add
    no sharing or App Group configuration, and signed artifacts contain no
    additional group.
19. All Keychain component preconditions use the six exact fixed,
    noninterpolating messages required by this design.
20. Ad-hoc and unsigned builds are described only as compile/link and
    source/project sharing-configuration evidence; any available signature is
    evaluated with the absent-or-singleton-default rule, and signed/provisioned
    runtime validation remains a mandatory adopter gate.
21. Focused, full, cross-platform, compile-negative, source-guard, release, and
    UI verification passes with warnings as errors and no failed, skipped,
    expected-failure, or zero-test result accepted as green.
22. The final diff contains only authorized Keychain implementation, tests,
    plan, and documentation changes and preserves completed UserDefaults work.

## Primary Apple References

- [Keychain items](https://developer.apple.com/documentation/security/keychain-items)
  describes encrypted password data, searchable attributes, and the SecItem
  add/search/update/delete surface.
- [TN3137: On Mac keychains](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)
  distinguishes file-based and Data Protection Keychains, recommends the
  latter, and documents signed entitlement and user-context constraints.
- [`kSecUseDataProtectionKeychain`](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain)
  selects iOS-style behavior on macOS without enabling synchronization and is
  safe to use across platforms.
- [`kSecClassGenericPassword`](https://developer.apple.com/documentation/security/ksecclassgenericpassword)
  defines applicable attributes and the composite primary key.
- [Adding a password to the keychain](https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain)
  demonstrates Data values, query construction, status checking, and the
  generic-password choice when Internet attributes are unnecessary.
- [Searching for keychain items](https://developer.apple.com/documentation/security/searching-for-keychain-items)
  and [item return result keys](https://developer.apple.com/documentation/security/item-return-result-keys)
  define return-Data and result-shape behavior.
- [Updating and deleting keychain items](https://developer.apple.com/documentation/security/updating-and-deleting-keychain-items)
  defines update/delete status handling and the need to qualify mutations.
- [`SecItemUpdate`](https://developer.apple.com/documentation/security/secitemupdate(_:_:))
  and [`SecItemDelete`](https://developer.apple.com/documentation/security/secitemdelete(_:))
  document blocking behavior and async/background execution guidance.
- [`kSecAttrSynchronizable`](https://developer.apple.com/documentation/security/ksecattrsynchronizable)
  defines false/absent nonsynchronizable behavior and incompatibility between
  synchronization and ThisDeviceOnly accessibility.
- [Restricting keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)
  explains lock-state protection, backup transfer, background trade-offs, and
  selecting the most restrictive usable policy.
- [`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
  defines unlocked-only access and nonmigration to another device.
- [Sharing access to keychain items among a collection of apps](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
  defines the private default access group, explicit sharing entitlements, and
  omission of `kSecAttrAccessGroup`.
- [`errSecDuplicateItem`](https://developer.apple.com/documentation/security/errsecduplicateitem),
  [`errSecItemNotFound`](https://developer.apple.com/documentation/security/errsecitemnotfound),
  and [Security Framework result codes](https://developer.apple.com/documentation/security/security-framework-result-codes)
  define the statuses interpreted by this design.
