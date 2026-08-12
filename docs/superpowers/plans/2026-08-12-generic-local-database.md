# Generic Local Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ExampleRecord-specific local-database API with a compile-time generic SwiftData engine for explicitly registered detached local records and their associated typed queries, without changing the shipped V1 schema or its persisted data.

**Architecture:** Keep `ILocalDatabaseService` as an existential-friendly generic Sendable value boundary. A `LocalDatabaseService` actor validates and authorizes each model through an immutable registry before lazily resolving a container; a generic `SwiftDataLocalStore` ModelActor owns operation-scoped contexts, while each nonisolated adapter owns concrete predicates, typed-query execution, and entity/value mapping. `VersionedSchema` remains the persistence source of truth, and feature code continues to use future semantic repositories rather than this infrastructure API directly.

**Tech Stack:** Swift 6.0 language mode, Swift 6.3.3 compiler, SwiftData, Foundation, OSLog, Synchronization, Swift Testing, XCTest UI tests, Xcode 26.6; no third-party persistence, repository, query, migration, logging, or type-erasure dependency.

## Global Constraints

- Treat `docs/superpowers/specs/2026-08-12-generic-local-database-design.md` as normative. If implementation evidence contradicts it, stop, amend the spec, and obtain review before continuing.
- Use `c4d4af99538af06f6f0b958495143a09c6229037` as the immutable pre-implementation baseline. It contains the approved spec and the current Example-specific implementation.
- Keep `AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift` byte-for-byte unchanged. Its required SHA-256 is `1b83fc638ba3ba8d3f628459d1f1081daee45a30dc7f4d664417a107b8aef706`, and its Git blob is `a85232942d6b193060be754a7979d6ea4ef04b93`.
- Keep deployment targets at iOS/iPadOS/macOS 26.0, `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and approachable concurrency enabled.
- Mark cross-actor value contracts, adapters, registry/configuration types, helpers, and test fixtures explicitly `nonisolated` where required by the MainActor default. `LocalEntityAdapter` must refine `SendableMetatype`; the registry itself must be `Sendable`.
- Keep SwiftData references inside `AppTemplate/App/Services/LocalDatabase`. Test-only SwiftData references stay inside `AppTemplateTests/App/Services/LocalDatabase` or `AppTemplateTests/TestSupport/LocalDatabase`.
- `LocalDatabaseModel` means a detached local-persistence record, not a product Domain entity. Features, ViewModels, and Domain protocols must not reference `LocalDatabaseModel`, `LocalEntityAdapter`, SwiftData, or the raw generic database.
- Keep `ExampleRecord` immutable, `Codable`, `Equatable`, `Identifiable`, and `Sendable`. Preserve its exact String ID and payload. Keep `ExampleQuery` byte-for-byte unchanged unless compiler formatting is required; its current default limit remains 50.
- The model/Query/adapter association is compile-time. Authorization by one service instance is runtime registry metadata. The registry never generates a schema and never dynamically dispatches associated-type operations.
- A valid registry is a nontrapping bijection across adapter, value, entity, and diagnostic-name identities. Invalid integrity maps to `.initialization` before the container factory. An unregistered adapter maps to `.validation(model:reason: .unregisteredModel)` before the factory.
- Every entity adapter has an injective `Value.ID` to business-ID mapping backed by schema-enforced uniqueness. Duplicate persistent IDs throw `LocalDatabasePersistenceInvariantError.duplicatePersistedID`; never call `Dictionary(uniqueKeysWithValues:)`, `fatalError`, `precondition`, `preconditionFailure`, or `try!` in production LocalDatabase code.
- Every storage-reaching engine operation creates one fresh autosave-disabled `ModelContext` and uses it synchronously within ModelActor isolation. No context, entity, descriptor, persistent identifier, or entity-taking closure crosses that boundary.
- Every state-changing upsert/delete-one operation explicitly saves exactly once. Unchanged upsert, empty registered batch, missing delete, and empty delete-all do not save. Nonempty delete-all executes exactly one type-level delete and zero explicit saves under Xcode 26.6.
- Preserve cancellation ordering: cancellation, pure adapter/shared validation, registry integrity, model registration, empty-batch no-op, lazy resolution, cancellation, engine work. Preserve `CancellationError` unchanged; never add a post-save or post-batch-delete cancellation check.
- A registered empty batch returns before a cached bootstrap failure and does not open the store. An unregistered empty batch fails registration. Invalid input precedes invalid registry and cached bootstrap errors. Registry integrity precedes registration.
- Diagnostics contain only operation, fixed adapter name or `LocalDatabase`, record count, error domain, and numeric code. Never log IDs, payloads, query/search values, store URLs, paths, descriptions, `userInfo`, or persistent objects.
- The test-only second model, entity, adapter, and mixed schema remain in the test target. They never enter `LocalDatabaseSchemaV1`, the production registry, production app source, preview composition, or UI-test composition.
- Keep `AppStateStore`, UserDefaults persistence, networking, navigation, Features, views, ViewModels, UI-test source, packages, build settings, schemes, entitlements, and hosted automation unchanged.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`; filesystem-synchronized groups include new Swift files automatically. Treat any Xcode project reordering as an incidental mutation that must be inspected and removed with a narrow `apply_patch` before proceeding.
- Every implementation task follows RED -> verify the intended RED -> minimal GREEN -> focused warnings-as-errors test -> mutation/self-review -> one commit. Cancellation tests use a child `Task`, never the Swift Testing runner task.
- Use quoted single-test selectors including `()` or parameter labels. Every GREEN test bundle must report `Passed`, a nonzero test count, and zero failed, skipped, or expected-failure tests.
- Create every derived-data/result root with `mktemp -d` and validate it is a real directory, not a symlink. Do not delete temporary artifacts; retain their paths in the task report.
- Store task evidence under `.superpowers/sdd/2026-08-12-generic-local-database/`; that tree is ignored by Git. Production and test edits must still use `apply_patch`.
- `ENABLE_APP_SANDBOX=NO` is a command-line override only for Task 1's baseline writer and Task 6's retained-artifact reader compatibility probes, allowing one external retained store to cross app-hosted test runs. Never change `project.pbxproj`, entitlements, schemes, or persistent build settings for it; the final gates continue to exercise the normally sandboxed product.

---

## File Map

### Create in production

- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseModel.swift` — detached local-record protocol and associated Query/adapter constraints.
- `AppTemplate/App/Services/LocalDatabase/LocalEntityAdapter.swift` — nonisolated SwiftData adapter protocol, type identities, nontrapping duplicate helpers, and persistence invariant error.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseModelRegistry.swift` — immutable adapter/value/entity/name bijection, retained integrity failure, authorization lookup, and production registry.
- `AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift` — Example validation, predicates, normalized query, mapping, and conformance to the unchanged V1 entity.

### Modify in production

- `AppTemplate/App/Models/Local/ExampleRecord.swift` — add `Identifiable`; do not alter fields or serialization.
- `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift` — replace six specialized requirements with the six generic requirements.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift` — add model metadata and unregistered-model validation.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift` — require explicit entity/component name instead of hard-coding Example.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift` — add shared homogeneous generic batch validation and remove Example-only overloads at cutover.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift` — add immutable factory+registry configuration and live/disk/in-memory configuration factories.
- `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift` — make all six operations generic and delegate entity-specific work to `Model.Persistence`.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift` — generic facade, registry precedence, lazy state machine, and configuration-only initializer.
- `AppTemplate/App/AppDependencies/AppDependencies.swift` — compose whole live/in-memory configurations.

### Intentionally unchanged production files

- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift`
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreHooks.swift`
- `AppTemplate/App/Models/Local/ExampleQuery.swift`
- every file under Features, ApplicationState, Navigation, Networking, Entry, and UI tests.

### Create in tests

- `AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift` — Example adapter validation, identity, and duplicate-safe behavior.
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift` — registry integrity, bijection, and schema-cardinality tests.
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreGenericModelTests.swift` — second-model CRUD/query/coexistence/isolation proofs.
- `AppTemplateTests/App/Services/LocalDatabase/Fixtures/LocalDatabaseQueryMismatchCompileFixture.swift` — opt-in compile-fail proof for mismatched Query types.
- `AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift` — test-only Int ID, Query, entity, adapter, mixed container, registry, and configuration helpers.

### Modify in tests

- `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift`
- `AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift`
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift`
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

### Modify documentation

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CUSTOMIZATION.md`
- `docs/RELEASE_CHECKLIST.md`

---

### Task 1: Capture the Pre-Refactor Store and Add Generic Record/Adapter Contracts

**Files:**

- Temporarily create, then delete with `apply_patch`: `AppTemplateTests/App/Services/LocalDatabase/PreRefactorBaselineExporterTests.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseModel.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalEntityAdapter.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift`
- Modify: `AppTemplate/App/Models/Local/ExampleRecord.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift`
- Modify: `AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift`

**Interfaces:**

- Consumes: frozen `LocalDatabaseSchemaV1.StoredExampleRecord`, current Example-specific service solely for the one-time baseline writer, current `ExampleRecord`, current `ExampleQuery`.
- Produces: `LocalDatabaseModel`, `LocalEntityAdapter`, `LocalDatabasePersistenceInvariantError`, `ExampleRecordAdapter`, `ExampleRecord: Identifiable & LocalDatabaseModel`, and `LocalDatabaseValidator.validate(values:)`.

- [ ] **Step 1: Verify the immutable baseline before writing anything**

Run:

```bash
set -euo pipefail

test "$(git merge-base c4d4af99538af06f6f0b958495143a09c6229037 HEAD)" \
  = 'c4d4af99538af06f6f0b958495143a09c6229037'
test -z "$(git status --porcelain)"
test "$({
  shasum -a 256 \
    AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift
} | awk '{print $1}')" \
  = '1b83fc638ba3ba8d3f628459d1f1081daee45a30dc7f4d664417a107b8aef706'
test "$(git hash-object \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift)" \
  = 'a85232942d6b193060be754a7979d6ea4ef04b93'

baseline_root="$(
  mktemp -d \
    /tmp/AppTemplate-GenericLocalDatabase-baseline-c4d4af9.XXXXXX
)"
test -d "$baseline_root"
test ! -L "$baseline_root"
printf 'Baseline root to record: %s\n' "$baseline_root"
```

Expected: exit 0 and a unique root path. Immediately record that exact path, using `apply_patch`, as the single line `Baseline root: /tmp/...` in ignored evidence file `.superpowers/sdd/2026-08-12-generic-local-database/baseline-root.txt`. Every later baseline command reads this manifest. If a partial attempt fails, retain its artifacts, create a new unique root, and update the manifest with `apply_patch`; never delete or overwrite the failed root.

- [ ] **Step 2: Add the temporary pre-refactor exporter**

Create `PreRefactorBaselineExporterTests.swift` exactly as follows:

```swift
import Foundation
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct PreRefactorBaselineExporterTests {
    @Test
    func exportsExampleSpecificDiskStore() async throws {
        let rawRoot = try #require(
            ProcessInfo.processInfo.environment[
                "APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT"
            ]
        )
        let root = URL(
            fileURLWithPath: rawRoot,
            isDirectory: true
        ).standardizedFileURL
        let storeURL = root.appending(
            path: "LocalDatabase.store",
            directoryHint: .notDirectory
        )

        #expect(!FileManager.default.fileExists(atPath: storeURL.path))

        let service: any ILocalDatabaseService = LocalDatabaseService(
            containerFactory:
                LocalDatabaseContainerFactories.disk(url: storeURL)
        )

        try await service.upsert([
            ExampleRecord(id: "01-updated", payload: "before-update"),
            ExampleRecord(id: "02-unicode", payload: "Crème 東京 β"),
            ExampleRecord(id: "03-empty", payload: ""),
            ExampleRecord(id: "04-Case-ID", payload: "uppercase"),
            ExampleRecord(id: "05-case-id", payload: "lowercase"),
            ExampleRecord(id: "99-delete", payload: "must disappear")
        ])
        try await service.upsert(
            ExampleRecord(id: "01-updated", payload: "after-update")
        )
        let didDelete = try await service.deleteRecord(id: "99-delete")
        #expect(didDelete)

        let expected = [
            ExampleRecord(id: "01-updated", payload: "after-update"),
            ExampleRecord(id: "02-unicode", payload: "Crème 東京 β"),
            ExampleRecord(id: "03-empty", payload: ""),
            ExampleRecord(id: "04-Case-ID", payload: "uppercase"),
            ExampleRecord(id: "05-case-id", payload: "lowercase")
        ]
        let actual = try await service.fetchRecords(
            matching: ExampleQuery(limit: 200)
        )
        #expect(actual == expected)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(expected).write(
            to: root.appending(path: "expected.json"),
            options: .atomic
        )
    }
}
```

- [ ] **Step 3: Export and validate the pre-refactor store through an injected macOS test run**

Run:

```bash
set -euo pipefail

baseline_manifest='.superpowers/sdd/2026-08-12-generic-local-database/baseline-root.txt'
test -f "$baseline_manifest"
baseline_root="$(sed -n 's/^Baseline root: //p' "$baseline_manifest")"
case "$baseline_root" in
  /tmp/AppTemplate-GenericLocalDatabase-baseline-c4d4af9.*) ;;
  *) exit 1 ;;
