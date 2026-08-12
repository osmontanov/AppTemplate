# Typed UserDefaults Service Design

## Status

The user approved this design through the preceding design review on
2026-08-12 and instructed work to continue without another confirmation gate.
This document is the normative input to the implementation plan.

This is an independent persistence cycle after the generic SwiftData local
database. It replaces only the raw `UserDefaults` access inside
`UserDefaultsAppStateStorage`; it does not merge application state into the
local database or introduce another product feature.

## Goal

Add a synchronous, typed, namespace-owning `UserDefaultsService` that:

- makes missing values explicit as `nil` rather than a type-specific fallback;
- rejects a stored physical type that does not match its typed key;
- distinguishes invalid storage from encoding and decoding failures;
- confines raw `UserDefaults` access behind one lock-protected service;
- supports the native scalar/value types the template needs and a JSON-backed
  `Codable` escape hatch;
- preserves the shipped `AppTemplate.AppState` record byte-for-byte; and
- remains a low-level app service rather than a Feature dependency or secrets
  store.

The service remains synchronous because its first consumer is the small
bootstrap record that must be read before the initial application root is
selected. Successful mutation means Foundation accepted/enqueued the
`UserDefaults` change. It does not mean the bytes have been synchronously
flushed to disk.

## Current Baseline

`UserDefaultsAppStateStorage` currently holds `UserDefaults` directly, uses the
fixed string `AppTemplate.AppState`, and stores raw JSON `Data` produced by
`AppStateStore`. Its contract is:

```swift
nonisolated
protocol IAppStateStorage: Sendable {
    func load() throws -> AppStateStorageLoadResult
    func save(_ data: Data) throws
    func remove() throws
}
```

`AppStateStore` owns `AppState` encoding, schema inspection, recovery, and
future-schema preservation. The storage adapter owns only the three-state
physical result: missing, raw `Data`, or invalid value.

The existing behavior that this design must preserve is:

- missing `AppTemplate.AppState` loads `AppState.initial` without a write;
- raw `Data` is passed to `AppStateStore` unchanged;
- a non-`Data` value is reported as `.invalidValue`;
- corrupt or old unsupported app-state JSON is repaired by `AppStateStore`;
- future-schema JSON is preserved and makes the store read-only;
- preview and UI-test graphs use `InMemoryAppStateStorage`; and
- no credential, token, navigation path, pending intent, or selected root is
  stored in this record.

## Selected Direction and Rejected Alternatives

The selected design is a generic service protocol plus a typed key that owns a
fixed logical name and codec. This gives primitive values their native
property-list representation while allowing a deliberate `Codable` key to use
raw JSON `Data`.

Two alternatives were rejected:

1. Type-specific service overloads such as `bool(for:)` and `setBool` would
   repeat the surface, make semantic keys plain strings, and reproduce
   Foundation's missing-value ambiguity.
2. A Codable-only service would turn every scalar into opaque `Data`, lose the
   native representation useful for existing defaults, and obscure physical
   compatibility checks.

A three-state generic read result was also rejected. The protocol returns
`Value?`: absence is `nil`, and a present but incompatible raw representation
throws `UserDefaultsServiceError.invalidStoredValue`.

## Responsibility Split

| Component | Owns | Must not own |
| --- | --- | --- |
| `UserDefaultsKey<Value>` | One fixed logical name, expected physical kind, and typed codec | Namespace, default value, backing store, synchronization, migration |
| `IUserDefaultsService` | The synchronous generic consumer contract | App-state schema or Feature semantics |
| `UserDefaultsService` | Namespace composition, locked raw access, physical validation, replacement behavior | Feature keys, default values, JSON schema policy, logging |
| `UserDefaultsEncodedValue` | A closed `Sendable` bridge between raw access and codecs | Public API or arbitrary property-list graphs |
| `UserDefaultsAppStateStorage` | Mapping the generic service to `AppStateStorageLoadResult` | AppState JSON encoding/decoding, schema recovery, logging |
| `AppStateStore` | AppState JSON, schema validation, recovery, and persistence status | Raw `UserDefaults` access |
| `AppDependencies.live()` | Defaulting and injecting the live namespaced service into the adapter | Storing the generic service as a graph property or exposing it to Features |

This split keeps the low-level service reusable without changing the semantic
application-state boundary that existing callers and tests use.

## Public Contract

All declarations are explicitly `nonisolated` because the project uses
MainActor default isolation.

