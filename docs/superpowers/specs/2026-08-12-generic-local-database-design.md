# Generic SwiftData Local Database Design

## Status

The design was approved section by section in conversation on 2026-08-12.
This specification is the normative input to the implementation plan. It
supersedes the ExampleRecord-specific API boundary in the 2026-08-10
SwiftData local-service design while preserving that design's shipped schema,
storage, isolation, persistence, cancellation, and recovery guarantees.

## Goal

Replace the six ExampleRecord-specific methods on `ILocalDatabaseService`
with a reusable, compile-time generic API. The API must support multiple
explicitly registered detached local-record value types, and each value type
must own a strongly typed query type.

The implementation remains a SwiftData reference store rather than a
schemaless document database. Adding a production model still requires an
explicit SwiftData entity, adapter, schema registration, and—after V1 has
shipped—an appropriate schema version and migration.

The immediate production model remains `ExampleRecord`. A second model exists
only in tests to prove that the engine is genuinely reusable without changing
the production schema.

## Current Baseline

The current service exposes six methods tied directly to `ExampleRecord` and
`ExampleQuery`:

```swift
func fetchRecord(id: String) async throws -> ExampleRecord?
func fetchRecords(matching query: ExampleQuery) async throws -> [ExampleRecord]
func upsert(_ record: ExampleRecord) async throws
func upsert(_ records: [ExampleRecord]) async throws
func deleteRecord(id: String) async throws -> Bool
func deleteAllRecords() async throws -> Int
```

The concrete implementation already has the operational properties that this
refactor must preserve:

- an actor facade serializes lazy initialization and caches non-cancellation
  bootstrap failures;
- a `@ModelActor` engine confines every SwiftData object;
- each operation that reaches storage creates a fresh autosave-disabled
  `ModelContext`;
- state-changing upsert and delete-one operations explicitly save once;
- successful no-ops do not save;
- type-level delete-all is treated as its own synchronous persistence
  boundary on the supported Xcode 26.6 SDK;
- only detached `Sendable` values leave the engine;
- preview, UI-test, and persistence-test graphs do not open the live store.

No feature currently consumes `ILocalDatabaseService`. This makes replacing
the specialized API now preferable to carrying deprecated wrappers.

## Decisions

1. Model, Query, and adapter pairing is enforced at compile time. Each service
   instance also has an explicit immutable runtime registry of permitted
   adapters. The database does not accept arbitrary `Codable` types.
2. The existing specialized API is removed in the same change. No deprecated
   forwarding methods remain.
3. Every model declares its own associated `Query` type. There is no universal
   query DSL.
4. Detached local-persistence records, IDs, and queries are immutable
   `Sendable` types. SwiftData entities and contexts remain internal
   implementation details.
5. `VersionedSchema` remains the source of truth for production persistence.
   Generic dispatch does not make an open container dynamically extensible.
6. Homogeneous batches are supported. Heterogeneous batches and arbitrary
   transaction closures are not.
7. Feature ViewModels do not receive the raw generic database. A real feature
   should place a semantic repository in front of it.

## Public Contract

The replacement service contract is:

```swift
nonisolated
protocol ILocalDatabaseService: Sendable {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model?

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model]

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int
}
```

Representative calls are:

```swift
try await database.upsert(record)

let record = try await database.fetch(
    ExampleRecord.self,
    id: recordID
)

let records = try await database.fetch(
    ExampleRecord.self,
    matching: ExampleQuery(searchText: "swift", limit: 20)
)
```

The local-record contract has this shape:

```swift
nonisolated
protocol LocalDatabaseModel: Identifiable, Sendable
where ID: Hashable & Sendable {
    associatedtype Query: Sendable
    associatedtype Persistence: LocalEntityAdapter
    where Persistence.Value == Self,
          Persistence.Query == Query
}
```

This exact recursive generic shape and the existential call were type-checked
with Swift 6.3.3, MainActor default isolation, and the project's approachable
concurrency settings during design review. The implementation must preserve
these semantic guarantees:

- the value type determines exactly one ID type, Query type, and adapter;
- the compiler rejects a query belonging to another model;
- a service existential remains callable as
  `database.fetch(Model.self, matching: query)`;
- no caller chooses or passes a SwiftData entity type.

`LocalDatabaseModel` means a detached local-persistence record, not a product
Domain entity. `ExampleRecord` already has that role under `App/Models/Local`.
It becomes `Identifiable` without changing its stored ID value or its immutable
`Codable`, `Equatable`, and `Sendable` value semantics. `ExampleQuery` remains
the associated query for that record.

