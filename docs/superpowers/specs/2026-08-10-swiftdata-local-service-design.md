# SwiftData Local Service Design

## Status

The design was approved in conversation on 2026-08-10. This written
specification incorporates self-review and independent architecture, SDK, and
testability reviews and is the normative input to the implementation plan.

## Goal

Replace the intentionally empty `ILocalDatabaseService` /
`LocalDatabaseService` example with a production-quality SwiftData reference
store for one explicit value type, `ExampleRecord`. The service provides
validated CRUD, bounded result queries, explicit persistence, deterministic
failure handling, and safe Swift 6 actor boundaries.

This is operational infrastructure and an executable example, not a generic
product persistence abstraction. No screen starts reading or writing local
records. The existing `AppStateStore` continues to own launch policy through
`UserDefaults`.

## Current State

The current local service boundary is deliberately inert:

```swift
nonisolated
protocol ILocalDatabaseService: Sendable {}

actor LocalDatabaseService: ILocalDatabaseService {}
```

`AppDependencies` creates that actor in live, preview, and UI-test graphs, but
no feature dependency, ViewModel, view, or router consumes it. `ExampleRecord`
and `ExampleQuery` are disconnected `Sendable` value examples under
`App/Models/Local`.

The project supports iOS, iPadOS, and macOS 26.0, uses Swift 6 with MainActor as
the default actor isolation, has no package dependencies, and uses
filesystem-synchronized Xcode groups. SwiftData is therefore an SDK framework
dependency, and normal new Swift files join their matching targets without
manual `project.pbxproj` entries.

## Design Principles

1. SwiftData is an implementation detail of the local service.
2. `ModelContext` and persistent model instances never cross an actor boundary.
3. Public APIs accept and return only immutable `Sendable` values.
4. One live app dependency graph owns one long-lived persistent container.
5. Preview, UI-test, and persistence-test graphs never open the live store.
6. Every successful state-changing operation performs exactly one explicit
   `save()`; successful no-ops perform none.
7. Store bootstrap failures, including migration failures, remain distinct
   from validation, read, and write failures.
8. The service never silently erases data or falls back to an ephemeral store.
9. The first release starts with an explicit versioned schema and no fake
   legacy migration.
10. The public surface is intentionally specific to `ExampleRecord`; it is not
    presented as a reusable product repository.
11. No SwiftUI `@Query`, global container, or generic persistence API is
    introduced.

Apple documents `ModelActor` as the mutually exclusive access boundary for
persistent models and its actor-isolated context. Apple also marks
`ModelContext` as non-transferable between concurrency contexts. The design
therefore keeps all SwiftData objects behind an isolated engine. See
[ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor) and
[ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext).

## Architecture

The implementation has two isolation layers with different responsibilities:

```text
AppDependencies
    |
    v
ILocalDatabaseService (Sendable ExampleRecord API)
    |
    v
LocalDatabaseService actor
    - checks cancellation and pure validation
    - serializes lazy initialization
    - caches bootstrap success or failure
    |
    v
SwiftDataLocalStore ModelActor
    - creates one private ModelContext per public operation
    - performs SwiftData reads and writes
    - maps persistent entities to value records
    - explicitly saves and discards failed operation contexts
    |
    v
ModelContainer -> local SwiftData store
```

### Facade state machine

The factory is deliberately synchronous:

```swift
typealias LocalDatabaseContainerFactory =
    @Sendable () throws -> ModelContainer
```

`LocalDatabaseService` has actor-isolated state with three cases:

- `uninitialized(factory)`;
- `ready(store)`;
- `failed(error)`.

Every public operation first checks task cancellation and then performs all
pure validation that is possible without storage. Invalid input, a
pre-cancelled task, and an empty batch return without invoking the factory.