```swift
nonisolated
protocol IUserDefaultsService: Sendable {
    func value<Value: Sendable>(
        for key: UserDefaultsKey<Value>
    ) throws -> Value?

    func set<Value: Sendable>(
        _ value: Value,
        for key: UserDefaultsKey<Value>
    ) throws

    func remove<Value: Sendable>(
        _ key: UserDefaultsKey<Value>
    )
}
```

The methods are synchronous. `remove(_:)` is nonthrowing because the closed
implementation performs only Foundation's nonthrowing removal operation; a
missing value is a successful no-op. `set(_:for:)` remains throwing because a
Codable key can fail while encoding before any raw mutation. `value(for:)`
remains throwing because physical validation or decoding can fail.

The exact public error is:

```swift
nonisolated
enum UserDefaultsServiceError: Error, Equatable, Sendable {
    case invalidStoredValue
    case encodingFailed
    case decodingFailed
}
```

The cases have no associated payload. The service does not expose the
namespace, logical or physical key, stored value, proposed value, encoded
bytes, underlying error, error description, or coding path. It emits no log.
This makes errors deliberately redacted and stable for equality-based tests.

The error rules are exact:

- no object for the physical key returns `nil`;
- an object with the wrong physical representation throws
  `.invalidStoredValue`;
- any error thrown while encoding a Codable value becomes `.encodingFailed`;
- any error thrown while decoding JSON `Data` becomes `.decodingFailed`;
- an encoding failure leaves an existing stored object untouched;
- a decoding or invalid-value failure does not repair, remove, or rewrite the
  stored object; semantic adapters decide whether recovery is appropriate.

## Typed Keys

The key declaration is:

```swift
nonisolated
struct UserDefaultsKey<Value: Sendable>: Sendable {
    // No public or internal untyped construction path.
}
```

It exposes these factories through constrained extensions:

```swift
extension UserDefaultsKey where Value == Bool {
    static func bool(_ name: String) -> Self
}

extension UserDefaultsKey where Value == Int {
    static func int(_ name: String) -> Self
}

extension UserDefaultsKey where Value == Float {
    static func float(_ name: String) -> Self
}

extension UserDefaultsKey where Value == Double {
    static func double(_ name: String) -> Self
}

extension UserDefaultsKey where Value == String {
    static func string(_ name: String) -> Self
}

extension UserDefaultsKey where Value == Data {
    static func data(_ name: String) -> Self
}

extension UserDefaultsKey where Value == Date {
    static func date(_ name: String) -> Self
}

extension UserDefaultsKey where Value: Codable {
    static func codable(_ name: String) -> Self
}
```

The native factories store `Bool`, `Int`, `Float`, `Double`, `String`, `Data`,
and `Date` in their native property-list representations. `.codable` always
encodes the value as JSON and stores that JSON as raw `Data`, even if `Value`
also has a native factory. For example, `.data("Blob")` stores the supplied
bytes directly, while a hypothetical `UserDefaultsKey<Data>.codable("Blob")`
stores JSON representing those bytes. A logical key must choose one factory
for its lifetime.

Every factory preconditions that `name` contains at least one character after
trimming `CharacterSet.whitespacesAndNewlines`. The service initializer applies
the same precondition to `namespace`. Validation does not normalize or trim a
valid component; the supplied spelling remains stable. Empty and
whitespace-only components are programmer errors, not runtime storage errors.

The key stores no default value. Production call sites declare fixed keys as
constants and do not derive a key name from user-controlled or remote data.
The only key introduced in this cycle is:

```swift
private static let appStateKey: UserDefaultsKey<Data> = .data("AppState")
```

The key's logical name is `AppState`; the live service's namespace is
`AppTemplate`; the exact physical key is therefore `AppTemplate.AppState`.

## Internal Codec Boundary

The implementation uses a closed internal `Sendable` value rather than
allowing `Any`, `NSNumber`, `NSData`, or another non-Sendable Foundation object
to cross out of the lock-protected raw-access section:

```swift
nonisolated
enum UserDefaultsEncodedValue: Sendable {
    case bool(Bool)
    case int(Int)
    case float(Float)
    case double(Double)
    case string(String)
    case data(Data)
    case date(Date)
}
```