A future semantic repository maps between a feature's Domain model and its
local record. Feature Domain protocols and ViewModels do not know about
`LocalDatabaseModel`, its adapter, or its SwiftData entity.

## Internal Adapter Boundary

The declaration is explicitly nonisolated under the project's MainActor
default:

```swift
nonisolated
protocol LocalEntityAdapter: SendableMetatype
where Value.Persistence == Self, Value.Query == Query {
    associatedtype Value: LocalDatabaseModel
    associatedtype Entity: PersistentModel
    associatedtype Query: Sendable
}
```

The complete protocol remains internal to `App/Services/LocalDatabase`. An
adapter associates:

- one `LocalDatabaseModel` value;
- one concrete SwiftData `PersistentModel` entity;
- the value's associated Query;
- a stable non-user-controlled diagnostic name.

It provides synchronous, actor-confined operations for:

- pure ID, value, and query validation;
- fetching one entity by typed ID;
- fetching existing entities for a homogeneous ID batch;
- building and executing the model-specific typed query with a synchronous,
  nonescaping progress callback;
- returning a non-sensitive diagnostic record count for a Query;
- reading an entity's typed business ID;
- mapping an entity to a detached value;
- creating a new entity;
- updating an existing entity and reporting whether it changed.

The generic engine owns orchestration, cancellation checkpoints, operation
contexts, save/no-op behavior, delete-all, error mapping, and diagnostics. The
adapter owns the concrete predicates, sort descriptors, search behavior, and
entity mapping that cannot be expressed honestly by a universal query type.

All adapter requirements are `nonisolated`. Functions that receive a
`ModelContext` are synchronous and can only be invoked from inside the
`@ModelActor`. The query progress callback is nonescaping and carries only the
number of examined entities; it never carries an entity, context, descriptor,
or query value. The adapter invokes it at each positive multiple of 128
examined entities. These requirements are not public extension points for
Features.

Every adapter defines one injective mapping between `Value.ID` and a persisted
business-ID field. The corresponding entity schema enforces uniqueness for
that field. Fetch-one and batch lookup must detect an unexpected duplicate
instead of selecting `.first` silently or trapping while building a
dictionary. Such corruption is thrown through the enclosing read or write
operation.

The `ExampleRecord` conformance and `ExampleRecordAdapter` live in the local
database adapter tree rather than adding SwiftData knowledge to the domain
model file. The adapter reuses the exact existing
`LocalDatabaseSchemaV1.StoredExampleRecord` class. It preserves:

- an ID is valid when it contains at least one non-whitespace character;
- exact, case-sensitive String ID persistence without trimming or
  normalization;
- schema-enforced unique business IDs;
- empty payload support;
- normalized payload substring search;
- ascending ID order;
- the existing inclusive query limit bounds;
- the existing maximum homogeneous batch size and exact duplicate-ID rule.

## Explicit Registration

A nonisolated, `Sendable` registry is part of one immutable store
configuration:

```swift
nonisolated
struct LocalDatabaseStoreConfiguration: Sendable {
    let containerFactory: LocalDatabaseContainerFactory
    let modelRegistry: LocalDatabaseModelRegistry
}

nonisolated
struct LocalDatabaseModelRegistry: Sendable {
    // Internal SendableMetatype registrations.
}
```

Bundling the factory and registry prevents production composition from
injecting them independently. The registry contains `SendableMetatype`
adapter metatypes permitted for that service instance and can answer whether
a generic `Model.Persistence` is registered without opening the store. This
exact erased-metatype storage shape was type-checked under the project settings
during design review.

The live, preview, and UI-test configurations use the production registry,
initially containing only `ExampleRecordAdapter`. A test-only configuration may
use a registry containing both the Example adapter and a test adapter.

A valid registry is a bijection across adapter, local-record value, and entity
metatypes: each of those three `ObjectIdentifier` values occurs exactly once.
Construction detects duplicates deterministically without `fatalError`,
`precondition`, or a dictionary-construction trap. Invalid registry
configuration fails as `.initialization` before invoking the container factory.
Schema/registry tests compare both entity identifiers and cardinality, so two
adapters cannot silently share one entity. Diagnostic names are also unique.

Registration is checked after cancellation and pure input validation but
before lazy store resolution. Calling the service with a conforming but
unregistered model fails deterministically as
`.validation(model: diagnosticName, reason: .unregisteredModel)` and does not
initialize the store.