esac
test -d "$baseline_root"
test ! -L "$baseline_root"

writer_derived_data="$baseline_root/DerivedData-writer"
writer_products="$writer_derived_data/Build/Products"
writer_xcresult="$baseline_root/writer.xcresult"
test ! -e "$writer_derived_data"
test ! -e "$writer_xcresult"

xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$writer_derived_data" \
  ENABLE_APP_SANDBOX=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

test -d "$writer_products"
xctestrun_matches="$(
  find "$writer_products" -maxdepth 1 -type f \
    -name 'AppTemplate_macosx*-arm64.xctestrun' -print
)"
xctestrun_match_count="$(
  printf '%s\n' "$xctestrun_matches" | sed '/^$/d' | wc -l | tr -d ' '
)"
test "$xctestrun_match_count" -eq 1
generated_xctestrun="$(
  printf '%s\n' "$xctestrun_matches" | sed '/^$/d'
)"
test -f "$generated_xctestrun"
test ! -L "$generated_xctestrun"

writer_xctestrun="$writer_products/AppTemplate_BaselineWriterInjected.xctestrun"
test ! -e "$writer_xctestrun"
cp "$generated_xctestrun" "$writer_xctestrun"
plutil -insert \
  'AppTemplateTests.EnvironmentVariables.APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT' \
  -string "$baseline_root" \
  "$writer_xctestrun"
test "$(
  plutil -extract \
    'AppTemplateTests.EnvironmentVariables.APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT' \
    raw -o - "$writer_xctestrun"
)" = "$baseline_root"

xcodebuild test-without-building \
  -xctestrun "$writer_xctestrun" \
  -destination 'platform=macOS,arch=arm64' \
  -resultBundlePath "$writer_xcresult" \
  '-only-testing:AppTemplateTests/PreRefactorBaselineExporterTests/exportsExampleSpecificDiskStore()'

xcrun xcresulttool get test-results summary \
  --path "$writer_xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount == 1
    and .passedTests == 1
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

test -f "$baseline_root/LocalDatabase.store"
test -f "$baseline_root/expected.json"
jq -e '
  . == [
    {"id":"01-updated","payload":"after-update"},
    {"id":"02-unicode","payload":"Crème 東京 β"},
    {"id":"03-empty","payload":""},
    {"id":"04-Case-ID","payload":"uppercase"},
    {"id":"05-case-id","payload":"lowercase"}
  ]
' "$baseline_root/expected.json"
```

Expected: `build-for-testing` creates exactly one matching arm64 macOS `.xctestrun`; the copied adjacent configuration contains the exact retained-root value under `AppTemplateTests.EnvironmentVariables`; the exact method selector runs once, passes, and leaves both the disk store and exact JSON oracle under the fixed baseline root. The command-line sandbox override applies only to this compatibility probe, not to project settings or final gates.

- [ ] **Step 4: Remove the temporary exporter before implementation changes**

Delete only `PreRefactorBaselineExporterTests.swift` with `apply_patch`, then run:

```bash
set -euo pipefail
test ! -e \
  AppTemplateTests/App/Services/LocalDatabase/PreRefactorBaselineExporterTests.swift
test -z "$(git status --porcelain)"
baseline_manifest='.superpowers/sdd/2026-08-12-generic-local-database/baseline-root.txt'
baseline_root="$(sed -n 's/^Baseline root: //p' "$baseline_manifest")"
test -f "$baseline_root/LocalDatabase.store"
test -f "$baseline_root/expected.json"
```

- [ ] **Step 5: Write contract and Example-adapter RED tests**

Create `ExampleRecordAdapterTests.swift` with these exact behaviors:

```swift
import SwiftData
import Testing
@testable import AppTemplate

struct ExampleRecordAdapterTests {
    @Test(arguments: ["", " ", "\n\t"])
    func rejectsBlankExampleIDs(id: String) {
        expectExampleValidation(.emptyID) {
            try ExampleRecordAdapter.validate(id: id)
        }
    }

    @Test
    func acceptsExactNonblankIdentityAndEmptyPayload() throws {
        let value = ExampleRecord(id: " local-42 ", payload: "")

        try ExampleRecordAdapter.validate(value: value)

        #expect(value.id == " local-42 ")
        #expect(value.payload.isEmpty)
    }

    @Test(arguments: [1, 200])
    func enforcesInclusiveExampleQueryLimits(limit: Int) throws {
        try ExampleRecordAdapter.validate(
            query: ExampleQuery(limit: limit)
        )
    }

    @Test(arguments: [0, 201])
    func rejectsOutOfRangeExampleQueryLimits(limit: Int) {
        expectExampleValidation(
            .invalidLimit(actual: limit, allowed: 1...200)
        ) {
            try ExampleRecordAdapter.validate(
                query: ExampleQuery(limit: limit)
            )
        }
    }

    @Test
    func sharedBatchValidationRejectsFiveHundredOneValues() {
        let values = (0...500).map {
            ExampleRecord(id: "record-\($0)", payload: "value")
        }

        expectExampleValidation(
            .batchTooLarge(actual: 501, maximum: 500)
        ) {
            try LocalDatabaseValidator.validate(values: values)
        }
    }

    @Test
    func sharedBatchValidationRejectsExactDuplicateIDs() {
        expectExampleValidation(.duplicateID) {
            try LocalDatabaseValidator.validate(values: [
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
    }

    @Test
    func caseDistinctExampleIDsRemainDistinct() throws {
        try LocalDatabaseValidator.validate(values: [
            ExampleRecord(id: "same", payload: "one"),
            ExampleRecord(id: "SAME", payload: "two")
        ])
    }

    @Test
    func duplicatePersistedIDsThrowInsteadOfTrapping() {
        let first = LocalDatabaseSchemaV1.StoredExampleRecord(
            id: "same",
            payload: "one"
        )
        let second = LocalDatabaseSchemaV1.StoredExampleRecord(
            id: "same",
            payload: "two"
        )

        #expect(throws: LocalDatabasePersistenceInvariantError.self) {
            _ = try ExampleRecordAdapter.entitiesByID([first, second])
        }
    }
}

private func expectExampleValidation(
    _ expected: LocalDatabaseValidationError,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected LocalDatabaseValidationError")
    } catch let error as LocalDatabaseValidationError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}
```

Replace the validator-specific tests in `LocalDatabaseContractTests.swift` with association/schema tests:

```swift
import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseContractTests {
    @Test
    func exampleQueryDefaultsToUnfilteredFiftyRecordLimit() {
        let query = ExampleQuery()

        #expect(query.searchText == nil)
        #expect(query.limit == 50)
    }

    @Test
    func exampleRecordUsesStringIDExampleQueryAndExampleAdapter() {
        requireModelAssociation(
            ExampleRecord.self,
            id: String.self,
            query: ExampleQuery.self,
            adapter: ExampleRecordAdapter.self
        )
    }

    @Test
    func schemaRemainsFrozenAtV1WithoutMigrationStages() {
        #expect(
            LocalDatabaseSchemaV1.versionIdentifier
                == Schema.Version(1, 0, 0)
        )
        #expect(LocalDatabaseSchemaV1.models.count == 1)
        #expect(LocalDatabaseMigrationPlan.schemas.count == 1)
        #expect(LocalDatabaseMigrationPlan.stages.isEmpty)
    }
}

private func requireModelAssociation<Model: LocalDatabaseModel>(
    _ model: Model.Type,
    id: Model.ID.Type,
    query: Model.Query.Type,
    adapter: Model.Persistence.Type
) {
    _ = model
    _ = id
    _ = query
    _ = adapter
}
```

Add this test to `ExampleLocalModelTests.swift` while retaining its existing Codable round trip:

```swift
@Test
func recordIdentityRemainsExact() {
    let record = ExampleRecord(id: " local-42 ", payload: "value")

    #expect(record.id == " local-42 ")
}
```

- [ ] **Step 6: Run focused RED and verify missing generic symbols**

Run:

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task1-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/ExampleRecordAdapterTests \
  -only-testing:AppTemplateTests/ExampleLocalModelTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -n 'LocalDatabaseModel|LocalEntityAdapter|ExampleRecordAdapter|LocalDatabasePersistenceInvariantError' \
  "$red_root/xcodebuild.log"
```

Expected: nonzero because the new contracts and adapter do not exist. A destination, selector, or syntax failure is not an acceptable RED.

- [ ] **Step 7: Implement the generic record and adapter contracts**

Create `LocalDatabaseModel.swift`:

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

Create `LocalEntityAdapter.swift`:

```swift
import SwiftData

nonisolated
enum LocalDatabasePersistenceInvariantError:
    Error,
    Equatable,
    Sendable
{
    case duplicatePersistedID
}

nonisolated
protocol LocalEntityAdapter: SendableMetatype
where Value.Persistence == Self, Value.Query == Query {
    associatedtype Value: LocalDatabaseModel
    associatedtype Entity: PersistentModel
    associatedtype Query: Sendable

    static var diagnosticName: String { get }
    static var adapterIdentifier: ObjectIdentifier { get }
    static var valueIdentifier: ObjectIdentifier { get }
    static var entityIdentifier: ObjectIdentifier { get }

    static func validate(id: Value.ID) throws
    static func validate(value: Value) throws
    static func validate(query: Query) throws
    static func fetch(
        id: Value.ID,
        in context: ModelContext
    ) throws -> Entity?
    static func fetchExisting(
        ids: [Value.ID],
        in context: ModelContext
    ) throws -> [Entity]
    static func fetch(
        matching query: Query,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity]
    static func attemptedRecordCount(for query: Query) -> Int
    static func id(of entity: Entity) -> Value.ID
    static func value(from entity: Entity) -> Value
    static func makeEntity(from value: Value) -> Entity
    static func update(_ entity: Entity, from value: Value) -> Bool
}

nonisolated
extension LocalEntityAdapter {
    static var adapterIdentifier: ObjectIdentifier {
        ObjectIdentifier(Self.self)
    }

    static var valueIdentifier: ObjectIdentifier {
        ObjectIdentifier(Value.self)
    }

    static var entityIdentifier: ObjectIdentifier {
        ObjectIdentifier(Entity.self)
    }

    static func uniqueEntity(
        from entities: [Entity]
    ) throws -> Entity? {
        guard entities.count <= 1 else {
            throw LocalDatabasePersistenceInvariantError
                .duplicatePersistedID
        }
        return entities.first
    }

    static func entitiesByID(
        _ entities: [Entity]
    ) throws -> [Value.ID: Entity] {
        var result: [Value.ID: Entity] = [:]
        for entity in entities {
            let businessID = id(of: entity)
            guard result.updateValue(entity, forKey: businessID) == nil else {
                throw LocalDatabasePersistenceInvariantError
                    .duplicatePersistedID
            }
        }
        return result
    }
}
```

Change the declaration in `ExampleRecord.swift` to:

```swift
nonisolated
struct ExampleRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let payload: String
}
```

Add the shared generic overload to `LocalDatabaseValidator` without removing its legacy Example overloads yet:

```swift
static func validate<Model: LocalDatabaseModel>(
    values: [Model]
) throws {
    guard values.count <= maximumBatchSize else {
        throw LocalDatabaseValidationError.batchTooLarge(
            actual: values.count,
            maximum: maximumBatchSize
        )
    }

    var identities = Set<Model.ID>()
    for value in values {
        try Model.Persistence.validate(value: value)
        guard identities.insert(value.id).inserted else {
            throw LocalDatabaseValidationError.duplicateID
        }
    }
}
```

Create `Adapters/ExampleRecordAdapter.swift`:

```swift
import Foundation
import SwiftData

nonisolated
extension ExampleRecord: LocalDatabaseModel {
    typealias Query = ExampleQuery
    typealias Persistence = ExampleRecordAdapter
}

nonisolated
enum ExampleRecordAdapter: LocalEntityAdapter {
    typealias Value = ExampleRecord
    typealias Entity = LocalDatabaseSchemaV1.StoredExampleRecord
    typealias Query = ExampleQuery

    static let diagnosticName = "StoredExampleRecord"
    private static let queryLimitRange = 1...200

    static func validate(id: String) throws {
        guard id.contains(where: { !$0.isWhitespace }) else {
            throw LocalDatabaseValidationError.emptyID
        }
    }

    static func validate(value: ExampleRecord) throws {
        try validate(id: value.id)
    }

    static func validate(query: ExampleQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func fetch(
        id: String,
        in context: ModelContext
    ) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 2
        return try uniqueEntity(from: context.fetch(descriptor))
    }

    static func fetchExisting(
        ids: [String],
        in context: ModelContext
    ) throws -> [Entity] {
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        return try context.fetch(descriptor)
    }

    static func fetch(
        matching query: ExampleQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [Entity] {
        var descriptor = FetchDescriptor<Entity>(
            sortBy: [SortDescriptor(\Entity.id)]
        )
        guard let normalizedSearch = normalizedSearch(query.searchText) else {
            descriptor.fetchLimit = query.limit
            return try context.fetch(descriptor)
        }

        descriptor.includePendingChanges = false
        let entities = try context.fetch(descriptor, batchSize: 128)
        var matches: [Entity] = []
        var examinedCount = 0

        for entity in entities {
            examinedCount += 1
            let normalizedPayload = entity.payload.folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale: nil
            )
            if normalizedPayload.contains(normalizedSearch) {
                matches.append(entity)
            }
            if examinedCount.isMultiple(of: 128) {
                try progress(examinedCount)
            }
            if matches.count == query.limit {
                return matches
            }
        }

        return matches
    }

    static func attemptedRecordCount(for query: ExampleQuery) -> Int {
        query.limit
    }

    static func id(of entity: Entity) -> String { entity.id }

    static func value(from entity: Entity) -> ExampleRecord {
        ExampleRecord(id: entity.id, payload: entity.payload)
    }

    static func makeEntity(from value: ExampleRecord) -> Entity {
        Entity(id: value.id, payload: value.payload)
    }

    static func update(
        _ entity: Entity,
        from value: ExampleRecord
    ) -> Bool {
        guard entity.payload != value.payload else { return false }
        entity.payload = value.payload
        return true
    }

    private static func normalizedSearch(
        _ searchText: String?
    ) -> String? {
        guard let searchText else { return nil }
        let trimmed = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(
            options: [
                .caseInsensitive,
                .diacriticInsensitive,
                .widthInsensitive
            ],
            locale: nil
        )
    }
}
```