An internal physical-kind enum distinguishes the cases without carrying a
value. A key stores its logical name, expected physical kind, and two
`@Sendable` closures that map `Value` to and from
`UserDefaultsEncodedValue`. The initializer that assembles these pieces is
private to `UserDefaultsKey`; callers use only the typed factories.

Primitive codecs are total after physical validation. Codable codecs create a
fresh default-configured `JSONEncoder` for every `set` and a fresh
default-configured `JSONDecoder` for every successful physical `Data` read.
Encoder and decoder instances are never cached or shared. This avoids mutable
codec state crossing operations and ensures user-written `Codable` code runs
outside the raw-access lock.

The service catches every Codable codec error at this boundary and replaces it
with the corresponding redacted `UserDefaultsServiceError`. It never exposes
an underlying `EncodingError`, `DecodingError`, or user-thrown error.

## Concrete Service and Physical Semantics

The concrete shape is:

```swift
nonisolated
final class UserDefaultsService:
    IUserDefaultsService,
    @unchecked Sendable
{
    private let namespace: String
    private let userDefaults: UserDefaults
    private let lock: NSLock

    init(
        namespace: String,
        userDefaults: UserDefaults = .standard
    )
}
```

`UserDefaults` is injectable so tests can use a unique suite. The live graph
uses `.standard`. There is no suite-name, App Group, registration-domain, or
global singleton API on the service.

For every operation, the physical key is computed as:

```text
<namespace>.<logical name>
```

No case folding, escaping, hashing, localization, bundle-identifier lookup, or
other transformation occurs.

### Reading

`value(for:)` follows this order:

1. Compute the physical key from the already validated fixed components.
2. Acquire the private `NSLock`.
3. Call `object(forKey:)` exactly once.
4. If absent, release the lock and return `nil`.
5. Validate the raw object's physical representation against the key and copy
   it into `UserDefaultsEncodedValue` while still holding the lock.
6. Release the lock.
7. Run the key's typed decoder. Codable user code therefore cannot execute
   under the lock.

The implementation does not call `bool(forKey:)`, `integer(forKey:)`, or the
other fallback-returning typed getters because they collapse missing and
incompatible values.

### Strict numeric representations

Foundation bridges Boolean and numeric defaults through `NSNumber`, so Swift
casts alone are not sufficient. Numeric validation uses Core Foundation type
APIs and compares against symbolic constants rather than hard-coded type-ID or
raw enum numbers:

| Key factory | Required raw representation |
| --- | --- |
| `.bool` | `CFGetTypeID(raw) == CFBooleanGetTypeID()` |
| `.int` | `CFGetTypeID(raw) == CFNumberGetTypeID()`, `CFNumberIsFloatType(...) == false`, and exact conversion to native `Int` succeeds |
| `.float` | `CFGetTypeID(raw) == CFNumberGetTypeID()` and `CFNumberGetType(...) == .float32Type` |
| `.double` | `CFGetTypeID(raw) == CFNumberGetTypeID()` and `CFNumberGetType(...) == .float64Type` |

The Int rule deliberately does not require one `CFNumberType`: Core Foundation
may choose a suitable internal integer representation. After excluding
`CFBoolean` and every floating-point `CFNumber`, conversion uses
`Int(exactly:)` so an out-of-range integer representation is invalid rather
than truncated. A Boolean is never accepted as integer zero/one; an integer is
never accepted as a Boolean; and equal-valued `Float` and `Double` objects are
not interchangeable. The macOS, iPhone, and iPad tests characterize and
enforce these representations for the supported Xcode 26.6 toolchain.

String, Data, and Date validation uses the corresponding Foundation bridge and
copies the result into the matching Swift value. Arrays, dictionaries, URLs,
and every unsupported object are invalid for all factories in this design.
Codable keys require physical `Data` before JSON decoding begins.

### Setting and equal cross-type replacement

`set(_:for:)` first runs the key's encoder without holding the service lock. If
encoding throws, the operation returns `.encodingFailed` and has performed no
raw read, removal, or write.

After successful encoding, the service acquires the lock and performs the
complete raw mutation sequence under that one lock:

1. Read the existing object for the physical key.
2. If an object exists and its physical representation is incompatible with
   the encoded value's kind, remove it with `removeObject(forKey:)`.
3. Write the encoded value using the matching typed `UserDefaults.set`
   overload or property-list value.
4. Release the lock and return.