The registry is metadata and dispatch authorization, not a dynamic schema.
Typed calls still dispatch generically through `Model.Persistence`; associated
adapter operations are not invoked through an erased adapter existential.

Tests must assert that the production registry's unique entity types exactly
match the current production schema's model types and cardinality. This turns
a forgotten schema or registry update into a deterministic test failure.
`VersionedSchema` remains the source of truth for persistence and migration;
the runtime registry is authorization metadata, not a schema generator.
Container initialization and actual SwiftData operations remain the final
runtime validation of schema compatibility.

## Architecture and Data Flow

```text
Feature semantic repository (future consumer)
    |
    v
ILocalDatabaseService (generic Sendable value API)
    |
    v
LocalDatabaseService actor
    - cancellation and pure validation
    - adapter registration check
    - serialized lazy initialization
    - cached bootstrap success or failure
    |
    v
SwiftDataLocalStore @ModelActor
    - one fresh private context per storage operation
    - generic orchestration through Model.Persistence
    - explicit persistence boundaries
    - typed error mapping and redacted diagnostics
    |
    v
LocalEntityAdapter
    - concrete entity predicates, query, sort, and mapping
    |
    v
ModelContainer -> versioned SwiftData store
```

For a valid operation, the facade performs this sequence:

1. check task cancellation;
2. run pure adapter and shared validation;
3. validate registry integrity and verify adapter registration;
4. return any guaranteed no-op, such as an empty registered batch;
5. resolve the lazy container and engine;
6. check task cancellation again;
7. invoke the typed engine operation.

The facade keeps the existing `uninitialized`, `ready`, and `failed` state
machine. The registry is immutable configuration and does not change after
construction.

A non-cancellation bootstrap error is cached. Later valid, registered,
non-cancelled operations requiring storage receive the cached initialization
category without another factory call. A bootstrap `CancellationError`
propagates unchanged and returns the facade to `uninitialized`, allowing one
later retry. Validation, registry integrity, unregistered-model, empty-batch,
and pre-cancellation results are resolved before consulting cached bootstrap
state. Therefore an empty batch for a registered model remains a no-op that
does not open the store, while an empty batch for an unregistered model fails
registration.

## Query Semantics

Every query is an immutable `Sendable` type selected by its model. It may
contain only domain-facing filters, sort choices, and bounded result options.
It cannot contain:

- `Predicate` or `FetchDescriptor`;
- SwiftData entities or persistent identifiers;
- raw key paths;
- escaping filtering or sorting closures;
- SQL-like field names or string operators.

The adapter maps the query to concrete SwiftData descriptors and, when the SDK
cannot express the required normalized match, bounded post-fetch filtering.
All sorting must define a total deterministic order with a unique tie-breaker.

V1 does not add offset or cursor pagination. The current API returns a bounded
array. This avoids claiming stable Unicode cursor ordering or snapshot
semantics that the current String ID and SwiftData API do not guarantee.

The Example adapter preserves the current query behavior exactly. Blank or
absent search text disables filtering. Nonblank search text performs the same
case-, diacritic-, and width-insensitive normalized substring match over the
payload. Results remain in ascending stored ID order and stop at the requested
validated limit.

When a query requires an in-memory scan, the adapter invokes its synchronous
nonescaping progress callback after every 128 examined entities. The engine's
callback runs the read-progress hook and cancellation check. The engine also
performs a final cancellation check before returning. For failure diagnostics,
the adapter supplies a bounded, non-sensitive attempted-record count; the
Example adapter returns the validated query limit.

## Mutation Semantics

The generic engine supports one value, one homogeneous batch, one typed ID
delete, and one typed model delete-all.

Shared validation rejects an oversized batch and exact duplicate IDs using
the model's `Hashable` ID. The model adapter validates each value. IDs are
never normalized or coerced by the generic engine.

Each upsert and delete-one operation:

1. creates a fresh autosave-disabled context;
2. runs the write-preparation checkpoint and cancellation check;
3. uses the adapter to fetch and stage changes;
4. returns immediately if the operation is a documented no-op;
5. runs the before-save checkpoint and cancellation check;
6. calls `save()` exactly once;
7. emits `didSave` and returns without a post-save cancellation check.

If preparation or save throws, the engine rolls back the operation context,
emits `didRollback`, maps the error, discards the context, and rethrows. The
next operation receives a new context and cannot reuse stale registered model
instances from the failed context. The service does not claim that rollback
can undo data already committed by an arbitrary failing store.