The first valid operation invokes the non-suspending factory once and
constructs one `SwiftDataLocalStore`. The actor stores `ready` before making an
`await` call to the engine, so actor reentrancy cannot duplicate
initialization. A non-cancellation container load or migration failure becomes
a cached `.initialization` error. Every later valid, non-cancelled operation
that requires storage returns the same cached category without repeating
filesystem I/O. Validation, cancellation, and empty-batch no-op semantics still
run before consulting cached store state. Recovery requires a new service
instance, normally on a later app launch or after an explicit composition-level
decision.

If the factory or URL resolver itself throws `CancellationError`, the facade
propagates it unchanged and restores `uninitialized(factory)`. A later valid
operation may therefore make a new bootstrap attempt; cancellation is never
cached as store corruption or initialization failure.

There is no `fatalError`, `try?`, automatic retry loop, automatic store erase,
or hidden in-memory fallback.

### SwiftData engine

`SwiftDataLocalStore` uses the `@ModelActor` macro. It never exposes a
`ModelContext` or persistent model. Each engine call that reaches storage
creates one fresh private `ModelContext` for the shared container, disables
autosave on that context, performs all synchronous SwiftData work without
suspension, converts entities into `ExampleRecord` values, and then releases
the context. The direct empty-batch fast path creates no context. Every
operation-scoped context is created and used entirely within ModelActor
isolation.

The actor declares a custom synchronous `init(modelContainer:hooks:)`. It
creates the executor context required by `ModelActor`, disables autosave on it,
assigns a `DefaultSerialModelExecutor`, stores the container and hooks, and
remains a normal `ModelActor`. A private `makeOperationContext()` creates the
context actually used by each public method and explicitly disables autosave
there as well; exact-save behavior therefore does not depend on the SDK
default. Both the initializer and operation-scoped context shape are
type-checked against the local Swift 6 / SwiftData SDK before implementation
planning.

The hooks stored property has a `.production` no-op default so the macro's
synthesized one-argument initializer also leaves a valid actor. The facade
always calls the custom two-argument initializer and passes hooks explicitly;
the `hooks` parameter has no default value, avoiding overload ambiguity.

The engine does not rely on autosave. Each state-changing operation stages all
changes in its private operation context, executes one pre-save cancellation
checkpoint, calls `save()` once, and returns only after that call succeeds. If
a write-phase operation throws before or during `save()`, the engine calls
`rollback()`, emits the rollback hook, and discards that operation context
before rethrowing the mapped error. A later operation necessarily starts from
a fresh context and therefore cannot observe stale registered models from the
failed context.

This context-discard rule is required by observed SwiftData behavior in Xcode
26.6: after a deterministic read-only-store save failure, `rollback()` clears
`hasChanges` but a fetch through the same context can still return an unsaved
value retained in its identity map. A fresh context returns the durable value.
The design does not claim that bare `rollback()` refreshes registered objects,
nor does it claim crash-level durability or compensating rollback of data that
a store may already have committed.

The actor/executor contract promises serialized access, not a particular
thread. No test or public API asserts background-thread identity.

### Internal verification seam

`SwiftDataLocalStore` accepts internal-only, production-no-op hooks:

```swift
nonisolated
enum LocalDatabaseStoreCheckpoint: Equatable, Sendable {
    case read(LocalDatabaseReadOperation)
    case readProgress(LocalDatabaseReadOperation)
    case writePreparation(LocalDatabaseWriteOperation)
    case beforeSave(LocalDatabaseWriteOperation)
}

nonisolated
struct LocalDatabaseStoreHooks: Sendable {
    let checkpoint:
        @Sendable (LocalDatabaseStoreCheckpoint) throws -> Void
    let didSave:
        @Sendable (LocalDatabaseWriteOperation) -> Void
    let didRollback:
        @Sendable (LocalDatabaseWriteOperation) -> Void
}
```