The explicit removal is mandatory. Foundation may treat numerically equal
`NSNumber` values as an unchanged assignment even when their representations
differ. Without removal, writing `Double(1.25)` over `Float(1.25)`, `Int(1)`
over `Bool(true)`, or the reverse can leave the old representation behind and
make the typed read fail. Removing an incompatible representation first makes
each cross-type replacement round-trip through its new key type.

Compatible assignments do not remove first. Removal and set are atomic only
with respect to callers sharing this service instance; this design does not
claim a transactional Foundation write or coordination with bypassing code.

### Removing and synchronization meaning

`remove(_:)` acquires the same lock, calls `removeObject(forKey:)`, and
releases the lock. It does not inspect or decode the existing representation.

Every raw access—read, compatibility read, set, and removal—occurs while the
private lock is held. No codec closure or user-supplied Codable implementation
runs while the lock is held. The lock is never exposed, and the implementation
does not depend on reentrancy.

The service never calls `synchronize()`. Apple deprecates it as unnecessary.
Return from `set` or `remove` means the mutation was accepted/enqueued by the
`UserDefaults` API, not fsynced to persistent media. Documentation must not
describe `AppStateMutationResult.persisted` as an fsync guarantee; its
application-level meaning remains that the synchronous storage boundary
accepted the mutation before in-memory policy changed.

## Concurrency Contract

`IUserDefaultsService`, `UserDefaultsKey`, encoded values, and errors are
`Sendable`. `UserDefaultsService` is a nonisolated final class with an explicit
`@unchecked Sendable` conformance justified by these invariants:

- `namespace`, `userDefaults`, and `lock` are immutable references after init;
- the same private `NSLock` protects every raw access to that `UserDefaults`
  instance through the service;
- no raw Foundation object leaves the critical section;
- all values that leave the critical section are cases of the closed
  `Sendable` encoded-value enum;
- codecs run only before acquiring or after releasing the lock; and
- there is no mutable shared encoder, decoder, cache, registry, or observer.

The lock prevents races among callers of one service instance. It does not
coordinate independently created service instances, direct `UserDefaults`
callers, another process, an extension, or an App Group member. The service
does not observe external changes and does not promise compare-and-swap,
multi-key transactions, ordering across processes, or notification delivery.

## AppState Integration

`UserDefaultsAppStateStorage` keeps conforming to `IAppStateStorage`, but its
dependency becomes `any IUserDefaultsService` rather than raw `UserDefaults`:

```swift
nonisolated
struct UserDefaultsAppStateStorage: IAppStateStorage, Sendable {
    private static let appStateKey: UserDefaultsKey<Data> = .data("AppState")
    private let userDefaults: any IUserDefaultsService

    init(userDefaults: any IUserDefaultsService)
}
```

The adapter behavior is exact:

- `value(for: .data("AppState")) == nil` maps to `.missing`;
- returned `Data` maps to `.data(data)` without mutation or re-encoding;
- `UserDefaultsServiceError.invalidStoredValue` maps to `.invalidValue`;
- every other thrown error propagates unchanged;
- `save(_:)` forwards the supplied bytes to `set(_:for:)` unchanged; and
- `remove()` delegates to nonthrowing `remove(_:)` while preserving the
  existing throwing `IAppStateStorage` signature.

The adapter does not use `.codable("AppState")`. `AppStateStore` continues to
own JSON encoding, decoding, schema inspection, repair, and future-schema
protection. `AppState`, `AppStateStore`, `IAppStateStorage`,
`AppStateStorageLoadResult`, and `InMemoryAppStateStorage` do not change.

The live composition is:

```swift
static func live(
    localDatabaseStoreLocationResolver:
        LocalDatabaseStoreLocationResolver = .live(),
    userDefaultsService: any IUserDefaultsService = UserDefaultsService(
        namespace: "AppTemplate"
    )
) -> AppDependencies
```

The factory constructs `UserDefaultsAppStateStorage(userDefaults:
userDefaultsService)`. This injection-only parameter mirrors the existing
live local-database resolver seam and makes composition tests deterministic.
It is consumed while building the adapter and is not retained separately.

`AppDependencies` retains only `appStateStorage: any IAppStateStorage`. It does
not gain an `IUserDefaultsService` property, accessor, or Feature-facing
dependency. Preview and UI-test composition keeps constructing fresh
`InMemoryAppStateStorage` values and never opens `UserDefaults`.

## Compatibility and Migration

This refactor has no data migration:

- the physical key remains exactly `AppTemplate.AppState`;
- the physical value remains raw `Data`;
- existing bytes are returned byte-for-byte;
- save forwards the existing `AppStateStore` JSON bytes byte-for-byte;
- `AppState.currentSchemaVersion` remains `1`;
- no existing AppState payload is eagerly read and rewritten;
- no registration default is introduced; and
- no fallback key, legacy alias, dual write, or cleanup pass is introduced.

An existing raw Data value must survive adapter construction and load
unchanged, including corrupt, old-schema, and future-schema JSON. Existing
`AppStateStore` behavior alone decides whether to repair current/old invalid
content or preserve a future schema. A physically non-Data value still maps to
`.invalidValue`, so the current semantic recovery path is unchanged.

The service is source-additive, but the adapter's raw-`UserDefaults`
initializer is intentionally replaced. There is no deprecated forwarding
initializer because production has one composition site and tests should
exercise the new boundary directly.

## Security, Privacy, and Entitlements

The service stores only nonsensitive app-private settings. It is not suitable
for passwords, credentials, authentication tokens, private keys, regulated or
personal content, or any other secret. Those require a separately designed
Keychain boundary and product-specific data policy. Neither a Keychain service
nor a secret consumer is added here.

No value, key, namespace, payload, or underlying error is logged. The service
defines no logger. Existing `AppStateStore` category-only recovery logging
remains unchanged and payload-free.

The project currently contains `REGISTER_APP_GROUPS = YES` in the app target's
Debug and Release build settings. In this project that setting is Xcode
automatic-provisioning/profile bookkeeping; it is not itself the
`com.apple.security.application-groups` entitlement and does not authorize
shared-container access. This work leaves the setting unchanged.

The finished source and built products must have no
`com.apple.security.application-groups` entitlement. The live service uses
`.standard`, no group suite is named, and no App Group capability or
entitlements file is added. If a future product needs sharing with an app
extension or another app, that is a separate design with an explicit
entitlement, suite, process-coordination policy, tests, and the appropriate
privacy-manifest reason.

The template still intentionally has no `PrivacyInfo.xcprivacy`; distribution
therefore remains blocked until the adopter supplies and validates a
product-specific manifest. The implementation updates release documentation
to require `NSPrivacyAccessedAPICategoryUserDefaults` and an applicable
approved reason. For the app-private standard-defaults behavior in this
design, Apple's `CA92.1` reason is the expected example. The final adopter must
revalidate the reason against the shipped product and every included SDK. This
cycle does not add a privacy manifest.

## Testing and Fault Seams

### Service and key tests

Tests inject a unique `UserDefaults(suiteName:)` into each concrete service and
remove that persistent domain during cleanup. They never mutate
`UserDefaults.standard`. Direct writes through the isolated backing object are
the deliberate physical-corruption seam; no production storage-backend
protocol or public test hook is added.

Focused tests cover:

- fixed-name construction and the shared nonblank component validator used by
  the namespace and key preconditions;
- missing `nil`, set/read round trip, replacement, and removal for Bool, Int,
  Float, Double, String, raw Data, and Date;
- Codable round trip with JSON stored physically as raw Data;
- a throwing Encodable maps to `.encodingFailed` and leaves prior bytes
  unchanged;
- malformed JSON Data for a Codable key maps to `.decodingFailed` and remains
  unchanged;
- every wrong physical representation maps to `.invalidStoredValue` and
  remains unchanged;
- strict Core Foundation recognition of Bool, Int, Float, and Double;
- a direct Boolean seed is not readable as Int, and a direct integer seed is
  not readable as Bool;
- equal-valued Float-to-Double, Double-to-Float, Bool-to-Int, Int-to-Bool, and
  integer/floating replacements remove the old representation and round-trip
  through the new key type;
- compatible same-kind replacement remains correct;
- Codable encoder/decoder instances are fresh per call;
- many concurrent synchronous calls through one shared service complete
  without data races or invalid intermediate values; and
- `UserDefaultsServiceError` descriptions contain no sentinel namespace, key,
  value, bytes, coding path, or underlying error description.

The factories' closed encoded-value mapping is tested directly under
`@testable import` where useful. Tests do not add a general arbitrary-codec
factory to production API.

### Adapter and compatibility tests

`UserDefaultsAppStateStorageTests` use both an `IUserDefaultsService` spy and a
real service over an isolated suite. They prove:

- the adapter requests the fixed `.data("AppState")` key;
- missing, Data, invalid physical type, save, and removal map exactly as
  specified;
- only `.invalidStoredValue` maps to `.invalidValue`;
- `.encodingFailed`, `.decodingFailed`, and a non-service sentinel error
  propagate unchanged;
- a preexisting byte sentinel at `AppTemplate.AppState` loads byte-for-byte;
- save writes those exact bytes under `AppTemplate.AppState` with raw Data
  representation; and
- wrong physical type behavior remains `.invalidValue`.

The generic protocol spy is lock-protected and records only fixed test
metadata; it supplies deterministic missing, value, and thrown-error results.
This is the adapter's failure-injection seam. The concrete service needs no
synthetic raw-I/O failure seam because Foundation's operations in its closed
contract are nonthrowing.

Existing `AppStateStore` tests continue proving corrupt/old repair, future
schema preservation, and state-before-save ordering. One integration
regression seeds an existing current-schema AppState Data record through raw
UserDefaults, loads it through the new service and adapter, and confirms the
exact state and physical bytes. A future-schema regression confirms the bytes
remain untouched.

### Composition and scope tests

Composition tests continue proving:

- live dependencies expose `UserDefaultsAppStateStorage` only through
  `any IAppStateStorage`;
- preview and UI-test graphs use fresh `InMemoryAppStateStorage` instances;
- existing custom test/preview storage injection passes through unchanged;
- an injected live `IUserDefaultsService` is consumed only by the
  `UserDefaultsAppStateStorage` adapter;
- the generic UserDefaults service is not an `AppDependencies` property; and
- no Feature, ViewModel, preview, or UI-test path consumes
  `IUserDefaultsService` or `UserDefaultsService`.

Static checks confirm the service folder imports no OSLog module, contains no
`Logger` calls, exposes no default-value field, has no `synchronize()` call,
and contains no App Group suite or application-groups entitlement.

## File Map

Expected implementation changes are:

```text
AppTemplate/
├── App/
│   ├── AppDependencies/
│   │   └── AppDependencies.swift                       # live factory injection seam
│   ├── ApplicationState/
│   │   └── Persistence/
│   │       └── UserDefaultsAppStateStorage.swift       # semantic adapter
│   └── Services/
│       └── UserDefaults/
│           ├── IUserDefaultsService.swift              # generic protocol
│           ├── UserDefaultsEncodedValue.swift          # internal Sendable bridge
│           ├── UserDefaultsKey.swift                   # typed factories/codecs
│           ├── UserDefaultsService.swift               # namespace, lock, raw access
│           └── UserDefaultsServiceError.swift          # redacted error enum
AppTemplateTests/
├── App/
│   ├── ApplicationState/
│   │   └── Persistence/
│   │       └── UserDefaultsAppStateStorageTests.swift
│   ├── Composition/
│   │   └── AppDependenciesTests.swift
│   └── Services/
│       └── UserDefaults/
│           ├── UserDefaultsKeyTests.swift
│           └── UserDefaultsServiceTests.swift
└── TestSupport/
    └── UserDefaults/
        └── UserDefaultsServiceSpy.swift
README.md
docs/ARCHITECTURE.md
docs/CUSTOMIZATION.md
docs/RELEASE_CHECKLIST.md
```

The exact internal file split may combine the encoded enum with the concrete
service if that is clearer, but no responsibility may move across the
boundaries defined above. The Xcode project uses filesystem-synchronized
groups, so these Swift files do not require manual project membership edits.

## Documentation Changes During Implementation

- `README.md` replaces the future-service wording with a concise description
  of the typed app-private defaults boundary and retains the separate Keychain
  warning.
- `docs/ARCHITECTURE.md` documents key/codec/service ownership, the locked raw
  boundary, exact AppState adapter path, and accepted/enqueued—not
  fsynced—mutation meaning.
- `docs/CUSTOMIZATION.md` explains how to declare a fixed typed logical key,
  preserve namespaces after release, choose native versus Codable Data, avoid
  user-generated keys, and keep secrets out of UserDefaults.
- `docs/RELEASE_CHECKLIST.md` adds physical-key compatibility checks, strict
  App Group entitlement absence, and the product-specific
  `NSPrivacyAccessedAPICategoryUserDefaults` required-reason review, with
  `CA92.1` as the app-private example.