- [ ] **Step 8: Run focused GREEN and strict result assertions**

Run:

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task1-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/ExampleRecordAdapterTests \
  -only-testing:AppTemplateTests/ExampleLocalModelTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "LocalDatabaseContractTests",
    "ExampleRecordAdapterTests",
    "ExampleLocalModelTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select(
          $suite == null
          or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0
        )
      | $name]
    | length == 0
  '
```

Expected: all selected tests pass, with no warning promoted to an error.

- [ ] **Step 9: Run mutation and scope checks**

Run both immediate mutation probes and restore each change with `apply_patch` before continuing:

1. Change `ExampleRecordAdapter.validate(id:)` to accept every nonempty string. Run `'-only-testing:AppTemplateTests/ExampleRecordAdapterTests/rejectsBlankExampleIDs(id:)'`; it must fail because whitespace-only IDs are accepted.
2. Change `entitiesByID(_:)` to overwrite a prior value instead of throwing. Run `'-only-testing:AppTemplateTests/ExampleRecordAdapterTests/duplicatePersistedIDsThrowInsteadOfTrapping()'`; it must fail.

After restoring both mutations, rerun the focused GREEN command from Step 8 and then run:

```bash
set -euo pipefail

test "$({
  shasum -a 256 \
    AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift
} | awk '{print $1}')" \
  = '1b83fc638ba3ba8d3f628459d1f1081daee45a30dc7f4d664417a107b8aef706'

if rg -n 'Dictionary\(uniqueKeysWithValues:' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi
if rg -n 'fatalError|precondition(Failure)?|try!' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi
git diff --check
```

Expected: both mutations are detected, the restored focused suite passes, and all static checks are clean.

- [ ] **Step 10: Commit Task 1**

```bash
set -euo pipefail
git add \
  AppTemplate/App/Models/Local/ExampleRecord.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseModel.swift \
  AppTemplate/App/Services/LocalDatabase/LocalEntityAdapter.swift \
  AppTemplate/App/Services/LocalDatabase/Adapters/ExampleRecordAdapter.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift \
  AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift \
  AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift
git diff --cached --check
git commit -m "refactor: define generic local database records"
test -z "$(git status --porcelain)"
```

Expected: one focused commit. The baseline store remains only under `/tmp`; the temporary exporter is absent from Git.

---

### Task 2: Add the Model Registry and Bundle It with Store Configuration

**Files:**

- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseModelRegistry.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift`
- Modify: `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift`

**Interfaces:**

- Consumes: `LocalEntityAdapter` identities and the unchanged V1 schema.
- Produces: a nontrapping `LocalDatabaseModelRegistry`, its deterministic integrity errors, and `LocalDatabaseStoreConfiguration` that always carries both a container factory and registry.
- Compatibility: keep `LocalDatabaseContainerFactories` during this task because the legacy facade still consumes a factory until Task 5.

- [ ] **Step 1: Write registry/configuration RED tests**

Create `LocalDatabaseModelRegistryTests.swift` with these tests:

```swift
import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseModelRegistryTests {
    @Test
    func productionRegistryContainsExactlyExampleRegistration() throws {
        let registry = LocalDatabaseModelRegistry.production

        try registry.validateIntegrity()
        #expect(registry.registrationCount == 1)
        #expect(registry.contains(ExampleRecordAdapter.self))
        #expect(
            registry.registeredEntityIdentifiers
                == [ObjectIdentifier(
                    LocalDatabaseSchemaV1.StoredExampleRecord.self
                )]
        )
    }

    @Test
    func productionRegistryEntityTypesEqualFrozenSchemaTypesAndCardinality() throws {
        let registry = LocalDatabaseModelRegistry.production
        let schemaIdentifiers = Set(
            LocalDatabaseSchemaV1.models.map(ObjectIdentifier.init)
        )

        try registry.validateIntegrity()
        #expect(registry.registrationCount == schemaIdentifiers.count)
        #expect(registry.registeredEntityIdentifiers == schemaIdentifiers)
    }

    @Test(arguments: RegistryCollisionFixture.allCases)
    func duplicateIdentityIsRejectedWithoutTrapping(
        fixture: RegistryCollisionFixture
    ) {
        #expect(
            LocalDatabaseRegistrationIdentityValidator
                .firstIntegrityError(in: fixture.identities)
                == fixture.expectedError
        )
    }

    @Test
    func integrityFailureUsesAdapterValueEntityNamePriority() {
        let identity = LocalDatabaseRegistrationIdentity(
            adapterIdentifier: ObjectIdentifier(IdentityA.self),
            valueIdentifier: ObjectIdentifier(IdentityB.self),
            entityIdentifier: ObjectIdentifier(IdentityC.self),
            diagnosticName: "duplicate"
        )
        #expect(
            LocalDatabaseRegistrationIdentityValidator
                .firstIntegrityError(in: [identity, identity])
                == .duplicateAdapter
        )
    }
}
```

Define `nonisolated enum RegistryCollisionFixture: CaseIterable, CustomTestStringConvertible, Sendable` and `nonisolated private enum IdentityA` through `IdentityH` in the same test file. Each fixture supplies two synthetic `LocalDatabaseRegistrationIdentity` values that collide in exactly one dimension and expects respectively `.duplicateAdapter`, `.duplicateValue`, `.duplicateEntity`, or `.duplicateDiagnosticName`. Synthetic identities exercise only the pure validator; no registry can be constructed from metadata unrelated to its retained adapter metatypes. Add a separate invalid-registry assertion using `LocalDatabaseModelRegistry(adapters: [ExampleRecordAdapter.self, ExampleRecordAdapter.self])` and require `.duplicateAdapter`.

Update `LocalDatabaseStoreConfigurationTests.swift`:

- Rename `liveFactoryDoesNotResolveLocationUntilInvoked` to `liveConfigurationDoesNotResolveLocationUntilFactoryInvocation` and construct `.live(locationResolver:)`.
- Rename `inMemoryFactoryCreatesIndependentContainers` to `inMemoryConfigurationCreatesIndependentContainersWithProductionRegistry`; invoke `configuration.containerFactory()` twice, assert distinct in-memory containers, and assert the registry is exactly `.production` by registration/entity identity.
- Rename `diskFactoryUsesExactURLAndAllowsSave` to `diskConfigurationUsesExactURLAllowsSaveAndProductionRegistry`; construct `.disk(url:)` and preserve the exact URL/save assertions.
- Keep all resolver and schema-uniqueness tests.

Add this configuration helper to `LocalDatabaseContainerFactoryRecorder` in `LocalDatabaseTestSupport.swift`:

```swift
func configuration(
    registry: LocalDatabaseModelRegistry = .production
) -> LocalDatabaseStoreConfiguration {
    LocalDatabaseStoreConfiguration(
        containerFactory: factory,
        modelRegistry: registry
    )
}
```

- [ ] **Step 2: Run focused RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task2-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -n 'LocalDatabaseModelRegistry|LocalDatabaseStoreConfiguration|RegistrationIdentityValidator' \
  "$red_root/xcodebuild.log"
```

Expected: compilation fails only because registry/configuration symbols and initializers are absent.

- [ ] **Step 3: Implement the nontrapping registry**

Create `LocalDatabaseModelRegistry.swift` with this shape:

```swift
nonisolated
enum LocalDatabaseModelRegistryError: Error, Equatable, Sendable {
    case duplicateAdapter
    case duplicateValue
    case duplicateEntity
    case duplicateDiagnosticName
}

nonisolated
struct LocalDatabaseRegistrationIdentity: Equatable, Sendable {
    let adapterIdentifier: ObjectIdentifier
    let valueIdentifier: ObjectIdentifier
    let entityIdentifier: ObjectIdentifier
    let diagnosticName: String
}

nonisolated
struct LocalDatabaseModelRegistry: Sendable {
    private let adapters: [any LocalEntityAdapter.Type]
    private let integrityError: LocalDatabaseModelRegistryError?
    private let adapterIdentifiers: Set<ObjectIdentifier>

    let registrationCount: Int
    let registeredEntityIdentifiers: Set<ObjectIdentifier>

    init(adapters: [any LocalEntityAdapter.Type]) {
        self.adapters = adapters
        let identities = adapters.map {
            LocalDatabaseRegistrationIdentity(
                adapterIdentifier: $0.adapterIdentifier,
                valueIdentifier: $0.valueIdentifier,
                entityIdentifier: $0.entityIdentifier,
                diagnosticName: $0.diagnosticName
            )
        }
        integrityError = LocalDatabaseRegistrationIdentityValidator
            .firstIntegrityError(in: identities)
        adapterIdentifiers = Set(
            identities.map(\.adapterIdentifier)
        )
        registeredEntityIdentifiers = Set(
            identities.map(\.entityIdentifier)
        )
        registrationCount = identities.count
    }

    static let production = LocalDatabaseModelRegistry(
        adapters: [ExampleRecordAdapter.self]
    )

    func validateIntegrity() throws {
        if let integrityError { throw integrityError }
    }

    func contains<Adapter: LocalEntityAdapter>(
        _ adapter: Adapter.Type
    ) -> Bool {
        adapterIdentifiers.contains(adapter.adapterIdentifier)
    }

}

nonisolated
enum LocalDatabaseRegistrationIdentityValidator {
    static func firstIntegrityError(
        in identities: [LocalDatabaseRegistrationIdentity]
    ) -> LocalDatabaseModelRegistryError? {
        var adapterIDs = Set<ObjectIdentifier>()
        var valueIDs = Set<ObjectIdentifier>()
        var entityIDs = Set<ObjectIdentifier>()
        var names = Set<String>()

        for identity in identities {
            guard adapterIDs.insert(identity.adapterIdentifier).inserted else {
                return .duplicateAdapter
            }
            guard valueIDs.insert(identity.valueIdentifier).inserted else {
                return .duplicateValue
            }
            guard entityIDs.insert(identity.entityIdentifier).inserted else {
                return .duplicateEntity
            }
            guard names.insert(identity.diagnosticName).inserted else {
                return .duplicateDiagnosticName
            }
        }
        return nil
    }
}
```

`LocalDatabaseModelRegistry` has only `init(adapters:)`; every retained identity is derived from those exact metatypes. Synthetic identities can reach only the pure validator and therefore cannot authorize a model or claim a schema entity.

- [ ] **Step 4: Add bundled store configuration without removing factories**

Append to `LocalDatabaseStoreConfiguration.swift`:

```swift
nonisolated
struct LocalDatabaseStoreConfiguration: Sendable {
    let containerFactory: LocalDatabaseContainerFactory
    let modelRegistry: LocalDatabaseModelRegistry

    static func live(
        locationResolver: LocalDatabaseStoreLocationResolver = .live()
    ) -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.live(
                locationResolver: locationResolver
            ),
            modelRegistry: .production
        )
    }

    static func disk(url: URL) -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url),
            modelRegistry: .production
        )
    }

    static func inMemory() -> LocalDatabaseStoreConfiguration {
        LocalDatabaseStoreConfiguration(
            containerFactory: LocalDatabaseContainerFactories.inMemory(),
            modelRegistry: .production
        )
    }
}
```

Do not derive a schema from `modelRegistry`; all three factories continue to open only the frozen V1 `VersionedSchema`.

- [ ] **Step 5: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task2-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "LocalDatabaseModelRegistryTests",
    "LocalDatabaseStoreConfigurationTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select($suite == null or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0)
      | $name]
    | length == 0
  '
```

- [ ] **Step 6: Mutation-test every collision and schema cardinality**

Temporarily apply each mutation separately, run the relevant single test, observe failure, and restore it:

1. Remove `ExampleRecordAdapter.self` from `.production`; `productionRegistryContainsExactlyExampleRegistration()` must fail.
2. Make `contains(_:)` always return `false`; `productionRegistryContainsExactlyExampleRegistration()` must fail.
3. Reorder `firstIntegrityError` to test diagnostic name before adapter; `integrityFailureUsesAdapterValueEntityNamePriority()` must fail.
4. Make `.inMemory()` carry an empty registry; the configuration test must fail while container creation still succeeds.

Then rerun Step 5 and the schema SHA check from Task 1.

- [ ] **Step 7: Commit Task 2**

```bash
set -euo pipefail
git add \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseModelRegistry.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift \
  AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift
git diff --cached --check
git commit -m "refactor: register local database models"
test -z "$(git status --porcelain)"
```