The engine invokes the matching checkpoint immediately before a public read,
after every 128 entities examined by filtered fetch-many, before preparatory
storage work for a write API, and after staging but directly before
`Task.checkCancellation()` and `save()`. Tests can make a checkpoint throw to
exercise deterministic read or write mapping. A test can synchronously cancel
its current task in `readProgress` or `beforeSave`; the immediately following
cancellation check then proves propagation or rollback without an
actor-reentrancy race. `didSave` runs only after a successful `save()`, and
`didRollback` runs only after the engine invokes `rollback()`; the failed
operation context is never reused afterward.

The hooks never receive a context, model, record, ID, payload, query, progress
count, or store URL. They are not public API. Their callbacks verify control-
flow placement; disk-reopen tests separately verify real SwiftData persistence.

## Public Value Contract

### Record

`ExampleRecord` remains an immutable value:

```swift
nonisolated
struct ExampleRecord: Codable, Equatable, Sendable {
    let id: String
    let payload: String
}
```

Its business ID is stable across launches and independent of SwiftData's
`PersistentIdentifier`. A valid ID contains at least one non-whitespace
character. The service preserves the supplied ID exactly; it does not trim,
case-fold, or otherwise normalize identity. Empty payloads are valid.

### Query

`ExampleQuery` is a bounded-result query:

```swift
nonisolated
struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let limit: Int

    init(searchText: String? = nil, limit: Int = 50)
}
```

Rules:

- `limit` is inclusive in `1...200`;
- the service trims query whitespace before search normalization;
- `nil`, empty, or whitespace-only search disables payload filtering;
- a nonempty search performs normalized substring matching against `payload`;
- matching uses Foundation string folding with case-insensitive,
  diacritic-insensitive, and width-insensitive options and a `nil` locale;
- results use the ascending order produced by SwiftData's
  `SortDescriptor(\.id)` and contain at most `limit` records.

The schema does not persist a normalized copy of payload. For an unfiltered
query, the descriptor uses `fetchLimit = limit`. For a filtered query, the
engine sets `includePendingChanges = false`, obtains an ID-sorted
`FetchResultsCollection` through `fetch(_:batchSize: 128)`, normalizes each
payload in actor isolation, checks cancellation at least once per 128 examined
entities, and stops consuming the collection as soon as `limit` matches are
collected or the store is exhausted. The context is clean because it was
created for this read operation and has no pending mutations. A filtered query
is O(n) in the worst case; product-scale indexed or full-text search is outside
this reference store's scope.

There is no cursor API. SwiftData does not document a Unicode collation contract
that would make an arbitrary-string `id > cursor` predicate provably identical
to its sort order. Removing cursor pagination avoids skip/duplicate promises the
store cannot support. Tests use stable ASCII fixture IDs and verify the order
returned by the configured SwiftData store, not a cross-OS Unicode collation.

### Service protocol

```swift
nonisolated
protocol ILocalDatabaseService: Sendable {
    func fetchRecord(id: String) async throws -> ExampleRecord?

    func fetchRecords(
        matching query: ExampleQuery
    ) async throws -> [ExampleRecord]

    func upsert(_ record: ExampleRecord) async throws
    func upsert(_ records: [ExampleRecord]) async throws

    @discardableResult
    func deleteRecord(id: String) async throws -> Bool

    @discardableResult
    func deleteAllRecords() async throws -> Int
}
```

The protocol does not accept a `ModelContext`, persistent model, generic
`FetchDescriptor`, predicate, store URL, or transaction closure.

## Validation and Mutation Semantics

### Facade validation

A pure `LocalDatabaseValidator` runs after the initial cancellation check and
before store resolution:

- fetch and delete-one IDs must contain a non-whitespace character;
- every upsert record must have a valid ID;
- a query limit must be in `1...200`;
- a batch may contain at most 500 records;
- a batch may not contain duplicate IDs using exact Swift `String` equality.

An empty batch is a successful no-op and does not initialize the store. All
other validation errors are returned before the container factory runs.

### Single upsert

The engine fetches by exact business ID, updates the payload when the entity
exists, or inserts one entity. If the stored payload already equals the new
payload, the operation succeeds without calling `save()`. Otherwise it stages
the change and calls `save()` once.