`docs/README.md` needs no change because its links and historical-record
policy remain accurate. Historical AppState designs remain evidence of the
schema and recovery rules; this specification is authoritative where their
raw adapter construction differs.

## Scope Guard

Authorized production work is limited to:

- the new `App/Services/UserDefaults` boundary;
- adapting `UserDefaultsAppStateStorage` to require
  `any IUserDefaultsService`;
- the injection-only `userDefaultsService` parameter and adapter construction
  in `AppDependencies.live()`;
- matching service, adapter, composition, and compatibility tests;
- the four active documentation files listed above; and
- this specification and its later implementation plan.

No implementation change is authorized in:

- `AppStateStore`, `AppState`, `IAppStateStorage`,
  `AppStateStorageLoadResult`, or `InMemoryAppStateStorage`;
- Features, ViewModels, views, navigation, flow policy, previews, or UI-test
  source;
- SwiftData/local database or networking;
- Keychain, credentials, tokens, or authentication implementation;
- packages, schemes, deployment targets, build settings, project-file
  structure, hosted automation, or signing configuration;
- entitlements or capabilities; or
- a privacy manifest.

`REGISTER_APP_GROUPS = YES` remains byte-for-byte unchanged in the project
file. The absence of `com.apple.security.application-groups` remains a required
security property.

## Explicitly Out of Scope

- App Groups, shared suites, app-extension sharing, or shared containers;
- cross-process locking, transactions, conflict resolution, or observation;
- `UserDefaults.didChangeNotification`, AsyncSequence, Combine, or Swift
  Observation integration;
- secrets, Keychain, encryption, access control, or biometric policy;
- feature-specific settings/repositories or any new Feature consumer;
- dynamic keys based on user IDs, server values, routes, or arbitrary input;
- key aliases, migrations, registration defaults, default-bearing keys, or
  property wrappers;
- URL, arrays, dictionaries, arbitrary property-list types, or untyped `Any`
  APIs;
- a generic service property in `AppDependencies` or Feature exposure;
- changes to AppState JSON, schema version, recovery, or logging;
- manual flush/fsync guarantees or `synchronize()`; and
- adding `PrivacyInfo.xcprivacy` before the adopter's product-specific review.

## Nine-Gate Final Verification Matrix

Every gate uses a unique Derived Data directory and result-bundle path. Swift
and Clang warnings are treated as errors. Every test result bundle must report
`Passed`, a nonzero executed-test count, and zero failed, skipped, or
expected-failure tests. Existing macOS UI-automation authorization remains an
environment prerequisite, not a reason to weaken a gate.

| Gate | Final verification | UserDefaults-specific evidence |
| ---: | --- | --- |
| 1 | Focused UserDefaults service, AppState persistence, AppStateStore, and composition tests on macOS | Typed representations, codec failures, byte compatibility, and live/in-memory ownership pass |
| 2 | All unit tests on macOS | No regression across application state, database, networking, navigation, or Features |
| 3 | All unit tests on iPhone 17 / iOS 26.5 | Native numeric representations and concurrency pass on iOS |
| 4 | All unit tests on iPad (A16) / iOS 26.5 | Native numeric representations and concurrency pass on iPadOS |
| 5 | Complete macOS scheme | Unit and UI behavior pass together with the live app build |
| 6 | Complete UI-test bundle on iPhone 17 / iOS 26.5 | UI-test launch remains isolated from live UserDefaults |
| 7 | Complete UI-test bundle on iPad (A16) / iOS 26.5 | iPad UI-test launch remains isolated from live UserDefaults |
| 8 | Generic macOS Release build | Release compiles warning-free; signed-app entitlement inspection has no application-groups entitlement |
| 9 | Unsigned generic iOS Release build with `CODE_SIGNING_ALLOWED=NO` | Release compiles warning-free without adding capabilities, entitlements, or a manifest |

After the nine builds/tests, deterministic source and artifact checks also
require:

- the only physical AppState key remains `AppTemplate.AppState`;
- no Feature or ViewModel references either generic defaults-service type;
- no `synchronize()`, service logging, App Group suite, or default-bearing key
  exists;
- `REGISTER_APP_GROUPS = YES` is unchanged in Debug and Release;
- source entitlements and available signed build entitlements contain no
  `com.apple.security.application-groups`;
- no `PrivacyInfo.xcprivacy` was added; and
- release documentation names
  `NSPrivacyAccessedAPICategoryUserDefaults` and the app-private `CA92.1`
  example while retaining the distribution blocker.