For nonempty delete-all, the engine counts matching entities, then performs
the before-batch-delete checkpoint and cancellation check before invoking
`ModelContext.delete(model:where:includeSubclasses:)` for the adapter's entity
type. Under the supported SDK, that call is the persistence boundary: there is
no explicit save, post-call cancellation check, or claim that rollback can
compensate a completed or partially completed batch delete. A toolchain
upgrade requires recharacterizing this behavior.

A delete-all failure during count, checkpoint, or the type-level delete call
also executes context cleanup and emits `didRollback`. For failures before the
delete call this is ordinary cleanup with no durable mutation. If the delete
call itself throws, neither the hook nor `rollback()` implies that already
durable or partially durable deletion was restored.

Heterogeneous batches and multi-entity transactions are outside V1. A future
feature requiring an atomic multi-entity use case must receive a named,
semantic engine operation rather than a general `ModelContext` closure.

## Errors and Diagnostics

The existing categories remain, generalized with stable model metadata:

- validation or registration failure;
- initialization or migration failure;
- read failure with model and read operation;
- write failure with model and write operation.

The normative error shape is:

```swift
nonisolated
enum LocalDatabaseError: Error {
    case validation(
        model: String,
        reason: LocalDatabaseValidationError
    )
    case initialization(underlying: any Error)
    case read(
        model: String,
        operation: LocalDatabaseReadOperation,
        underlying: any Error
    )
    case write(
        model: String,
        operation: LocalDatabaseWriteOperation,
        underlying: any Error
    )
}
```

`LocalDatabaseValidationError` retains `emptyID`, `invalidLimit`,
`batchTooLarge`, and `duplicateID`, and adds `unregisteredModel`. An adapter
uses only the cases relevant to its value and Query. A future adapter-specific
rule extends this typed enum rather than using an arbitrary message.

An adapter provides a fixed diagnostic entity name. Error and hook operation
enums remain data-free (`fetchOne`, `fetchMany`, `upsertOne`, `upsertBatch`,
`deleteOne`, and `deleteAll`).

Production diagnostics may include only:

- operation;
- the adapter diagnostic entity name for validation, read, and write
  operations;
- the fixed component name `LocalDatabase` for container-wide initialization
  and migration failures;
- attempted record count;
- underlying error domain;
- underlying numeric error code.

They must never include IDs, payloads, search text, query values, file URLs,
store paths, error descriptions, `userInfo`, or persistent objects. The
underlying error remains attached to the thrown error for programmatic
inspection but is not formatted into logs.

`CancellationError` always propagates unchanged and is never logged or wrapped
as a database failure.

## Concurrency and Isolation

`LocalDatabaseService` remains an actor. `SwiftDataLocalStore` remains a
`@ModelActor`. The facade serializes initialization state; the model actor and
its executor serialize access to SwiftData. The contract promises mutual
exclusion, not a specific thread.

Every engine operation that reaches storage creates and consumes one private
`ModelContext` synchronously inside model-actor isolation. A context,
persistent entity, descriptor tied to an entity, or entity-taking closure
never crosses that boundary.

Concurrent calls may complete in the engine's serialization order, but the
public API does not promise submission order between independent Tasks.
Callers that require domain ordering must serialize their own semantic
operations in a repository or higher-level actor.

Cancellation checkpoints occur:

- before validation;
- before lazy initialization;
- after successful initialization and before engine work;
- on engine entry;
- periodically during scanned reads;
- immediately before `save()`;
- immediately before type-level batch delete.

Synchronous SwiftData calls are not made cancellable retroactively. After a
successful write persistence boundary, the operation reports success even if
the task becomes cancelled immediately afterward.

## Schema and Migration

This refactor changes the API and engine organization but not the production
store schema.

`LocalDatabaseSchemaV1`, its `Schema.Version(1, 0, 0)`, and
`StoredExampleRecord` retain their exact names, fields, uniqueness attribute,
and initializer semantics. `LocalDatabaseMigrationPlan.schemas` remains V1
only and `stages` remains empty. Existing disk stores must reopen without a
migration and retain inserted, updated, and surviving records.

The second test model and entity are registered only in a dedicated test
registry and in-memory test container. They do not appear in
`LocalDatabaseSchemaV1` or the production migration plan.

After V1 has shipped, adding a production model requires all of the following:

1. a detached Sendable local-persistence record and associated Query;
2. a concrete SwiftData entity;
3. a schema-enforced unique business-ID field with an injective mapping from
   the local record's ID;