---

### Task 3: Generalize Errors, Diagnostics, and the Mutation Engine

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`

**Interfaces:**

- Produces generic store operations for fetch-one, upsert-one, upsert-batch, delete-one, and delete-all.
- Keeps only temporary internal Example wrappers for `fetchRecord`, `deleteRecord`, and `deleteAllRecords` so the still-specialized facade compiles until Task 5. Generic `upsert` needs no wrapper because its call syntax is unchanged.
- Changes error/diagnostic metadata in one compile-green step; every caller pattern match is migrated in this task.

- [ ] **Step 1: Rewrite direct-store tests as RED generic calls**

In `SwiftDataLocalStoreMutationTests.swift`, replace the specialized calls with:

```swift
try await store.fetch(ExampleRecord.self, id: id)
try await store.upsert(record)
try await store.delete(ExampleRecord.self, id: id)
```

Replace every untyped empty generic batch in direct-store tests with `try await store.upsert([ExampleRecord]())`; `upsert([])` cannot infer `Model` once the generic overload is the only candidate.

Keep the existing setup and hook assertions, but use these final test names and guarantees:

- `genericInsertAndExactFetchRoundTripDetachedValue`
- `exampleEmptyPayloadRoundTripsWithoutNormalization`
- `genericUpdateChangesExistingEntityWithoutDuplicate`
- `unchangedGenericUpsertDoesNotSave`
- `missingGenericDeleteIsNoOpAndPresentDeleteSaves`
- `beforeSaveFailureRollsBackAndMapsExampleModelAndOperation`
- `realSaveFailureDiscardsStaleGenericOperationContext`
- `cancellationRaisedAfterSaveDoesNotReplaceSuccess`
- `readCheckpointFailureMapsExampleModelAndOperation`
- `diagnosticMetadataUsesModelNameAndOmitsSensitiveValues`

For every mapped error, require the exact model name:

```swift
guard case let .write(model, operation, underlying) = error else {
    Issue.record("Expected LocalDatabaseError.write")
    return
}
#expect(model == ExampleRecordAdapter.diagnosticName)
#expect(operation == .upsertOne)
```

For diagnostic metadata, pass `entityType: ExampleRecordAdapter.diagnosticName` and require that the sentinel ID, payload, search text, and disk path occur nowhere in the resulting value. Keep metadata restricted to operation/entity/count/domain/code.

In `SwiftDataLocalStoreBatchTests.swift`, replace calls with generic equivalents and lock these cases:

- `genericBatchInsertsAndUpdatesWithOneSave`
- `emptyAndFullyUnchangedGenericBatchesDoNotSave`
- `failedGenericBatchRollsBackEveryPendingChange`
- `genericDeleteAllReturnsCountUsesOneCheckpointAndNeverSaves`
- all existing before-batch-delete cancellation/failure and durability characterization cases, now calling `deleteAll(ExampleRecord.self)`;
- all mapped writes assert model `StoredExampleRecord` plus the exact operation.

Update only error case patterns in `SwiftDataLocalStoreQueryTests.swift` and `LocalDatabaseServiceTests.swift` so they expect the new model-bearing enum. Query calls and facade calls remain specialized until Tasks 4 and 5.

- [ ] **Step 2: Run focused RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task3-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -n 'no member.*fetch|no member.*delete|extraneous argument label.*model|LocalDatabaseError' \
  "$red_root/xcodebuild.log"
```

Expected: nonzero because the generic store API and model-bearing error cases do not exist. Do not accept a fixture/setup failure.

- [ ] **Step 3: Generalize validation and public error cases**

Replace `LocalDatabaseError.swift` with the same read/write operation enums plus:

```swift
nonisolated
enum LocalDatabaseValidationError: Error, Equatable, Sendable {
    case emptyID
    case invalidLimit(actual: Int, allowed: ClosedRange<Int>)
    case batchTooLarge(actual: Int, maximum: Int)
    case duplicateID
    case unregisteredModel
}

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

Update the still-specialized `LocalDatabaseService.mapValidation` to accept `model: String` and throw `.validation(model:reason:)`; every current call passes `ExampleRecordAdapter.diagnosticName`. This is temporary plumbing, not the final generic facade.

- [ ] **Step 4: Make diagnostics require explicit entity metadata**

Change both diagnostics entry points to require `entityType`:

```swift
static func metadata(
    operation: LocalDatabaseDiagnosticOperation,
    entityType: String,
    recordCount: Int,
    error: any Error
) -> LocalDatabaseFailureMetadata

static func report(
    operation: LocalDatabaseDiagnosticOperation,
    entityType: String,
    recordCount: Int,
    error: any Error
)
```

`metadata` copies only that fixed name and `NSError.domain/code`. Every read/write caller passes `Model.Persistence.diagnosticName`; initialization in `LocalDatabaseService` passes the literal `"LocalDatabase"`. Never infer entity type from the underlying error or runtime object.

- [ ] **Step 5: Implement generic fetch-one and mutations in the ModelActor**

Remove the hard-coded `storedRecord(id:in:)` helper. Retain the private `StoredRecord` alias, `value(from:)`, and `normalizedSearch(_:)` solely for the still-specialized query method until Task 4; deleting them in this task would break Task 3 GREEN. Add these actor-isolated methods to `SwiftDataLocalStore`:

```swift
func fetch<Model: LocalDatabaseModel>(
    _ type: Model.Type,
    id: Model.ID
) throws -> Model? {
    let operation = LocalDatabaseReadOperation.fetchOne
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.read(operation))
        try Task.checkCancellation()
        return try Model.Persistence.fetch(id: id, in: context)
            .map(Model.Persistence.value(from:))
    } catch {
        throw mapReadFailure(
            error,
            model: Model.Persistence.diagnosticName,
            operation: operation,
            recordCount: 1
        )
    }
}

func upsert<Model: LocalDatabaseModel>(_ value: Model) throws {
    let operation = LocalDatabaseWriteOperation.upsertOne
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()
        if let entity = try Model.Persistence.fetch(
            id: value.id,
            in: context
        ) {
            guard Model.Persistence.update(entity, from: value) else {
                return
            }
        } else {
            context.insert(Model.Persistence.makeEntity(from: value))
        }
        try save(context: context, operation: operation)
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            model: Model.Persistence.diagnosticName,
            context: context,
            operation: operation,
            recordCount: 1
        )
    }
}

func upsert<Model: LocalDatabaseModel>(_ values: [Model]) throws {
    guard !values.isEmpty else { return }
    let operation = LocalDatabaseWriteOperation.upsertBatch
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()
        let entities = try Model.Persistence.fetchExisting(
            ids: values.map(\.id),
            in: context
        )
        let entitiesByID = try Model.Persistence.entitiesByID(entities)
        var changed = false
        for value in values {
            if let entity = entitiesByID[value.id] {
                changed = Model.Persistence.update(
                    entity,
                    from: value
                ) || changed
            } else {
                context.insert(Model.Persistence.makeEntity(from: value))
                changed = true
            }
        }
        guard changed else { return }
        try save(context: context, operation: operation)
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            model: Model.Persistence.diagnosticName,
            context: context,
            operation: operation,
            recordCount: values.count
        )
    }
}

func delete<Model: LocalDatabaseModel>(
    _ type: Model.Type,
    id: Model.ID
) throws -> Bool {
    let operation = LocalDatabaseWriteOperation.deleteOne
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()
        guard let entity = try Model.Persistence.fetch(
            id: id,
            in: context
        ) else { return false }
        context.delete(entity)
        try save(context: context, operation: operation)
        return true
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            model: Model.Persistence.diagnosticName,
            context: context,
            operation: operation,
            recordCount: 1
        )
    }
}

func deleteAll<Model: LocalDatabaseModel>(
    _ type: Model.Type
) throws -> Int {
    let operation = LocalDatabaseWriteOperation.deleteAll
    try Task.checkCancellation()
    let context = makeOperationContext()
    var recordCount = 0
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()
        recordCount = try context.fetchCount(
            FetchDescriptor<Model.Persistence.Entity>()
        )
        guard recordCount > 0 else { return 0 }
        try hooks.checkpoint(.beforeBatchDelete(operation))
        try Task.checkCancellation()
        try context.delete(
            model: Model.Persistence.Entity.self,
            where: nil,
            includeSubclasses: false
        )
        return recordCount
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            model: Model.Persistence.diagnosticName,
            context: context,
            operation: operation,
            recordCount: recordCount
        )
    }
}
```

Keep fresh `ModelContext` creation, autosave disabled, pre-save cancellation, exactly one explicit save for changed non-delete-all mutations, and no post-commit cancellation check.

- [ ] **Step 6: Add temporary internal compatibility wrappers and generic failure mapping**

Keep these wrappers only until Task 5:

```swift
func fetchRecord(id: String) throws -> ExampleRecord? {
    try fetch(ExampleRecord.self, id: id)
}

func deleteRecord(id: String) throws -> Bool {
    try delete(ExampleRecord.self, id: id)
}

func deleteAllRecords() throws -> Int {
    try deleteAll(ExampleRecord.self)
}
```

Change `mapReadFailure` and `rollbackAndMapWriteFailure` to accept `model: String`, pass it to diagnostics, and construct `.read(model:operation:underlying:)` or `.write(model:operation:underlying:)`. Preserve unchanged `CancellationError`. The specialized query method remains for Task 4 but must pass `ExampleRecordAdapter.diagnosticName` into the new mapper.

- [ ] **Step 7: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task3-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "SwiftDataLocalStoreMutationTests",
    "SwiftDataLocalStoreBatchTests",
    "SwiftDataLocalStoreQueryTests",
    "LocalDatabaseServiceTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select($suite == null or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0)
      | $name]
    | length == 0
  '
```

- [ ] **Step 8: Run mutation probes for save, scope, and diagnostics**

Apply and restore each mutation separately:

1. Make `ExampleRecordAdapter.update` mutate but return `false`; `genericUpdateChangesExistingEntityWithoutDuplicate()` must fail.
2. Remove the batch `guard changed`; `emptyAndFullyUnchangedGenericBatchesDoNotSave()` must fail because the fully unchanged batch emits a save.
3. Remove `context.save()`; disk/reopen is deferred, but the existing fresh-context fetch assertion in `genericInsertAndExactFetchRoundTripDetachedValue()` must fail.
4. Invoke the whole `save(context:operation:)` helper twice; the exact `didSave` hook count must observe two saves and fail.
5. Hard-code `"StoredExampleRecord"` in the generic error mapper and require the source guard below to fail. Full runtime proof with a distinct diagnostic name follows in Task 6.

After restoration, rerun Step 7 and run:

```bash
set -euo pipefail
if rg -n 'Dictionary\(uniqueKeysWithValues:' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi
if rg -n 'entityType: "StoredExampleRecord"' \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift; then
  exit 1
fi
git diff --check
```

- [ ] **Step 9: Commit Task 3**

```bash
set -euo pipefail
git add \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift
git diff --cached --check
git commit -m "refactor: generalize local database mutations"
test -z "$(git status --porcelain)"
```

---

### Task 4: Delegate Typed Queries and Progress Cancellation to Adapters

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift`

**Interfaces:**

- Produces `SwiftDataLocalStore.fetch(Model.self, matching: Model.Query)`.
- The engine owns operation context, checkpoints, cancellation, error mapping, and entity-to-value conversion; `Model.Persistence` owns the concrete descriptor, predicate/scan, total order, and limit semantics.
- Keeps one temporary `fetchRecords(matching:)` Example wrapper only until the facade cutover in Task 5.

- [ ] **Step 1: Convert Example query tests to the generic engine**

Replace every direct-store query call with:

```swift
try await store.fetch(
    ExampleRecord.self,
    matching: ExampleQuery(...)
)
```

Preserve the existing fixtures and lock these behaviors under their current or clearer names:

- unfiltered results are ascending exact IDs and stop at limit;
- nil/empty/whitespace search disables filtering;
- case/diacritic/width-insensitive substring search returns exact values;
- filtered results preserve ID order and honor limit after filtering;
- a match beyond the first 128 fetched entities is found;
- no progress checkpoint occurs when the limit is met before 128 examined;
- a progress checkpoint occurs at the 128 boundary before returning a just-reached limit;
- cancellation/failure at `.readProgress(.fetchMany)` propagates unchanged or maps to `.read(model: ExampleRecordAdapter.diagnosticName, operation: .fetchMany, ...)`;
- the store remains usable after cancelled filtered reads.

Add pure adapter assertions to `ExampleRecordAdapterTests.swift` for:

```swift
@Test
func attemptedExampleQueryCountUsesValidatedLimit() {
    #expect(
        ExampleRecordAdapter.attemptedRecordCount(
            for: ExampleQuery(limit: 37)
        ) == 37
    )
}
```

- [ ] **Step 2: Run focused RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task4-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/ExampleRecordAdapterTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -n 'no exact matches in call|extraneous argument label.*matching|incorrect argument label.*matching|no member.*fetch' \
  "$red_root/xcodebuild.log"
```

Expected: the generic typed-query overload is missing; test fixtures and destinations are otherwise valid.

- [ ] **Step 3: Add the generic typed-query engine method**

Replace the hard-coded `fetchRecords(matching:)` body with:

```swift
func fetch<Model: LocalDatabaseModel>(
    _ type: Model.Type,
    matching query: Model.Query
) throws -> [Model] {
    let operation = LocalDatabaseReadOperation.fetchMany
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.read(operation))
        try Task.checkCancellation()
        let entities = try Model.Persistence.fetch(
            matching: query,
            in: context,
            progress: { _ in
                try hooks.checkpoint(.readProgress(operation))
                try Task.checkCancellation()
            }
        )
        try Task.checkCancellation()
        return entities.map(Model.Persistence.value(from:))
    } catch {
        throw mapReadFailure(
            error,
            model: Model.Persistence.diagnosticName,
            operation: operation,
            recordCount:
                Model.Persistence.attemptedRecordCount(for: query)
        )
    }
}
```

The `type` argument exists to select `Model` and pair the associated Query at compile time; add `_ = type` only if Swift warns under the actual compiler. Do not type-erase Query or inspect it in the engine.

Keep this temporary wrapper for the old facade:

```swift
func fetchRecords(
    matching query: ExampleQuery
) throws -> [ExampleRecord] {
    try fetch(ExampleRecord.self, matching: query)
}
```

Delete the engine’s hard-coded `normalizedSearch`, `StoredExampleRecord` descriptors, and payload scanning. Those now exist only in `ExampleRecordAdapter`.

- [ ] **Step 4: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task4-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/ExampleRecordAdapterTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "SwiftDataLocalStoreQueryTests",
    "ExampleRecordAdapterTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select($suite == null or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0)
      | $name]
    | length == 0
  '
```

- [ ] **Step 5: Mutation-test boundary ordering**

Apply and restore these mutations one at a time:

1. Move the adapter `progress` call after the `matches.count == query.limit` return; the 128th-match cancellation test must fail.
2. Apply `descriptor.fetchLimit = query.limit` before Example in-memory filtering; the beyond-first-batch test must fail.
3. Remove the unique ID sort descriptor from Example adapter; the exact-order fixture must fail.

After restoring, rerun Step 4 and verify there is no `ExampleQuery`, `StoredExampleRecord`, `.payload`, or `normalizedSearch` reference in `SwiftDataLocalStore.swift` except the three-line temporary compatibility wrapper.

- [ ] **Step 6: Commit Task 4**

```bash
set -euo pipefail
git add \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/ExampleRecordAdapterTests.swift
git diff --cached --check
git commit -m "refactor: delegate typed local database queries"
test -z "$(git status --porcelain)"
```

---

### Task 5: Cut Over the Public Generic Facade and Dependency Composition

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Create: `AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift`
- Modify: `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

**Interfaces:**

- Replaces all six specialized protocol/facade methods immediately with compile-time generic methods.
- Makes `LocalDatabaseStoreConfiguration` the only facade initializer dependency.
- Enforces the normative precedence before any store resolution.
- Adds a second test-only model solely to prove unregistered authorization and generic existential conformance; it does not enter a container until Task 6.

- [ ] **Step 1: Add the second-model and generic-test-double fixtures**

Create `GenericLocalDatabaseTestSupport.swift` with these exact detached types:

```swift
import Foundation
import SwiftData
@testable import AppTemplate

nonisolated
struct TestLocalRecordID: Hashable, Sendable {
    let rawValue: Int
}

nonisolated
struct TestLocalQuery: Equatable, Sendable {
    let minimumScore: Int?
    let limit: Int

    init(minimumScore: Int? = nil, limit: Int = 10) {
        self.minimumScore = minimumScore
        self.limit = limit
    }
}

nonisolated
struct TestLocalRecord: Identifiable, Equatable, Sendable,
    LocalDatabaseModel
{
    typealias Query = TestLocalQuery
    typealias Persistence = TestLocalRecordAdapter

    let id: TestLocalRecordID
    let score: Int
    let title: String
}

@Model
nonisolated final class StoredTestLocalRecord {
    @Attribute(.unique) var businessID: Int
    var score: Int
    var title: String

    init(businessID: Int, score: Int, title: String) {
        self.businessID = businessID
        self.score = score
        self.title = title
    }
}
```

Define `nonisolated enum GenericLocalDatabaseFixtureError: Error, Sendable { case storageNotImplemented }` and `nonisolated enum TestLocalRecordAdapter: LocalEntityAdapter` in the same file. At this stage, implement identity, validation, attempted-count, mapping, entity construction, and update exactly, but have its three storage-facing fetch methods throw `.storageNotImplemented`. This makes the type a valid compile-time model/adapter fixture for unregistered checks without pretending its mixed-store behavior is implemented before Task 6. Its final contract is fixed:

- `diagnosticName == "StoredTestLocalRecord"`;
- ID mapping is exactly `TestLocalRecordID.rawValue <-> businessID`;
- ID validation accepts every `Int` identity;
- query validation permits only `1...200`;
- `fetch(id:)` and `fetchExisting(ids:)` use `businessID` predicates and duplicate-safe adapter helpers;
- Task 6 replaces the temporary storage throws with query order `score` ascending then unique `businessID` ascending;
- Task 6 applies `minimumScore` during the scan, not as engine knowledge;
- Task 6 invokes progress after every 128 examined entities and before a just-reached limit returns;
- mapping/update preserve exact `score` and `title`.

Use this exact Task 5 adapter scaffold so the target compiles and unregistered validation is real while storage behavior remains RED for Task 6:

```swift
nonisolated
enum GenericLocalDatabaseFixtureError: Error, Sendable {
    case storageNotImplemented
}

nonisolated
enum TestLocalRecordAdapter: LocalEntityAdapter {
    typealias Value = TestLocalRecord
    typealias Entity = StoredTestLocalRecord
    typealias Query = TestLocalQuery

    static let diagnosticName = "StoredTestLocalRecord"
    private static let queryLimitRange = 1...200

    static func validate(id: TestLocalRecordID) throws {}

    static func validate(value: TestLocalRecord) throws {}

    static func validate(query: TestLocalQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func fetch(
        id: TestLocalRecordID,
        in context: ModelContext
    ) throws -> StoredTestLocalRecord? {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func fetchExisting(
        ids: [TestLocalRecordID],
        in context: ModelContext
    ) throws -> [StoredTestLocalRecord] {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func fetch(
        matching query: TestLocalQuery,
        in context: ModelContext,
        progress: (_ examinedCount: Int) throws -> Void
    ) throws -> [StoredTestLocalRecord] {
        throw GenericLocalDatabaseFixtureError.storageNotImplemented
    }

    static func attemptedRecordCount(for query: TestLocalQuery) -> Int {
        query.limit
    }

    static func id(
        of entity: StoredTestLocalRecord
    ) -> TestLocalRecordID {
        TestLocalRecordID(rawValue: entity.businessID)
    }

    static func value(
        from entity: StoredTestLocalRecord
    ) -> TestLocalRecord {
        TestLocalRecord(
            id: TestLocalRecordID(rawValue: entity.businessID),
            score: entity.score,
            title: entity.title
        )
    }

    static func makeEntity(
        from value: TestLocalRecord
    ) -> StoredTestLocalRecord {
        StoredTestLocalRecord(
            businessID: value.id.rawValue,
            score: value.score,
            title: value.title
        )
    }

    static func update(
        _ entity: StoredTestLocalRecord,
        from value: TestLocalRecord
    ) -> Bool {
        guard entity.score != value.score
            || entity.title != value.title
        else { return false }
        entity.score = value.score
        entity.title = value.title
        return true
    }
}
```

Add helpers, but do not use the mixed container in production:

```swift
nonisolated
func makeGenericTestRegistry() -> LocalDatabaseModelRegistry {
    LocalDatabaseModelRegistry(adapters: [
        ExampleRecordAdapter.self,
        TestLocalRecordAdapter.self
    ])
}

nonisolated
func makeGenericInMemoryLocalDatabaseContainer() throws -> ModelContainer {
    let schema = Schema([
        LocalDatabaseSchemaV1.StoredExampleRecord.self,
        StoredTestLocalRecord.self
    ])
    let configuration = ModelConfiguration(
        "GenericLocalDatabaseTests",
        schema: schema,
        isStoredInMemoryOnly: true,
        allowsSave: true,
        groupContainer: .none,
        cloudKitDatabase: .none
    )
    return try ModelContainer(
        for: schema,
        configurations: [configuration]
    )
}

nonisolated
func makeGenericTestConfiguration() -> LocalDatabaseStoreConfiguration {
    LocalDatabaseStoreConfiguration(
        containerFactory: {
            try makeGenericInMemoryLocalDatabaseContainer()
        },
        modelRegistry: makeGenericTestRegistry()
    )
}
```

Also add to `LocalDatabaseTestSupport.swift` in this task:

```swift
nonisolated
func resultOfChildTask<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> Result<Value, any Error> {
    await Task {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }.value
}
```

This file belongs only to `AppTemplateTests`; the production source scan must never find these symbols.

- [ ] **Step 2: Write public-facade and composition RED tests**

Rewrite all calls in `LocalDatabaseServiceTests.swift`, `LocalDatabaseContractTests.swift`, `LocalDatabasePersistenceTests.swift`, `LocalDatabaseTestSupport.swift`, and `AppDependenciesTests.swift`:

```swift
fetchRecord(id: id)
// becomes
fetch(ExampleRecord.self, id: id)

fetchRecords(matching: query)
// becomes
fetch(ExampleRecord.self, matching: query)

deleteRecord(id: id)
// becomes
delete(ExampleRecord.self, id: id)

deleteAllRecords()
// becomes
deleteAll(ExampleRecord.self)
```

Replace every empty facade batch with `try await service.upsert([ExampleRecord]())` (or `[TestLocalRecord]()` for the unregistered-model case). No final call may spell `upsert([])` because it infers `Any` rather than a `LocalDatabaseModel`.

Construct the facade only as:

```swift
LocalDatabaseService(configuration: recorder.configuration())
```

In existing disk tests use `LocalDatabaseService(configuration: .disk(url: url))`; preserve their release/reopen assertions. Task 6 strengthens them with direct-V1 and retained-baseline fixtures.

Add/lock these `LocalDatabaseServiceTests`:

- `invalidExampleInputAndEmptyRegisteredBatchDoNotInitializeStore`
- `unregisteredModelFailsBeforeStoreInitialization`
- `emptyUnregisteredBatchFailsBeforeNoOpAndInitialization`
- `invalidRegistryFailsBeforeContainerFactory`
- `preCancellationPrecedesValidationRegistrationAndInitialization`
- `validConcurrentGenericCallsInitializeExactlyOnce`
- `bootstrapCancellationRetries`
- `nonCancellationBootstrapFailureIsCached`
- `validationRegistrationNoOpAndCancellationPrecedeCachedFailure`
- `successfulFactoryCancellationIsObservedBeforeEngineWork`
- the existing inclusive/out-of-range, maximum batch, exact duplicate, case-distinct, and six pre-cancelled-operation cases through the generic API.

For unregistered calls use `TestLocalRecord` with a `.production` registry and a recorder factory; expect:

```swift
.validation(
    model: TestLocalRecordAdapter.diagnosticName,
    reason: .unregisteredModel
)
```

For invalid registry use `LocalDatabaseModelRegistry(adapters: [ExampleRecordAdapter.self, ExampleRecordAdapter.self])`, a recorder factory, and assert `.initialization`, `callCount == 0`. For empty registered Example batch, assert success and `callCount == 0`, including after a cached non-cancellation factory failure. For empty unregistered Test batch, assert validation and `callCount == 0`.

Add to `LocalDatabaseContractTests.swift`:

```swift
@Test
func genericServiceContractIsCallableThroughExistential() async throws {
    let service: any ILocalDatabaseService = GenericNoOpDatabase()
    #expect(
        try await service.fetch(ExampleRecord.self, id: "id") == nil
    )
    #expect(
        try await service.fetch(
            TestLocalRecord.self,
            matching: TestLocalQuery()
        ).isEmpty
    )
}
```

Define plain `actor GenericNoOpDatabase: ILocalDatabaseService`—`nonisolated actor` is invalid Swift—with these exact witnesses; convert `InjectedLocalDatabaseService` in `AppDependenciesTests.swift` to the same signature shape while preserving its identity assertions:

```swift
actor GenericNoOpDatabase: ILocalDatabaseService {
    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Model? { nil }

    func fetch<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        matching query: Model.Query
    ) async throws -> [Model] { [] }

    func upsert<Model: LocalDatabaseModel>(
        _ value: Model
    ) async throws {}

    func upsert<Model: LocalDatabaseModel>(
        _ values: [Model]
    ) async throws {}

    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool { false }

    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int { 0 }
}
```

Add composition assertions:

- `liveGraphDefersResolverUntilFirstValidRegisteredOperation`;
- existing preview/UI graphs remain fresh and nonsharing through generic Example calls;
- `previewAndUITestingGraphsRejectTestOnlyModel` without initializing their production-only store;
- explicit `.test(...)` dependency identity remains unchanged.

- [ ] **Step 3: Run focused RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task5-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -n 'does not conform to protocol|extraneous argument label|no member.*fetch|no member.*delete|configuration' \
  "$red_root/xcodebuild.log"