Distribution signing and archive validation remain separate adopter gates;
the unsigned generic iOS build is not evidence about an App Store profile.

## Acceptance Criteria

The implementation is complete only when all of the following are true:

1. `IUserDefaultsService` has exactly the synchronous generic read, set, and
   remove operations specified here and is explicitly nonisolated and
   Sendable.
2. `UserDefaultsKey<Value: Sendable>` has only the seven native factories and
   Codable-as-JSON-Data factory, validates nonblank fixed logical names, and
   stores no default value.
3. Missing values return `nil`; wrong physical representations throw
   `.invalidStoredValue`; encoding and decoding failures remain distinct and
   redacted.
4. Bool, Int, Float, and Double use the strict Core Foundation representation
   checks in this design, and equal cross-type replacement round-trips after
   mandatory incompatible-value removal.
5. `UserDefaultsService` is a nonisolated final `@unchecked Sendable` class
   whose private lock covers every raw access while every codec and user
   Codable call runs outside the lock.
6. Codable operations create fresh default JSON encoders/decoders per call;
   no raw `Any` or non-Sendable Foundation object leaves a critical section.
7. No implementation calls `synchronize()` or claims fsync durability; set
   and remove mean accepted/enqueued synchronous mutations.
8. `UserDefaultsAppStateStorage` requires `any IUserDefaultsService`, uses
   `.data("AppState")`, maps only `.invalidStoredValue` to `.invalidValue`, and
   propagates every other error.
9. `AppDependencies.live()` defaults an injection-only
   `userDefaultsService` parameter to
   `UserDefaultsService(namespace: "AppTemplate")`, consumes it in that
   adapter, and does not store or expose the generic service as an
   `AppDependencies` property.
10. Existing `AppTemplate.AppState` Data loads and saves byte-for-byte with no
    migration, re-encoding, fallback key, or AppState schema bump.
11. `AppStateStore`, `AppState`, `IAppStateStorage`, the load-result enum,
    previews, UI-test composition, and in-memory storage remain behaviorally
    and source unchanged as required by the scope guard.
12. The service emits no logs, errors reveal no metadata or payload, and no
    Feature or ViewModel consumes the generic boundary.
13. No App Group suite, capability, or
    `com.apple.security.application-groups` entitlement exists;
    `REGISTER_APP_GROUPS = YES` remains unchanged as profile bookkeeping.
14. No privacy manifest is added, and release documentation retains the
    product-specific blocker while requiring the UserDefaults accessed-API
    category and applicable app-private reason review.
15. Focused corruption, codec, compatibility, concurrency, composition,
    redaction, and scope tests pass.
16. All nine final verification gates pass with warnings as errors and no
    failed, skipped, expected-failure, or zero-test result accepted as green.
17. The final diff contains only the authorized implementation, tests, plan,
    and documentation changes.

## Primary Apple References

- [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
  describes supported settings values, app-private standard defaults, the
  privacy-manifest requirement, and the prohibition on sensitive information.
- [`object(forKey:)`](https://developer.apple.com/documentation/foundation/userdefaults/object(forkey:))
  is the raw read needed to distinguish missing from an incompatible object.
- [`set(_:forKey:)`](https://developer.apple.com/documentation/foundation/userdefaults/set(_:forkey:)-8ab6d)
  documents property-list writes and archiving other values into Data.
- [`removeObject(forKey:)`](https://developer.apple.com/documentation/foundation/userdefaults/removeobject(forkey:))
  documents removal from the target defaults domain.
- [`synchronize()`](https://developer.apple.com/documentation/foundation/userdefaults/synchronize())
  is deprecated as unnecessary and is not used.
- [`CFGetTypeID(_:)`](https://developer.apple.com/documentation/corefoundation/cfgettypeid(_:)),
  [`CFNumber`](https://developer.apple.com/documentation/corefoundation/cfnumber),
  and [`CFNumberType`](https://developer.apple.com/documentation/corefoundation/cfnumbertype)
  define the symbolic physical type checks used for bridged numeric values.
- [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder)
  and [`JSONDecoder`](https://developer.apple.com/documentation/foundation/jsondecoder)
  define the Codable JSON boundary.
- [`NSPrivacyAccessedAPIType`](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
  lists the UserDefaults category and approved reasons, including `CA92.1` for
  app-private access.
- [App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
  defines the entitlement deliberately absent from this design.