### Batch upsert

After facade validation, the engine resolves existing entities and applies all
inserts and updates. If every record is unchanged, the operation is a successful
no-op. Otherwise the entire public batch is staged and one `save()` is
attempted. A failure invokes context rollback and discards that operation
context; the service never deliberately splits one public batch across
multiple saves.

This is single-save/failed-context-discard behavior, not a stronger claim that
every possible SwiftData `DataStore` provides crash-level atomicity.

### Delete one

`deleteRecord(id:)` fetches by exact identity. It returns `false` without a save
when no entity exists. When present, it stages deletion, saves once, and returns
`true` only after the save succeeds.

### Delete all

`deleteAllRecords()` first uses `fetchCount` and returns zero without a save when
the store is empty. Otherwise it calls SwiftData's type-level
`ModelContext.delete(model:where:includeSubclasses:)` with no predicate and
`includeSubclasses: false` for `StoredExampleRecord`, then saves once and
returns the pre-delete count. The service does not fetch or materialize the
entities before invoking SwiftData's type-level delete. The method affects only
`StoredExampleRecord`; it is not `ModelContainer.deleteAllData()`.

Apple documents that type-level deletion removes matching entities on the next
save. See
[delete(model:where:includeSubclasses:)](https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:)).

### Cancellation

Cancellation is cooperative and has precise checkpoints:

- a pre-cancelled task does not validate or initialize the store;
- each active operation checks again before entering SwiftData work;
- each state-changing mutation checks immediately before `save()`;
- cancellation observed at that pre-save checkpoint invokes `rollback()`,
  discards the operation context, and propagates `CancellationError`
  unchanged;
- synchronous SwiftData work, including an in-progress `save()`, cannot be
  preempted;
- there is no post-save cancellation checkpoint, so an operation whose save
  succeeds returns success even if cancellation arrives afterward.

The check and synchronous `save()` are not claimed to be atomic. Cancellation
arriving after the last check may be observed only by later work.

## SwiftData Schema

The first shipped schema is explicit from day one:

```swift
nonisolated
enum LocalDatabaseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StoredExampleRecord.self]
    }

    @Model
    final class StoredExampleRecord {
        @Attribute(.unique) var id: String
        var payload: String

        init(id: String, payload: String) {
            self.id = id
            self.payload = payload
        }
    }
}
```

The exact macro/nonisolated declaration order is compile-verified under the
project's Swift 6 default-MainActor settings during implementation. Regardless
of generated conformances, instances are treated as actor-bound and never enter
the public API.

`LocalDatabaseMigrationPlan` includes `LocalDatabaseSchemaV1` and an empty
stage list. There is no artificial V0 model. Future releases retain historical
schema declarations, add the next `VersionedSchema`, define every required
lightweight or custom transition, and prove each transition with a disk fixture
before release. Container load and migration errors both map to the documented
bootstrap `.initialization` category because SwiftData does not expose an
exhaustive public discriminator for those phases.

Apple exposes schema responsibilities through
[VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)
and
[SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan).

The unique attribute is a storage invariant. Upsert still performs an explicit
identity fetch and update because implicit unique-collision merge behavior is
not part of this service contract.

## Store Configuration

### Live location and container

Live composition uses an injectable, synchronous URL resolver:

```swift
nonisolated
struct LocalDatabaseStoreLocationResolver: Sendable {
    let resolve: @Sendable () throws -> URL
}
```

The default resolver locates the user-domain Application Support directory,
requires a nonempty bundle identifier, creates a bundle-identifier-scoped
directory when needed, and returns the stable filename `LocalDatabase.store`.
The live container factory invokes that resolver lazily on the facade actor,
builds the complete versioned schema and migration plan, and creates a writable
`ModelConfiguration` at the explicit URL with CloudKit set to `.none`.