```

Expected: the old protocol/facade cannot satisfy generic calls or generic fakes.

- [ ] **Step 4: Replace the public service contract**

Replace `ILocalDatabaseService.swift` exactly with:

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

    @discardableResult
    func delete<Model: LocalDatabaseModel>(
        _ type: Model.Type,
        id: Model.ID
    ) async throws -> Bool

    @discardableResult
    func deleteAll<Model: LocalDatabaseModel>(
        _ type: Model.Type
    ) async throws -> Int
}
```

Do not add deprecated wrappers or an `Any`/`Codable` envelope.

- [ ] **Step 5: Implement the registry-aware generic facade**

Refactor `LocalDatabaseService` state to retain only the factory/ready store/cached bootstrap error and add immutable `modelRegistry`. The only initializer is:

```swift
init(
    configuration: LocalDatabaseStoreConfiguration,
    hooks: LocalDatabaseStoreHooks = .production
) {
    state = .uninitialized(configuration.containerFactory)
    modelRegistry = configuration.modelRegistry
    self.hooks = hooks
}
```

Each public method follows this exact order:

```swift
try Task.checkCancellation()
try mapValidation(Model.self) {
    // adapter ID/value/query or shared batch validation
}
try validateRegistration(Model.self)
// only batch: guard !values.isEmpty else { return }
let store = try resolveStore()
try Task.checkCancellation()
return try await store.<generic operation>
```

Validation by operation:

- fetch-one/delete-one: `Model.Persistence.validate(id:)`;
- fetch-many: `Model.Persistence.validate(query:)`;
- upsert-one: `Model.Persistence.validate(value:)`;
- upsert-batch: `LocalDatabaseValidator.validate(values:)`;
- delete-all: no value/query validation, but it still checks cancellation and registry.

Implement helpers:

```swift
private func mapValidation<Model: LocalDatabaseModel>(
    _ type: Model.Type,
    _ operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let reason as LocalDatabaseValidationError {
        throw LocalDatabaseError.validation(
            model: Model.Persistence.diagnosticName,
            reason: reason
        )
    }
}

private func validateRegistration<Model: LocalDatabaseModel>(
    _ type: Model.Type
) throws {
    do {
        try modelRegistry.validateIntegrity()
    } catch {
        LocalDatabaseDiagnostics.report(
            operation: .initialization,
            entityType: "LocalDatabase",
            recordCount: 0,
            error: error
        )
        throw LocalDatabaseError.initialization(underlying: error)
    }
    guard modelRegistry.contains(Model.Persistence.self) else {
        throw LocalDatabaseError.validation(
            model: Model.Persistence.diagnosticName,
            reason: .unregisteredModel
        )
    }
}
```

Keep bootstrap cancellation retry and non-cancellation failure caching. Registry integrity is evaluated before consulting the cached bootstrap state on every valid call. Initialization diagnostics use `entityType: "LocalDatabase"`.

- [ ] **Step 6: Switch composition and remove temporary compatibility code**

Update `AppDependencies`:

```swift
// live
LocalDatabaseService(
    configuration: .live(
        locationResolver: localDatabaseStoreLocationResolver
    )
)

// each UI-testing/preview default graph
LocalDatabaseService(configuration: .inMemory())
```

Keep `.test(...)` explicitly injected. Do not change `AppTemplateApp` or pass the raw database into a Feature/ViewModel.

Remove from `SwiftDataLocalStore` the temporary `fetchRecord`, `fetchRecords`, `deleteRecord`, and `deleteAllRecords` wrappers. Remove the legacy Example-specific overloads from `LocalDatabaseValidator`; retain only `maximumBatchSize` and `validate<Model>(values:)`.

- [ ] **Step 7: Run focused GREEN and old-API scan**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task5-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

if rg -n \
  '\b(fetchRecord|fetchRecords|deleteRecord|deleteAllRecords)\s*\(' \
  AppTemplate AppTemplateTests --glob '*.swift'; then
  exit 1
fi
if rg -n 'upsert\(\[\]\)' \
  AppTemplate AppTemplateTests --glob '*.swift'; then
  exit 1
fi

# Prove that every selected suite ran at least one passing test.
xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "LocalDatabaseServiceTests",
    "AppDependenciesTests",
    "LocalDatabaseContractTests",
    "LocalDatabaseModelRegistryTests",
    "LocalDatabasePersistenceTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select($suite == null or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0)
      | $name]
    | length == 0
  '
```

- [ ] **Step 8: Mutation-test precedence and registration**

Apply/restore one mutation at a time and run the named case:

1. Resolve the store before `validateRegistration`; `unregisteredModelFailsBeforeStoreInitialization()` must observe factory count 1 instead of 0.
2. Place empty-batch return before registration; `emptyUnregisteredBatchFailsBeforeNoOpAndInitialization()` must fail.
3. Consult cached bootstrap failure before pure validation; `validationRegistrationNoOpAndCancellationPrecedeCachedFailure()` must receive initialization instead of validation.
4. Cache factory `CancellationError`; `bootstrapCancellationRetries()` must observe one invocation and fail.
5. Temporarily bypass the `modelRegistry.contains(Model.Persistence.self)` guard; `unregisteredModelFailsBeforeStoreInitialization()` and `previewAndUITestingGraphsRejectTestOnlyModel()` must fail because storage initialization is attempted instead of returning `.unregisteredModel`.

Restore, rerun Step 7, and verify `git diff --check`.

- [ ] **Step 9: Commit Task 5**

```bash
set -euo pipefail
git add \
  AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift \
  AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
git diff --cached --check
git commit -m "refactor: expose generic local database service"
test -z "$(git status --porcelain)"
```

---

### Task 6: Prove a Distinct Model, Compile-Time Query Pairing, and V1 Reopen Compatibility

**Files:**

- Modify: `AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreGenericModelTests.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/Fixtures/LocalDatabaseQueryMismatchCompileFixture.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift`
- Temporarily create, run, and delete: `AppTemplateTests/App/Services/LocalDatabase/PostRefactorBaselineReaderTests.swift`

**Interfaces:**

- Proves the generic engine against a different `Int`-backed ID, different typed Query, different `@Model`, and a mixed test-only container.
- Proves `ExampleRecord` cannot be fetched with `TestLocalQuery` at compile time.
- Proves the unchanged V1 store can be reopened both from the retained pre-refactor artifact and from a permanent direct frozen-V1 writer fixture.

- [ ] **Step 1: Add mixed-model RED runtime tests**

Create `SwiftDataLocalStoreGenericModelTests.swift` with a shared helper that creates a `SwiftDataLocalStore` from `makeGenericInMemoryLocalDatabaseContainer()` and optional hooks. Add these tests:

- `oneGenericStoreRoundTripsExampleAndDistinctIDTestValues`: insert one Example and one Test record, fetch each by its own typed ID, and assert detached equality.
- `genericServiceExistentialRoundTripsBothRegisteredModels`: create `let database: any ILocalDatabaseService = LocalDatabaseService(configuration: makeGenericTestConfiguration())`, upsert/fetch both model types through that one existential, and assert exact values.
- `testModelFetchAndDeleteHandleMissingAndPresentDistinctIDs`: through the same registered service existential, assert a missing numeric ID fetches nil, a missing delete returns false, a present delete returns true, and the deleted Test value becomes nil while an Example value survives.
- `testAdapterRejectsOutOfRangeQueryLimits`: require `.invalidLimit(actual: 0, allowed: 1...200)` and `.invalidLimit(actual: 201, allowed: 1...200)`, and accept both inclusive bounds 1 and 200.
- `testModelBatchMixesInsertAndUpdate`: seed numeric IDs 1 and 2, batch-update 1 and insert 3, assert one save and exact three rows.
- `testModelValuesRemainDetachedAfterOperation`: retain returned value after the store is released; no `@Model` object crosses the API.
- `deleteAllIsScopedToRequestedModel`: seed both entity types, call `deleteAll(TestLocalRecord.self)`, assert Example survives and only Test rows are gone.
- `testModelWriteFailureUsesItsOwnDiagnosticName`: inject `.beforeSave(.upsertOne)`, assert `.write(model: "StoredTestLocalRecord", operation: .upsertOne, ...)` and no persisted row.
- `testQueryFiltersMinimumScoreSortsByScoreThenIDAndHonorsLimit`: use equal-score ties and require total order by numeric ID.
- `testQueryReturnsEmptyWhenNothingQualifies`.
- `testQueryDoesNotReportProgressBefore128Examined`.
- `testQueryReportsProgressAtExactly128Examined`.
- `testQueryStopsBeforeUnneededProgressCheckpoint`.
- `testQueryCancellationAt128PrecedesLimitReturn`: seed scores `0...127`, query `minimumScore: 127, limit: 1`, cancel at `.readProgress(.fetchMany)`, and require unchanged `CancellationError` rather than one result.
- `testQueryCancellationLeavesGenericStoreUsable`: after the cancelled child task, fetch an existing Test record successfully.

Every cancellation test runs the operation in the exact `resultOfChildTask` helper added in Task 5; never cancel the Swift Testing runner task.

Extend `LocalDatabaseModelRegistryTests` with:

```swift
@Test
func testRegistryAcceptsExampleAndTestRegistrationsAsBijection() throws {
    let registry = makeGenericTestRegistry()
    try registry.validateIntegrity()
    #expect(registry.registrationCount == 2)
    #expect(registry.contains(ExampleRecordAdapter.self))
    #expect(registry.contains(TestLocalRecordAdapter.self))
    #expect(registry.registeredEntityIdentifiers.count == 2)
}
```

Extend `LocalDatabaseStoreConfigurationTests` with `testContainerSchemaEnforcesUniqueNumericBusinessID`: save two `StoredTestLocalRecord` instances with the same `businessID` from separate contexts and assert one durable row containing the second values, matching SwiftData unique-upsert semantics.

- [ ] **Step 2: Run the distinct-model RED**

With the Task 5 adapter still throwing `.storageNotImplemented` from storage-facing methods, run:

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task6-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

set +e
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreGenericModelTests \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$red_root/xcodebuild.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -F 'storageNotImplemented' "$red_root/xcodebuild.log"
rg -F 'SwiftDataLocalStoreGenericModelTests' "$red_root/xcodebuild.log"
```

Expected: the new runtime tests compile, then fail because the test adapter deliberately has no storage implementation yet. This is a behavioral RED, not a destination/setup error.

- [ ] **Step 3: Complete the Test adapter and mixed-store helpers**

Replace the three `.storageNotImplemented` methods with these exact storage implementations:

```swift
static func fetch(
    id: TestLocalRecordID,
    in context: ModelContext
) throws -> StoredTestLocalRecord? {
    let rawID = id.rawValue
    var descriptor = FetchDescriptor<StoredTestLocalRecord>(
        predicate: #Predicate { $0.businessID == rawID }
    )
    descriptor.fetchLimit = 2
    return try uniqueEntity(from: context.fetch(descriptor))
}

static func fetchExisting(
    ids: [TestLocalRecordID],
    in context: ModelContext
) throws -> [StoredTestLocalRecord] {
    let rawIDs = ids.map(\.rawValue)
    let descriptor = FetchDescriptor<StoredTestLocalRecord>(
        predicate: #Predicate { rawIDs.contains($0.businessID) }
    )
    return try context.fetch(descriptor)
}

static func fetch(
    matching query: TestLocalQuery,
    in context: ModelContext,
    progress: (_ examinedCount: Int) throws -> Void
) throws -> [StoredTestLocalRecord] {
    var descriptor = FetchDescriptor<StoredTestLocalRecord>(
        sortBy: [
            SortDescriptor(\.score),
            SortDescriptor(\.businessID)
        ]
    )
    descriptor.includePendingChanges = false
    let entities = try context.fetch(descriptor, batchSize: 128)
    var result: [StoredTestLocalRecord] = []
    var examined = 0
    for entity in entities {
        examined += 1
        if query.minimumScore.map({ entity.score >= $0 }) ?? true {
            result.append(entity)
        }
        if examined.isMultiple(of: 128) {
            try progress(examined)
        }
        if result.count == query.limit { return result }
    }
    return result
}
```

This is required for SwiftData batched fetches and is safe because every operation uses a fresh context with no pending changes.

After all three replacements, remove the now-unused `GenericLocalDatabaseFixtureError`; the final test support contains no deliberate not-implemented path.

Do not add Test types to `LocalDatabaseSchemaV1`, `.production`, `AppDependencies`, previews, or UI-testing graphs.

- [ ] **Step 4: Add and prove the compile-negative query fixture**

Create `Fixtures/LocalDatabaseQueryMismatchCompileFixture.swift`:

```swift
#if LOCAL_DATABASE_QUERY_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

func compileQueryMismatch(
    database: any ILocalDatabaseService,
    query: TestLocalQuery
) async throws {
    _ = try await database.fetch(
        ExampleRecord.self,
        matching: query
    )
}
#endif
```

Run:

```bash
set -euo pipefail
compile_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-CompileMismatch.XXXXXX)"
test -d "$compile_root"
test ! -L "$compile_root"

set +e
xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_DATABASE_QUERY_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
status=$?
set -e

test "$status" -ne 0
rg -F 'TestLocalQuery' "$compile_root/build.log"
rg -F 'ExampleQuery' "$compile_root/build.log"
rg -n 'cannot convert|same-type requirement|requires the types' \
  "$compile_root/build.log"
```

Expected: the real test target fails only at the intentional Query mismatch. Then run a normal build without the condition and require success; the guarded fixture contributes no invalid declaration normally.