4. an internal adapter and `LocalDatabaseModel` conformance;
5. a new immutable `VersionedSchema` containing all required entities;
6. an appropriate lightweight or custom migration stage;
7. production registry update;
8. schema/registry bijection and uniqueness tests;
9. a disk transition fixture proving the prior store opens and preserves data.

Historical schema declarations are frozen. A model rename, property change,
index, uniqueness rule, or relationship change is evaluated as a schema
migration even when the public generic API is unchanged.

## Composition

`AppDependencies` continues to expose `any ILocalDatabaseService`; generic
methods on that existential are part of the required compiler proof.

The live graph constructs the service with one live store configuration that
contains the existing lazy persistent container factory and production
registry. Preview and UI-test graphs construct fresh in-memory configurations
and fresh service instances using the same production registry.
`AppDependencies.test(...)` continues to require an explicitly injected
service.

`AppTemplateApp`, application-state persistence, navigation, Features, views,
and ViewModels do not change. No Feature starts consuming the generic database
as part of this refactor.

A future feature should define a semantic protocol such as
`IProjectsRepository`, implement it using the generic database and one model,
and inject that repository into the feature dependency slice. The generic
database is infrastructure, not a ViewModel-facing business API.

## Verification Strategy

### Compiler and contract proofs

Before broad behavior work, focused Swift 6 compiler tests must prove:

- the recursive model/adapter constraints compile with MainActor as the
  project's default isolation;
- generic methods are callable through `any ILocalDatabaseService`;
- an external compile-fail fixture that passes one model's Query to another
  model exits nonzero with the expected type-mismatch diagnostic;
- test doubles can conform without unsafe type erasure.

Directory placement is not a Swift access-control boundary because the app is
one module. The plan therefore uses source-boundary guards—not a false compiler
claim—to reject `import SwiftData`, `ModelContext`, `ModelContainer`,
`PersistentModel`, `FetchDescriptor`, `Predicate`, adapter references, and
`LocalDatabaseModel` references outside their approved persistence and
composition paths. Moving persistence into a separate Swift module is outside
this refactor.

The removed specialized method names must have no production or test call
sites after the migration.

### Generic behavior proofs

The test suite uses both:

- `ExampleRecord` with the production entity and adapter;
- a test-only value with a different ID type, Query shape, and entity.

The test container registers both entity types, while the production schema
continues to register only `StoredExampleRecord`. Tests exercise both adapters
through the same `any ILocalDatabaseService` value.

Required coverage includes:

- fetch-one missing and present behavior for both models;
- insert, update, unchanged no-op, and detached value lifetime;
- homogeneous batch insert, mixed update/insert, empty no-op, maximum size,
  oversized rejection, exact duplicate-ID rejection, and case-distinct String
  IDs for the Example adapter;
- delete-one missing/present and model-scoped delete-all;
- model isolation when both adapters share one test container;
- each Query's filtering, deterministic sorting, limits, empty result, scanned
  batching, early stop, and cancellation behavior;
- unregistered-model rejection without container initialization;
- deterministic rejection of duplicate adapter, value, entity, or diagnostic
  name registrations without container initialization;
- production registry and production schema equality including cardinality;
- schema-enforced unique business IDs and nontrapping duplicate-detection
  behavior at the adapter boundary;
- exactly one save for each state-changing upsert/delete-one operation;
- no save for documented no-ops;
- the existing type-level delete-all persistence characterization;
- deterministic read/write failure mapping with the correct model metadata;
- rollback/context discard after save failure and later service usability;
- cached non-cancellation bootstrap failure and retry after bootstrap
  cancellation;
- actor-safe concurrent first initialization and concurrent operations;
- metadata-only diagnostic redaction with sentinel IDs, payloads, search text,
  paths, descriptions, and `userInfo` absent from emitted metadata;
- a temporary disk-backed store seeded directly through the frozen V1 entity,
  then released and reopened through the generic service with exact Example
  values preserved;
- a normal generic-service disk reopen after inserts, updates, and deletions.

Before changing source, the implementation plan also creates a temporary
baseline store through the current Example-specific service and records its
fixture values. The completed generic service must reopen that preserved store
and return those exact values. `LocalDatabaseSchema.swift` must remain
byte-for-byte unchanged in the implementation diff. The direct frozen-V1
writer test remains as repeatable regression coverage after the temporary
pre-refactor artifact is gone.

The complete error, cancellation, save/no-op, and delete-all matrix is proven
once through the generic engine and retained Example regression scenarios. The
second test adapter needs distinct-ID CRUD, its own Query behavior, registration
checks, coexistence, and model isolation; it does not duplicate every engine
failure scenario.