The resolver can be injected with a unique temporary root or a deterministic
throwing closure. Tests therefore verify stable path construction and directory
failure without reading or mutating the user's real Application Support data.
Calling `AppDependencies.live()` alone does not resolve the path or open the
store.

Only the one service owned by a live `AppDependencies` graph opens that logical
store. App Group sharing and cross-process access are not configured.

### Preview and UI testing

`AppDependencies.preview()` and `AppDependencies.uiTesting(initialState:)`
construct a fresh lazy service whose factory creates a new container using
`ModelConfiguration(isStoredInMemoryOnly: true)`. Separate dependency factory
calls never share a container. Preview rendering and UI-test launches cannot
read, mutate, migrate, or lock the live store.

### Unit and integration tests

Persistence tests create a fresh in-memory service per test. Persistence and
reopen tests use a unique temporary directory and explicit store URL, release
the first service/container, then create a second service against the same URL.
Tests never use the default live resolver or a global singleton.

The general `AppDependencies.test(...)` factory remains caller-injected and may
receive a fresh real in-memory service, spy, or fake appropriate to that test.
It does not silently construct a database service.

`ModelConfiguration` supports explicit URLs and ephemeral in-memory stores;
see [Apple's configuration API](https://developer.apple.com/documentation/swiftdata/modelconfiguration).

## Errors

The service defines stable public-operation categories while retaining the
underlying framework error:

```swift
nonisolated
enum LocalDatabaseValidationError: Error, Equatable, Sendable {
    case emptyID
    case invalidLimit(actual: Int, allowed: ClosedRange<Int>)
    case batchTooLarge(actual: Int, maximum: Int)
    case duplicateID
}

nonisolated
enum LocalDatabaseReadOperation: Equatable, Sendable {
    case fetchOne
    case fetchMany
}

nonisolated
enum LocalDatabaseWriteOperation: Equatable, Sendable {
    case upsertOne
    case upsertBatch
    case deleteOne
    case deleteAll
}

nonisolated
enum LocalDatabaseError: Error {
    case validation(LocalDatabaseValidationError)
    case initialization(underlying: any Error)
    case read(
        operation: LocalDatabaseReadOperation,
        underlying: any Error
    )
    case write(
        operation: LocalDatabaseWriteOperation,
        underlying: any Error
    )
}
```

`Error` is `Sendable` in the project's Swift language mode; the exact enum
declarations are compile-verified. `LocalDatabaseError` is not `Equatable`
because it preserves an arbitrary underlying error. Supporting operation and
validation enums are `Equatable` and `Sendable`.

Mapping follows the public operation, not the low-level SwiftData primitive:

- facade validation maps to `.validation`;
- container creation and any migration/load failure map to `.initialization`;
- failures during fetch-one or fetch-many map to `.read` with that operation;
- preparatory fetch/count, staging, batch-delete, and save failures inside a
  write API map to `.write` with that public write operation;
- `CancellationError` always propagates unchanged.

The service logs only operation name, entity type, record count, error domain,
and error code. It never logs IDs, payloads, search text, store contents, or
filesystem paths containing user-specific components. An internal typed
`LocalDatabaseFailureMetadata` value contains exactly those five allowed
fields; its constructor accepts an operation, record count, and error, not a
record, ID, payload, query, or URL. Production logging renders only that
metadata, and tests never inspect the environment's unified log store.

## Dependency Composition and Intended Reuse

`AppDependencies` remains the application composition root:

- `live()` injects one lazy persistent `LocalDatabaseService`;
- `uiTesting(initialState:)` injects a fresh in-memory service;
- `preview(...)` defaults to a fresh in-memory service and still accepts an
  explicit service;
- `test(...)` continues to require an explicit service.

The service is not passed into `AppSceneView` or a feature in this change. The
`ExampleRecord` contract is deliberately a runnable template reference, not the
storage boundary that Browse, Projects, or another real feature should consume.
A product feature introduces its own semantic protocol and schema (or replaces
this sample contract), then injects that feature protocol into its ViewModel.
It does not encode arbitrary domain data into `ExampleRecord.payload` merely to
reuse this API, and it does not inject `AppDependencies`, `ModelContainer`, or
SwiftData types into the ViewModel.

`IAppStateStorage`, `AppStateStore`, and their UserDefaults schema remain
unchanged. Moving launch policy into SwiftData would be a separate design with
asynchronous startup and migration requirements.

## Verification Strategy

Implementation follows test-driven development and adds focused coverage for:

1. Pre-cancellation and every validation rule before factory invocation.
2. Empty-batch no-op without initialization.
3. Case, diacritic, width, whitespace, and substring search behavior.
4. Entity-to-value mapping without persistent-object leakage.
5. Insert, exact fetch, update-in-place, unchanged no-op, missing fetch, and
   empty payload.
6. Bounded result count, configured SwiftData ordering, multi-batch search, no
   match, and limit validation.
7. Empty, valid, duplicate, oversized, unchanged, and mixed batch upserts.
8. Missing/present single deletion and counted type-level delete-all behavior.
9. Control-flow placement for one successful save per state-changing public
   mutation and no save for each documented no-op, observed through hooks, plus
   real persistence verified independently through disk reopen tests.
10. Deterministic read/write checkpoint failures, exact error categories,
    rollback plus failed-context discard, and a successful operation on the
    same service. A disk-backed `allowsSave: false` fixture also proves that a
    real thrown `save()` cannot leak its unsaved value into the next operation.
11. Deterministic filtered-read cancellation through `readProgress`, unchanged
    `CancellationError`, and a usable service afterward.
12. Deterministic pre-save cancellation via `beforeSave`, unchanged persisted
    state, unchanged `CancellationError`, and observed rollback.
13. Exactly-once synchronous lazy initialization, retry after factory
    cancellation, cached non-cancellation initialization failure, and one
    long-lived engine per successful service initialization.
14. Concurrent public calls through the facade and serialized engine access.
15. Fresh preview/UI-test/in-memory composition with no state sharing.
16. Stable live URL construction and deterministic resolver failure using only
    temporary roots.
17. Reopening a uniquely located disk store in a second container.
18. Schema-v1 and migration-plan metadata with no fake transition.
19. Exact diagnostic metadata generated from a sentinel error whose description
    contains an ID, payload, search text, and user-specific path, proving that
    only operation, entity type, count, error domain, and error code can reach
    the logging boundary.

Cancellation checks execute inside a child `Task`, so synchronously cancelling
the request does not cancel Swift Testing's runner task or produce a masked
cancelled test. Tests do not corrupt a real store, depend on filesystem
permissions, race an external cancellation against synchronous work, assert a
particular executor thread, or touch the live Application Support directory.

The final local gates are:

- focused LocalDatabase and AppDependencies tests on macOS;
- all `AppTemplateTests` on macOS;
- all `AppTemplateTests` on iPhone 17 / iOS 26.5;
- all `AppTemplateTests` on iPad (A16) / iOS 26.5;
- the complete macOS scheme, including UI tests;
- the full UI-test bundle on iPhone 17 and iPad (A16);
- a generic macOS Release build;
- a generic iOS Release compile gate with `CODE_SIGNING_ALLOWED=NO`;
- Swift and Clang warnings treated as errors for every gate.

Each gate uses unique Derived Data and result paths. Distribution signing is a
release-checklist responsibility, not a precondition for the generic iOS
compile gate. Hosted CI remains absent; these are explicit local verification
requirements.

## Documentation Changes

Implementation updates:

- `README.md` to state that the template includes a local-only SwiftData
  reference store but does not choose product entities or sync policy;
- `docs/ARCHITECTURE.md` with facade/ModelActor/value-boundary/schema details;
- `docs/CUSTOMIZATION.md` with sample replacement, store URL, migration,
  retention, backup, CloudKit, and feature-protocol guidance;
- `docs/RELEASE_CHECKLIST.md` with SwiftData schema-transition fixtures,
  persistence/reopen checks, data lifecycle, and store recovery review.

Documentation must not claim application-level encryption, CloudKit sync,
cross-process support, crash-level durability, Unicode cursor ordering, or
migration coverage beyond the implemented V1 schema.

## Non-Goals

This change does not:

- connect local records to Browse, Projects, or another screen;
- present `ILocalDatabaseService` as a generic future feature repository;
- replace `AppStateStore` or UserDefaults persistence;
- expose `@Query`, `ModelContext`, `ModelContainer`, `PersistentModel`, or
  `PersistentIdentifier` outside the persistence implementation;
- provide arbitrary predicates, cursor pagination, or a transaction closure;
- add relationships, CloudKit, App Group sharing, widgets, history processing,
  change streams, undo, Spotlight, full-text indexing, or background import;
- claim application-level encryption or permit secrets by default;
- automatically erase, repair, downgrade, or migrate an unknown store;
- add third-party dependencies, package changes, entitlements, or hosted CI.

## Alternatives Rejected

### Direct `@ModelActor` service with eager container creation

This is smaller, but throwing initialization would force a persistence failure
policy into synchronous `AppDependencies.live()` and `AppTemplateApp.init`.
Fatal initialization and silent fallback are both poor template defaults. The
lazy facade preserves a clean app-launch boundary while surfacing failure on
the first actual operation.

### SwiftUI main context and `@Query`

This would be concise for a concrete UI feature, but no such consumer is in
scope. It would leak persistence into views, bind storage work to MainActor, and
weaken explicit dependency injection.

### Generic CRUD repository

SwiftData predicates and managed models would escape into callers, while a
type-erased CRUD layer would hide rather than clarify validation, mapping,
isolation, and persistence semantics. A real feature should define a semantic
feature protocol instead of inheriting a sample's generic storage vocabulary.

### Cursor pagination on arbitrary string IDs

SwiftData does not specify that predicate string comparison and sort descriptors
share one stable Unicode collation across OS and store versions. An additional
sortable cursor key would add schema and migration cost without a consumer.
Bounded arrays are the honest YAGNI choice for the sample.

### Persisting normalized search text

A denormalized field would require a normalization-version and backfill policy
whenever Unicode/ICU behavior or the algorithm changes. Runtime normalization
keeps schema V1 stable and makes the O(n) tradeoff explicit.

### Converting `ExampleRecord` into `@Model`

That would replace an immutable `Codable`, `Equatable`, `Sendable` value with a
context-bound reference object. A separate internal entity protects actor
boundaries and lets the storage schema evolve independently of the public value.

## Acceptance Criteria

The implementation is complete when:

1. The public contract, validation rules, query behavior, and no-op semantics
   above are implemented exactly.
2. SwiftData objects remain confined to the internal ModelActor engine.
3. Live composition uses one lazy disk service at the resolver's stable URL,
   and preview/UI-test composition uses isolated in-memory containers.
4. Schema V1 and its migration plan are explicit and contain no fake legacy
   transition.
5. Every successful state-changing operation completes one explicit save;
   documented successful no-ops complete none.
6. Write-phase failure or cancellation observed at the pre-save checkpoint
   invokes context rollback and discards that operation context; the next
   operation observes durable state from a fresh context. No stronger
   store-level atomicity is claimed.
7. Non-cancellation bootstrap errors are cached without fatal termination,
   automatic erase, or ephemeral fallback.
8. Persistence reopen, concurrency, validation, CRUD, bounded query,
   cancellation, failure mapping, rollback, and composition tests pass.
9. The local platform, UI, Release, and warnings-as-errors gates pass with zero
   failed or skipped tests.
10. Documentation accurately describes the `ExampleRecord` reference store,
    replacement path, limitations, and non-goals.
11. The implementation diff adds no package dependency, entitlement, hosted CI,
    or unrelated feature behavior.