- [ ] **Step 5: Add permanent disk compatibility tests**

In `LocalDatabasePersistenceTests.swift`, retain/update the existing generic reopen tests and lock these final cases:

- `genericServiceReopeningDiskStoreRetainsMutations`;
- `genericServiceReopeningDiskStoreRetainsDeleteAll`;
- `genericServiceOpensStoreSeededDirectlyThroughFrozenV1Entity`.

The direct-V1 case must:

1. Create a unique disk URL.
2. Open it through `LocalDatabaseContainerFactories.disk(url:)`.
3. Insert exact `LocalDatabaseSchemaV1.StoredExampleRecord` rows with an autosave-disabled `ModelContext` and explicitly save.
4. Release the context/container before opening `LocalDatabaseService(configuration: .disk(url:))`.
5. Fetch by typed ID and typed Query and assert exact String IDs/payloads, including whitespace ID, empty payload, Unicode payload, and case-distinct IDs.

This is permanent portable coverage; it never duplicates or edits the schema declaration.

- [ ] **Step 6: Reopen the retained pre-refactor artifact through an injected macOS test run, then remove the temporary reader**

Create `PostRefactorBaselineReaderTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct PostRefactorBaselineReaderTests {
    @Test
    func reopensPreRefactorV1CompatibilityArtifact() async throws {
        let root = URL(
            fileURLWithPath: try #require(
                ProcessInfo.processInfo.environment[
                    "APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT"
                ]
            ),
            isDirectory: true
        ).standardizedFileURL
        let expected = try JSONDecoder().decode(
            [ExampleRecord].self,
            from: Data(
                contentsOf: root.appending(path: "expected.json")
            )
        )
        let service: any ILocalDatabaseService = LocalDatabaseService(
            configuration: .disk(
                url: root.appending(path: "LocalDatabase.store")
            )
        )

        let actual = try await service.fetch(
            ExampleRecord.self,
            matching: ExampleQuery(limit: 200)
        )
        #expect(actual == expected)
        for record in expected {
            #expect(
                try await service.fetch(
                    ExampleRecord.self,
                    id: record.id
                ) == record
            )
        }
    }
}
```

Run it exactly once against the recorded writer root:

```bash
set -euo pipefail
baseline_manifest='.superpowers/sdd/2026-08-12-generic-local-database/baseline-root.txt'
test -f "$baseline_manifest"
baseline_root="$(sed -n 's/^Baseline root: //p' "$baseline_manifest")"
case "$baseline_root" in
  /tmp/AppTemplate-GenericLocalDatabase-baseline-c4d4af9.*) ;;
  *) exit 1 ;;
esac
test -f "$baseline_root/LocalDatabase.store"
test -f "$baseline_root/expected.json"

reader_root="$(
  mktemp -d /tmp/AppTemplate-GenericLocalDB-BaselineReader.XXXXXX
)"
test -d "$reader_root"
test ! -L "$reader_root"

reader_derived_data="$reader_root/DerivedData-reader"
reader_products="$reader_derived_data/Build/Products"
reader_xcresult="$reader_root/Reader.xcresult"
test ! -e "$reader_derived_data"
test ! -e "$reader_xcresult"

xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$reader_derived_data" \
  ENABLE_APP_SANDBOX=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

test -d "$reader_products"
xctestrun_matches="$(
  find "$reader_products" -maxdepth 1 -type f \
    -name 'AppTemplate_macosx*-arm64.xctestrun' -print
)"
xctestrun_match_count="$(
  printf '%s\n' "$xctestrun_matches" | sed '/^$/d' | wc -l | tr -d ' '
)"
test "$xctestrun_match_count" -eq 1
generated_xctestrun="$(
  printf '%s\n' "$xctestrun_matches" | sed '/^$/d'
)"
test -f "$generated_xctestrun"
test ! -L "$generated_xctestrun"

reader_xctestrun="$reader_products/AppTemplate_BaselineReaderInjected.xctestrun"
test ! -e "$reader_xctestrun"
cp "$generated_xctestrun" "$reader_xctestrun"
plutil -insert \
  'AppTemplateTests.EnvironmentVariables.APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT' \
  -string "$baseline_root" \
  "$reader_xctestrun"
test "$(
  plutil -extract \
    'AppTemplateTests.EnvironmentVariables.APP_TEMPLATE_PRE_REFACTOR_BASELINE_ROOT' \
    raw -o - "$reader_xctestrun"
)" = "$baseline_root"

xcodebuild test-without-building \
  -xctestrun "$reader_xctestrun" \
  -destination 'platform=macOS,arch=arm64' \
  -resultBundlePath "$reader_xcresult" \
  '-only-testing:AppTemplateTests/PostRefactorBaselineReaderTests/reopensPreRefactorV1CompatibilityArtifact()'

xcrun xcresulttool get test-results summary \
  --path "$reader_xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount == 1
    and .passedTests == 1
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

printf 'Retained baseline reader artifacts: %s\n' "$reader_root"
```

Expected: `build-for-testing` creates exactly one matching arm64 macOS `.xctestrun`; the copied adjacent reader configuration contains the exact retained-root value under `AppTemplateTests.EnvironmentVariables`; the exact reader method selector runs once and passes. The command-line sandbox override is restricted to this external-artifact compatibility probe; it does not change project settings or the normally sandboxed final gates.

Then delete only `PostRefactorBaselineReaderTests.swift` with `apply_patch` and run:

```bash
set -euo pipefail
test ! -e \
  AppTemplateTests/App/Services/LocalDatabase/PostRefactorBaselineReaderTests.swift
baseline_root="$(sed -n 's/^Baseline root: //p' \
  .superpowers/sdd/2026-08-12-generic-local-database/baseline-root.txt)"
test -f "$baseline_root/LocalDatabase.store"
test -f "$baseline_root/expected.json"
git diff --check
```

- [ ] **Step 7: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-Task6-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreGenericModelTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e '
    .result == "Passed"
    and .totalTestCount > 0
    and .passedTests == .totalTestCount
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
  '

xcrun xcresulttool get test-results tests \
  --path "$green_root/Tests.xcresult" --compact \
| jq -e --argjson expected '[
    "SwiftDataLocalStoreGenericModelTests",
    "LocalDatabasePersistenceTests",
    "LocalDatabaseModelRegistryTests",
    "LocalDatabaseStoreConfigurationTests",
    "SwiftDataLocalStoreBatchTests"
  ]' '
    def descendants: recurse(.children[]?);
    [.testNodes[] | descendants
      | select(.nodeType == "Test Suite")] as $suites
    | [$expected[] as $name
      | ($suites | map(select(.name == $name)) | first) as $suite
      | select($suite == null or $suite.result != "Passed"
          or ([$suite | descendants
            | select(.nodeType == "Test Case")] | length) == 0)
      | $name]
    | length == 0
  '
```

- [ ] **Step 8: Mutation-test generic isolation and persistence**

Apply/restore separately:

1. Make `deleteAll(Model.self)` delete `StoredExampleRecord.self`; `deleteAllIsScopedToRequestedModel()` must fail.
2. Remove the numeric business-ID tie-breaker; the equal-score order test must fail.
3. Add `StoredTestLocalRecord.self` to V1 or `.production`; the schema SHA/cardinality guard must fail.
4. Change the direct-V1 reader to a different URL; the exact reopen assertions must fail.
5. Temporarily add an unconstrained protocol-extension overload `fetch<Model: LocalDatabaseModel, OtherQuery: Sendable>(_:matching:)` that returns an empty array. The compile-negative fixture must unexpectedly succeed, proving the gate detects loss of Query pairing; remove the overload and rerun the expected-failure gate.

After restoration, rerun Steps 4 and 7.

- [ ] **Step 9: Commit Task 6**

```bash
set -euo pipefail
test ! -e \
  AppTemplateTests/App/Services/LocalDatabase/PostRefactorBaselineReaderTests.swift
git add \
  AppTemplateTests/TestSupport/LocalDatabase/GenericLocalDatabaseTestSupport.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreGenericModelTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/Fixtures/LocalDatabaseQueryMismatchCompileFixture.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseModelRegistryTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift
git diff --cached --check
git commit -m "test: prove generic local database models"
test -z "$(git status --porcelain)"
```

---

### Task 7: Update Active Documentation and Enforce Architectural Scope

**Files:**

- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`

**Interfaces:**

- Documents a typed, explicitly registered engine—not a schemaless arbitrary-Codable store.
- Preserves UserDefaults-backed application state as a separate concern.
- Makes the production schema/registry/migration checklist explicit for future models.

- [ ] **Step 1: Write documentation RED assertions**

Before editing docs, run and require at least one failure:

```bash
set -euo pipefail
if rg -F 'Generic does not mean schemaless or arbitrary Codable storage.' \
  README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md; then
  exit 1
fi
```

Also record the current release-checklist LocalDatabase section so the edit preserves disk reopen, failure recovery, privacy, backup, platform, UI, and Release gates.

- [ ] **Step 2: Update README**

Replace the Example-specific wording with these points:

- the template includes a typed, explicitly registered SwiftData reference engine;
- `ExampleRecord` is the first detached local-persistence model, not a hard-coded service API;
- include the exact sentence `Generic does not mean schemaless or arbitrary Codable storage.`, then explain that it is one compile-time engine for models explicitly added to a schema/registry, not runtime discovery;
- Feature/ViewModel code should depend on a semantic repository rather than `ILocalDatabaseService`;
- `AppStateStore` remains a separate UserDefaults-backed synchronous launch-state mechanism.

Do not claim CloudKit sync, cross-process access, encryption, backup policy, or product-domain persistence.

- [ ] **Step 3: Update architecture/customization/release docs**

In `docs/ARCHITECTURE.md`, describe the exact flow:

```text
detached LocalDatabaseModel
  -> associated typed Query and LocalEntityAdapter
  -> adapter-owned SwiftData entity/predicate/mapping
  -> operation-scoped ModelContext inside SwiftDataLocalStore
```

Explain that `VersionedSchema` owns physical persistence and migrations, while `LocalDatabaseModelRegistry` authorizes adapter/value/entity/name identity for one service. Retain lazy bootstrap/cached failure, explicit save/no-op, delete-all characterization, cancellation, redacted diagnostics, fresh preview/UI stores, and future semantic-repository boundaries.

In `docs/CUSTOMIZATION.md`, add this required new-model checklist in order:

1. detached immutable `Sendable` record and typed Query;
2. schema entity with a schema-enforced unique business ID;
3. adapter and record conformance;
4. new immutable `VersionedSchema` version—never edit a shipped schema;
5. migration stage and disk transition fixture;
6. production registry entry;
7. schema/registry bijection and uniqueness tests;
8. semantic Feature repository mapping Domain values to local records.

Preserve stable Application Support URL, retention/deletion/backup/recovery/security decisions, CloudKit `.none` default, and the statement that AppState remains UserDefaults-owned.

In `docs/RELEASE_CHECKLIST.md`, require:

- production registry entity set and cardinality equal the active schema;
- unique business-ID behavior for every registered entity;
- all prior-schema disk transition fixtures plus direct-V1 and generic reopen tests;
- delete-all SDK characterization and failed-write recovery;
- local database privacy/retention/backup/sync/cross-process decisions;
- three-platform unit gates, full macOS scheme, iPhone/iPad UI suites, and generic macOS/iOS Release builds.

Do not edit the historical 2026-08-10 SwiftData design document.

- [ ] **Step 4: Run documentation and full scope guards**