Cancellation tests run the database call in a child Task. They never cancel
the Swift Testing runner itself and never depend on timing races.

### Project gates

The implementation plan must define unique temporary derived-data and result
paths and require warning-as-error verification for:

1. focused LocalDatabase, local-model, and composition tests on macOS;
2. all unit tests on macOS;
3. all unit tests on iPhone 17 / iOS 26.5;
4. all unit tests on iPad (A16) / iOS 26.5;
5. the complete macOS scheme;
6. the complete UI-test bundle on iPhone 17 / iOS 26.5;
7. the complete UI-test bundle on iPad (A16) / iOS 26.5;
8. a generic macOS Release build;
9. an unsigned generic iOS Release build.

Every test result bundle must report `Passed`, a nonzero test count, and zero
failed, skipped, or expected-failure tests. Existing macOS UI automation
authorization requirements remain an environment prerequisite rather than a
reason to weaken or allow-list the gate.

## Documentation Changes During Implementation

The implementation updates the active project documentation:

- `README.md` describes a typed, explicitly registered SwiftData reference
  engine rather than an Example-only service;
- `docs/ARCHITECTURE.md` documents the value → adapter → entity boundary and
  semantic repository expectation;
- `docs/CUSTOMIZATION.md` gives the exact checklist for adding a production
  model, schema version, registry entry, and migration fixture;
- `docs/RELEASE_CHECKLIST.md` retains disk reopen, migration, failure recovery,
  privacy, backup, and platform verification requirements.

The 2026-08-10 design remains historical evidence for the original V1 store.
This specification is authoritative where the two designs differ about a
generic API or ExampleRecord-specific boundary.

## Scope Guard

Expected production changes are limited to:

- `App/Models/Local/ExampleRecord.swift` and `ExampleQuery.swift` where needed
  for the new contracts;
- `App/Services/LocalDatabase`;
- `AppDependencies` composition;
- matching LocalDatabase, local-model, and composition tests;
- the four active project documentation files listed above;
- this specification and its implementation plan.

No implementation change is authorized in:

- Features, ViewModels, views, navigation, or application state;
- networking;
- UserDefaults or Keychain services;
- UI-test source;
- packages, build settings, entitlements, schemes, or hosted automation.

The Xcode project uses filesystem-synchronized groups, so adding Swift files
under existing source and test roots must not require manual project-file
membership edits.

`App/Services/LocalDatabase/LocalDatabaseSchema.swift` is an inspected input
but must remain byte-for-byte unchanged by this API refactor.

## Out of Scope

- arbitrary Codable/Data envelope persistence;
- runtime discovery or dynamic registration after container creation;
- a universal filter/sort/query language;
- raw SwiftData predicates, descriptors, entities, contexts, or persistent
  identifiers in public APIs;
- cursor or offset pagination;
- heterogeneous batches;
- general transaction/context closures;
- cross-entity atomic operations;
- SwiftData relationships added only to demonstrate genericity;
- a second production model;
- feature repository adoption;
- CloudKit, App Groups, cross-process coordination, encryption, or backup
  policy changes;
- UserDefaultsService or KeychainService implementation.

## Acceptance Criteria

The change is complete only when all of the following are true:

1. `ILocalDatabaseService` exposes only the six generic operations in this
   design, and the old specialized method names have no call sites.
2. A service existential accepts `ExampleRecord` and a distinct test model
   through the same typed API.
3. Each model accepts only its associated Query type at compile time.
4. Every registry is a nontrapping adapter/value/entity bijection, the
   production registry matches production schema types and cardinality, and
   each entity enforces its adapter's unique business ID.
5. `LocalDatabaseSchema.swift` remains byte-for-byte unchanged, and a store
   created by the pre-refactor V1 service reopens with exact values preserved.
6. All current Example validation, query, save/no-op, batch-delete,
   cancellation, failure, isolation, and redaction guarantees remain true.
7. SwiftData types remain confined to the local persistence implementation;
   Features and ViewModels receive none of them.
8. No production test entity or feature consumer is introduced.
9. All nine project gates pass with warnings treated as errors and with no
   failed, skipped, expected-failure, or zero-test result accepted as green.
10. The working-tree change remains inside the approved scope and the active
    documentation explains how a future production model is registered and
    migrated.

Once these criteria are met and the Generic LocalDatabase work is integrated,
the next independent design/specification cycle begins for
`UserDefaultsService`, followed by `KeychainService`.