```bash
set -euo pipefail
baseline_commit='c4d4af99538af06f6f0b958495143a09c6229037'
test "$(git merge-base "$baseline_commit" HEAD)" = "$baseline_commit"

rg -q 'explicitly registered' README.md
rg -qF 'Generic does not mean schemaless or arbitrary Codable storage.' \
  README.md
rg -q 'LocalDatabaseModel' docs/ARCHITECTURE.md
rg -q 'LocalEntityAdapter' docs/ARCHITECTURE.md
rg -q 'VersionedSchema' docs/ARCHITECTURE.md
rg -q 'LocalDatabaseModelRegistry' docs/ARCHITECTURE.md
rg -q 'VersionedSchema' docs/CUSTOMIZATION.md
rg -qi 'production registry' docs/CUSTOMIZATION.md
rg -qi 'semantic.*repository' docs/CUSTOMIZATION.md
rg -qi 'registry.*schema|schema.*registry' docs/RELEASE_CHECKLIST.md
rg -q 'iPhone 17' docs/RELEASE_CHECKLIST.md
rg -qF 'iPad (A16)' docs/RELEASE_CHECKLIST.md
rg -q 'generic macOS' docs/RELEASE_CHECKLIST.md
rg -q 'generic iOS' docs/RELEASE_CHECKLIST.md
rg -q 'UserDefaults' README.md
rg -q 'UserDefaults' docs/ARCHITECTURE.md
rg -q 'UserDefaults' docs/CUSTOMIZATION.md

changed_paths="$({
  git diff --name-only "$baseline_commit"...HEAD
  git diff HEAD --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | LC_ALL=C sort -u)"

unexpected_paths="$(
  while IFS= read -r path; do
    test -z "$path" && continue
    case "$path" in
      README.md | \
      docs/ARCHITECTURE.md | \
      docs/CUSTOMIZATION.md | \
      docs/RELEASE_CHECKLIST.md | \
      docs/superpowers/specs/2026-08-12-generic-local-database-design.md | \
      docs/superpowers/plans/2026-08-12-generic-local-database.md | \
      AppTemplate/App/AppDependencies/AppDependencies.swift | \
      AppTemplate/App/Models/Local/ExampleRecord.swift | \
      AppTemplate/App/Services/LocalDatabase/* | \
      AppTemplateTests/App/Composition/AppDependenciesTests.swift | \
      AppTemplateTests/App/Models/Local/ExampleLocalModelTests.swift | \
      AppTemplateTests/App/Services/LocalDatabase/* | \
      AppTemplateTests/TestSupport/LocalDatabase/*)
        ;;
      *) printf '%s\n' "$path" ;;
    esac
  done <<< "$changed_paths"
)"
if test -n "$unexpected_paths"; then
  printf 'Unexpected implementation paths:\n%s\n' \
    "$unexpected_paths" >&2
  exit 1
fi

test "$(
  shasum -a 256 \
    AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift \
  | awk '{print $1}'
)" = '1b83fc638ba3ba8d3f628459d1f1081daee45a30dc7f4d664417a107b8aef706'
git diff --quiet "$baseline_commit" -- \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift
git diff --quiet "$baseline_commit" -- \
  AppTemplate/App/Models/Local/ExampleQuery.swift

git diff --quiet "$baseline_commit" -- \
  AppTemplate/Features \
  AppTemplate/App/ApplicationState \
  AppTemplate/App/Navigation \
  AppTemplate/App/Networking \
  AppTemplate/App/Entry \
  AppTemplateUITests \
  AppTemplate.xcodeproj \
  Config \
  .github \
  Package.swift \
  Package.resolved \
  ':(glob)**/*.entitlements'

low_level_pattern='^import SwiftData$|\bModelContext\b|\bModelContainer\b|\bPersistentModel\b|\bPersistentIdentifier\b|\bFetchDescriptor\b|\bPredicate\b'
outside_persistence="$(
  rg -l "$low_level_pattern" AppTemplate --glob '*.swift' \
  | rg -v '^AppTemplate/App/Services/LocalDatabase/' || true
)"
test -z "$outside_persistence"

outside_test_persistence="$(
  rg -l "$low_level_pattern" AppTemplateTests --glob '*.swift' \
  | rg -v '^AppTemplateTests/(App/Services/LocalDatabase|TestSupport/LocalDatabase)/' || true
)"
test -z "$outside_test_persistence"

model_boundary_violations="$(
  rg -l '\b(LocalDatabaseModel|LocalEntityAdapter)\b' \
    AppTemplate --glob '*.swift' \
  | rg -v '^AppTemplate/App/Services/LocalDatabase/' || true
)"
test -z "$model_boundary_violations"

test "$(
  rg -l '@Model\b' AppTemplate --glob '*.swift' | LC_ALL=C sort
)" = 'AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift'

if rg -n \
  '\b(fetchRecord|fetchRecords|deleteRecord|deleteAllRecords)\s*\(' \
  AppTemplate AppTemplateTests --glob '*.swift'; then
  exit 1
fi
if rg -n \
  '\b(ILocalDatabaseService|LocalDatabaseService|LocalDatabaseModel|LocalEntityAdapter|ExampleRecord)\b|^import SwiftData$' \
  AppTemplate/Features --glob '*.swift'; then
  exit 1
fi
if rg -n 'Dictionary\(uniqueKeysWithValues:|fatalError|precondition(Failure)?|try!' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi
if rg -n 'TestLocalRecord|StoredTestLocalRecord|TestLocalQuery' \
  AppTemplate --glob '*.swift'; then
  exit 1
fi
if rg -n 'ExampleRecord|ExampleQuery|StoredExampleRecord' \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift; then
  exit 1
fi

test ! -e \
  AppTemplateTests/App/Services/LocalDatabase/PreRefactorBaselineExporterTests.swift
test ! -e \
  AppTemplateTests/App/Services/LocalDatabase/PostRefactorBaselineReaderTests.swift

git diff --check
```

- [ ] **Step 5: Commit Task 7**

```bash
set -euo pipefail
git add \
  README.md \
  docs/ARCHITECTURE.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md
git diff --cached --check
git commit -m "docs: explain generic local persistence"
test -z "$(git status --porcelain)"
```

---

### Task 8: Run the Compiler Proof, Nine Final Gates, and Independent Review

**Files:**

- Verify only; do not edit unless a gate or review exposes a defect.
- Evidence: `.superpowers/sdd/2026-08-12-generic-local-database/final-verification-report.md`

- [ ] **Step 1: Verify toolchain, clean status, schema, and compiler-negative proof**

```bash
set -euo pipefail
xcodebuild -version
xcrun swift --version
sw_vers
jq --version
test -z "$(git status --porcelain)"
destinations="$(
  xcodebuild -project AppTemplate.xcodeproj \
    -scheme AppTemplate -showdestinations
)"
rg 'OS:26\.5, name:iPhone 17' <<<"$destinations"
rg 'OS:26\.5, name:iPad \(A16\)' <<<"$destinations"
test "$(
  shasum -a 256 \
    AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift \
  | awk '{print $1}'
)" = '1b83fc638ba3ba8d3f628459d1f1081daee45a30dc7f4d664417a107b8aef706'

compile_root="$(mktemp -d /tmp/AppTemplate-GenericLocalDB-FinalCompile.XXXXXX)"
test -d "$compile_root"
test ! -L "$compile_root"
set +e
xcodebuild build-for-testing \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$compile_root/DerivedData" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCAL_DATABASE_QUERY_MISMATCH_COMPILE_FIXTURE' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  >"$compile_root/build.log" 2>&1
status=$?
set -e
test "$status" -ne 0
rg -F 'TestLocalQuery' "$compile_root/build.log"
rg -F 'ExampleQuery' "$compile_root/build.log"
rg -n 'cannot convert|same-type requirement|requires the types' \
  "$compile_root/build.log"
```

- [ ] **Step 2: Verify macOS UI automation authorization**

Before the complete macOS scheme gate, verify the current terminal/runner is authorized for UI automation using the repository’s previously proven local workflow. Do not disable security controls, skip UI tests, or classify a runner initialization failure as a pass. If authorization is absent, report the exact blocked gate and preserve all results; once authorization is supplied, rerun the full unfiltered macOS scheme from a fresh result root.

- [ ] **Step 3: Run all nine gates under one validated root**

```bash
set -euo pipefail

verification_root="$(
  mktemp -d /tmp/AppTemplate-GenericLocalDatabase-final.XXXXXX
)"
test -n "$verification_root"
test -d "$verification_root"
test ! -L "$verification_root"
case "$verification_root" in
  /tmp/AppTemplate-GenericLocalDatabase-final.*) ;;
  *) exit 1 ;;
esac
printf 'Retained verification root: %s\n' "$verification_root"
trap 'printf "Verification artifacts retained at: %s\n" "$verification_root"' EXIT

assert_clean_build_result() {
  local bundle="${1:?}"
  test -d "$bundle"
  xcrun xcresulttool get build-results \
    --path "$bundle" --compact \
  | jq -e '
      has("status")
      and (.status | ascii_downcase) == "succeeded"
      and ((.errorCount // 0) == 0)
      and ((.warningCount // 0) == 0)
      and ((.analyzerWarningCount // 0) == 0)
      and (.errors | length) == 0
      and (.warnings | length) == 0
      and (.analyzerWarnings | length) == 0
    '
}

assert_test_result() {
  local bundle="${1:?}"
  assert_clean_build_result "$bundle"
  xcrun xcresulttool get test-results summary \
    --path "$bundle" --compact \
  | jq -e '
      .result == "Passed"
      and .totalTestCount > 0
      and .failedTests == 0
      and .skippedTests == 0
      and .expectedFailures == 0
      and .passedTests == .totalTestCount
      and (
        .passedTests
        + .failedTests
        + .skippedTests
        + .expectedFailures
      ) == .totalTestCount
    '
}

assert_test_suites() {
  local bundle="${1:?}"
  shift
  local expected_json
  expected_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  xcrun xcresulttool get test-results tests \
    --path "$bundle" --compact \
  | jq -e --argjson expected "$expected_json" '
      def descendants: recurse(.children[]?);
      [.testNodes[] | descendants
        | select(.nodeType == "Test Suite")] as $suites
      | [$expected[] as $name
        | ($suites | map(select(.name == $name)) | first) as $suite
        | select($suite == null or $suite.result != "Passed"
            or ([$suite | descendants
              | select(.nodeType == "Test Case")] | length) == 0)
        | $name]
      | length == 0
    '
}

run_test_gate() {
  local gate="${1:?}"
  local destination="${2:?}"
  shift 2
  local derived="$verification_root/DerivedData-$gate"
  local result="$verification_root/$gate.xcresult"
  test ! -e "$derived"
  test ! -e "$result"
  xcodebuild test \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$derived" \
    -resultBundlePath "$result" \
    "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_test_result "$result"
}

run_build_gate() {
  local gate="${1:?}"
  local destination="${2:?}"
  shift 2
  local derived="$verification_root/DerivedData-$gate"
  local result="$verification_root/$gate.xcresult"
  test ! -e "$derived"
  test ! -e "$result"
  xcodebuild build \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration Release \
    -destination "$destination" \
    -derivedDataPath "$derived" \
    -resultBundlePath "$result" \
    "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_clean_build_result "$result"
}

# 1: all twelve persistence/composition suites, including all three new suites
run_test_gate focused-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/ExampleRecordAdapterTests \
  -only-testing:AppTemplateTests/LocalDatabaseModelRegistryTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreGenericModelTests \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/ExampleLocalModelTests

assert_test_suites "$verification_root/focused-macOS.xcresult" \
  LocalDatabaseContractTests \
  ExampleRecordAdapterTests \
  LocalDatabaseModelRegistryTests \
  LocalDatabaseStoreConfigurationTests \
  SwiftDataLocalStoreMutationTests \
  SwiftDataLocalStoreBatchTests \
  SwiftDataLocalStoreQueryTests \
  SwiftDataLocalStoreGenericModelTests \
  LocalDatabaseServiceTests \
  LocalDatabasePersistenceTests \
  AppDependenciesTests \
  ExampleLocalModelTests

# 2
run_test_gate units-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests

# 3
run_test_gate units-iPhone17 \
  'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -only-testing:AppTemplateTests

# 4
run_test_gate units-iPadA16 \
  'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -only-testing:AppTemplateTests

# 5: complete shared scheme, including macOS UI tests
run_test_gate scheme-macOS 'platform=macOS'

# 6
run_test_gate ui-iPhone17 \
  'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -only-testing:AppTemplateUITests

# 7
run_test_gate ui-iPadA16 \
  'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -only-testing:AppTemplateUITests

# 8
run_build_gate release-macOS 'generic/platform=macOS'

# 9
run_build_gate release-iOS 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO

printf 'Retained verification artifacts: %s\n' "$verification_root"
```

Expected: all nine commands exit 0; every test result has nonzero total, all passed, and no skip/expected failure; every result has zero build/analyzer warnings. Do not reuse a result bundle or DerivedData directory after a failed command.

- [ ] **Step 4: Run final scope guards and independent code review**

Rerun the complete Task 7 Step 4 guard after the nine gates. Then request an independent review of `c4d4af9...HEAD` against the approved spec and this plan. The reviewer must inspect:

- generic constraints/existential usability;
- registry integrity/authorization precedence;
- fresh-context SwiftData confinement and error recovery;
- save/no-op/delete-all semantics;
- typed query order/progress/cancellation;
- V1 hash and disk compatibility;
- diagnostics redaction;
- test-only type leakage and raw-database Feature boundaries;
- all nine retained xcresult bundles.

P0–P2 findings require a focused RED, minimal fix, focused GREEN, a separate fix commit, and rerunning all nine final gates because source changed after the matrix. P3 wording-only findings may be fixed in docs, committed separately, then rerun Task 7 guards and any directly affected verification; record why the full runtime matrix is or is not invalidated.

- [ ] **Step 5: Write the final evidence report**

Create `.superpowers/sdd/2026-08-12-generic-local-database/final-verification-report.md` with:

- implementation commit list;
- pre-refactor writer and post-refactor reader artifact paths/results;
- compile-negative command, exit, and matched diagnostic;
- Task 1–7 focused RED/GREEN and mutation evidence;
- exact nine gate commands, result bundle paths, counts, and warning totals;
- schema SHA/blob verification;
- scope/static guard result;
- independent review verdict and any fix-round commits;
- final `git status --short` and `git log --oneline c4d4af9..HEAD`.

The evidence report is ignored and must not be committed. Completion requires a clean working tree and no unfinished review findings.

---

## Definition of Done

- All six public LocalDatabase operations are generic and callable through `any ILocalDatabaseService`.
- A model’s associated Query cannot be substituted with another model’s Query at compile time.
- The runtime registry is nontrapping, bijective, production-schema-aligned, and checked before initialization.
- Example and the distinct numeric-ID test model both work through one generic engine; test entities never ship.
- The frozen V1 schema hash/blob and old disk data remain compatible.
- No specialized public method, raw SwiftData Feature dependency, schemaless envelope, or hard-coded Example engine logic remains.
- Focused tests, three-platform unit tests, complete macOS scheme, both mobile UI suites, both Release builds, source guards, and independent review are all green.
