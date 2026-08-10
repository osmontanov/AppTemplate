# SwiftData Local Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inert local-database scaffold with a production-quality, local-only SwiftData reference store for `ExampleRecord`, while preserving strict value, actor, dependency-injection, and test-isolation boundaries.

**Architecture:** Keep `ILocalDatabaseService` as a `Sendable` value-facing API. A `LocalDatabaseService` actor validates requests and owns a synchronous lazy-initialization state machine; an internal `SwiftDataLocalStore` `ModelActor` confines the executor and operation-scoped `ModelContext` instances, performs bounded reads and single-save mutations, and never returns persistent models.

**Tech Stack:** Swift 6, SwiftData, Foundation, OSLog, Swift Testing, XCTest UI tests, Xcode 26.6; no third-party persistence, repository, reactive, sync, or logging dependency.

## Global Constraints

- Treat `docs/superpowers/specs/2026-08-10-swiftdata-local-service-design.md` as normative. If implementation evidence contradicts it, stop and amend/re-review the spec before continuing.
- Keep deployment targets at iOS/iPadOS/macOS 26.0, `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and approachable concurrency enabled.
- Keep SwiftData internal to `App/Services/LocalDatabase`; do not expose `ModelContext`, `ModelContainer`, `PersistentModel`, `PersistentIdentifier`, `FetchDescriptor`, or `@Query` through the service protocol, app models, `AppDependencies`, features, or views.
- Keep `ExampleRecord` an immutable `Codable`, `Equatable`, `Sendable` value. Keep `ExampleQuery` an immutable `Equatable`, `Sendable` value.
- Keep `AppStateStore` and its `UserDefaults` schema unchanged. Do not connect the new service to a feature, ViewModel, screen, route, or navigation state.
- Live composition uses one lazy disk service. Preview and UI-test factory calls each use a fresh in-memory container. `AppDependencies.test(...)` continues to require explicit caller injection.
- Every engine call that reaches storage creates a private operation-scoped `ModelContext` with autosave disabled; the empty-batch fast path creates none. Every state-changing public operation performs one explicit `save()`; unchanged upsert, empty batch, missing delete, and empty delete-all perform none. A failed mutation calls `rollback()` and discards that context, without claiming compensating disk rollback or crash-level atomicity.
- Cancellation stays cooperative: preserve `CancellationError`, never add a post-save cancellation check, and use synchronous child-task checkpoints for deterministic cancellation tests.
- Schema V1 is the first schema. Do not invent V0, add migration stages, enable CloudKit, add App Group sharing, erase an unknown store, or fall back to in-memory storage after bootstrap failure.
- Diagnostic metadata contains only operation, entity type, record count, error domain, and error code. Never send an ID, payload, search text, error description/userInfo, store contents, or user-specific path to the logging boundary.
- Do not modify `AppTemplate.xcodeproj/project.pbxproj`: filesystem-synchronized app and test groups automatically include new Swift files. Do not add packages, entitlements, hosted automation, or a privacy manifest.
- Every task follows RED -> verify expected RED -> GREEN -> focused warnings-as-errors gate -> self-review -> one commit. Never let Swift Testing cancellation mark the runner task cancelled; cancellation requests run in a child `Task` and return `Result`.
- Do not delete temporary artifacts. Every final gate creates and validates a unique `/tmp/AppTemplate-SwiftData-*` root and leaves it available for inspection.

---

## File Map

### Create

- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift` — public validation/read/write/bootstrap error categories and operation values.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift` — pure pre-store validation for IDs, limits, and batches.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift` — V1 `@Model` entity and empty-stage migration plan.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift` — synchronous container factory alias, stable live URL resolver, and live/disk/in-memory container factories.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreHooks.swift` — internal non-data-bearing read/write/save/rollback checkpoints.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift` — typed privacy-safe failure metadata and production OSLog rendering.
- `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift` — `@ModelActor` engine with operation-scoped contexts, explicit save, failed-context discard, CRUD, bounded search, and value mapping.
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift` — query defaults, validation, schema, and error-contract tests.
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift` — lazy resolver, stable URL, in-memory, disk, and failure tests.
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift` — single-record mutations, hooks, mapping, and diagnostic-redaction tests.
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift` — batch/delete-all single-save, rollback, and cancellation tests.
- `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift` — bounded ordering, normalization, batch traversal, read failure, and cancellation tests.
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift` — disk reopen, detached-value, and persisted deletion integration tests.
- `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift` — fresh containers/services, unique disk URLs, synchronous hook recorder, and factory recorder.

### Modify

- `AppTemplate/App/Models/Local/ExampleQuery.swift` — defaulted bounded query initializer.
- `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift` — semantic `ExampleRecord` CRUD/query API.
- `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift` — lazy actor facade and cached bootstrap state.
- `AppTemplate/App/AppDependencies/AppDependencies.swift` — live disk versus isolated preview/UI-test composition.
- `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift` — replace empty-interface smoke test with facade state-machine tests.
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift` — make the injected test actor conform and prove graph isolation.
- `README.md` — advertise an operational local-only reference store without claiming a product schema.
- `docs/ARCHITECTURE.md` — document facade/ModelActor/schema/value/error boundaries.
- `docs/CUSTOMIZATION.md` — document sample replacement, migrations, lifecycle, sync, and feature protocols.
- `docs/RELEASE_CHECKLIST.md` — add SwiftData lifecycle/migration/reopen and final local gate requirements.

---

### Task 1: Define the Value, Validation, Error, and Schema Contracts

**Files:**

- Modify: `AppTemplate/App/Models/Local/ExampleQuery.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift`

**Interfaces:**

- Consumes: existing `ExampleRecord(id:payload:)` and the SwiftData SDK.
- Produces: `ExampleQuery.init(searchText:limit:)`, `LocalDatabaseValidationError`, `LocalDatabaseReadOperation`, `LocalDatabaseWriteOperation`, `LocalDatabaseError`, `LocalDatabaseValidator`, `LocalDatabaseSchemaV1`, and `LocalDatabaseMigrationPlan`.

- [ ] **Step 1: Write contract and validation RED tests**

Create `LocalDatabaseContractTests.swift` with tests that exercise the desired API before it exists:

```swift
import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseContractTests {
    @Test
    func queryDefaultsToUnfilteredFiftyRecordLimit() {
        let query = ExampleQuery()

        #expect(query.searchText == nil)
        #expect(query.limit == 50)
    }

    @Test
    func validatorRejectsBlankIDs() {
        for id in ["", " ", "\n\t"] {
            expectValidationError(.emptyID) {
                try LocalDatabaseValidator.validate(id: id)
            }
        }
    }

    @Test
    func validatorAcceptsExactNonblankIdentityAndEmptyPayload() throws {
        try LocalDatabaseValidator.validate(
            record: ExampleRecord(id: " local-42 ", payload: "")
        )
    }

    @Test
    func validatorEnforcesInclusiveQueryBounds() throws {
        try LocalDatabaseValidator.validate(
            query: ExampleQuery(limit: 1)
        )
        try LocalDatabaseValidator.validate(
            query: ExampleQuery(limit: 200)
        )
        expectValidationError(
            .invalidLimit(actual: 0, allowed: 1...200)
        ) {
            try LocalDatabaseValidator.validate(
                query: ExampleQuery(limit: 0)
            )
        }
        expectValidationError(
            .invalidLimit(actual: 201, allowed: 1...200)
        ) {
            try LocalDatabaseValidator.validate(
                query: ExampleQuery(limit: 201)
            )
        }
    }

    @Test
    func validatorRejectsOversizedAndDuplicateBatches() {
        let oversized = (0...500).map {
            ExampleRecord(id: "record-\($0)", payload: "value")
        }
        expectValidationError(
            .batchTooLarge(actual: 501, maximum: 500)
        ) {
            try LocalDatabaseValidator.validate(records: oversized)
        }
        expectValidationError(.duplicateID) {
            try LocalDatabaseValidator.validate(records: [
                ExampleRecord(id: "same", payload: "one"),
                ExampleRecord(id: "same", payload: "two")
            ])
        }
    }

    @Test
    func schemaStartsAtV1WithoutInventedMigrationStage() {
        #expect(
            LocalDatabaseSchemaV1.versionIdentifier
                == Schema.Version(1, 0, 0)
        )
        #expect(LocalDatabaseSchemaV1.models.count == 1)
        #expect(LocalDatabaseMigrationPlan.schemas.count == 1)
        #expect(LocalDatabaseMigrationPlan.stages.isEmpty)
    }
}

private func expectValidationError(
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

- [ ] **Step 2: Run the focused test and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task1-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65. Compilation must fail because the default `ExampleQuery` initializer and LocalDatabase contract/schema types do not exist. Fix spelling or target-selection errors until the failure is for those missing APIs.

- [ ] **Step 3: Add the minimal contract implementation**

Replace `ExampleQuery.swift` with:

```swift
nonisolated
struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let limit: Int

    init(searchText: String? = nil, limit: Int = 50) {
        self.searchText = searchText
        self.limit = limit
    }
}
```

Create `LocalDatabaseError.swift`:

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

Create `LocalDatabaseValidator.swift`:

```swift
nonisolated
enum LocalDatabaseValidator {
    static let queryLimitRange = 1...200
    static let maximumBatchSize = 500

    static func validate(id: String) throws {
        guard id.contains(where: { !$0.isWhitespace }) else {
            throw LocalDatabaseValidationError.emptyID
        }
    }

    static func validate(record: ExampleRecord) throws {
        try validate(id: record.id)
    }

    static func validate(query: ExampleQuery) throws {
        guard queryLimitRange.contains(query.limit) else {
            throw LocalDatabaseValidationError.invalidLimit(
                actual: query.limit,
                allowed: queryLimitRange
            )
        }
    }

    static func validate(records: [ExampleRecord]) throws {
        guard records.count <= maximumBatchSize else {
            throw LocalDatabaseValidationError.batchTooLarge(
                actual: records.count,
                maximum: maximumBatchSize
            )
        }

        var identities = Set<String>()
        for record in records {
            try validate(record: record)
            guard identities.insert(record.id).inserted else {
                throw LocalDatabaseValidationError.duplicateID
            }
        }
    }
}
```

Create `LocalDatabaseSchema.swift`:

```swift
import SwiftData

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

nonisolated
enum LocalDatabaseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LocalDatabaseSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
```

Do not add `nonisolated` to a top-level `typealias`; Swift 6 rejects that modifier. No factory alias is introduced until Task 2.

- [ ] **Step 4: Run focused GREEN and the existing value-model test**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task1-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task1.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/ExampleLocalModelTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task1.xcresult" \
  | jq -e '.result == "Passed"
      and .failedTests == 0
      and .skippedTests == 0
      and .expectedFailures == 0
      and .totalTestCount > 0'
```

Expected: command and summary assertion exit zero with no warning, failure, skip, or expected failure.

- [ ] **Step 5: Self-review and commit Task 1**

```bash
git diff --check
git add \
  AppTemplate/App/Models/Local/ExampleQuery.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift
git diff --cached --check
git commit -m "feat: define SwiftData local database contract"
```

---

### Task 2: Build Explicit Live, Disk, and In-Memory Containers

**Files:**

- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift`

**Interfaces:**

- Consumes: `LocalDatabaseSchemaV1` and `LocalDatabaseMigrationPlan` from Task 1.
- Produces: plain top-level `LocalDatabaseContainerFactory`, `LocalDatabaseStoreLocationResolver`, `LocalDatabaseStoreLocationError`, and `LocalDatabaseContainerFactories.live`, `.disk`, and `.inMemory`.

- [ ] **Step 1: Write resolver and factory RED tests**

Create `LocalDatabaseStoreConfigurationTests.swift` with these behaviors:

```swift
import Foundation
import SwiftData
import Synchronization
import Testing
@testable import AppTemplate

struct LocalDatabaseStoreConfigurationTests {
    @Test
    func liveResolverBuildsStableBundleScopedURLLazily() throws {
        let recorder = DirectoryCreationRecorder()
        let root = URL(filePath: "/tmp/AppTemplate-Resolver-Fixture", directoryHint: .isDirectory)
        let resolver = LocalDatabaseStoreLocationResolver.live(
            applicationSupportDirectory: { root },
            bundleIdentifier: { "com.example.AppTemplate" },
            createDirectory: { recorder.record($0) }
        )

        #expect(recorder.urls.isEmpty)

        let url = try resolver.resolve()

        let expectedDirectory = root.appending(
            path: "com.example.AppTemplate",
            directoryHint: .isDirectory
        )
        #expect(recorder.urls == [expectedDirectory])
        #expect(
            url
                == expectedDirectory.appending(
                    path: "LocalDatabase.store",
                    directoryHint: .notDirectory
                )
        )
    }

    @Test
    func liveResolverRejectsMissingOrEmptyBundleIdentifier() {
        for identifier: String? in [nil, ""] {
            let resolver = LocalDatabaseStoreLocationResolver.live(
                applicationSupportDirectory: {
                    URL(filePath: "/tmp", directoryHint: .isDirectory)
                },
                bundleIdentifier: { identifier },
                createDirectory: { _ in }
            )

            #expect(throws: LocalDatabaseStoreLocationError.self) {
                _ = try resolver.resolve()
            }
        }
    }

    @Test
    func liveResolverPropagatesDirectoryCreationFailure() {
        let resolver = LocalDatabaseStoreLocationResolver.live(
            applicationSupportDirectory: {
                URL(filePath: "/tmp", directoryHint: .isDirectory)
            },
            bundleIdentifier: { "com.example.AppTemplate" },
            createDirectory: { _ in
                throw ConfigurationFixtureError.directoryCreation
            }
        )

        #expect(throws: ConfigurationFixtureError.self) {
            _ = try resolver.resolve()
        }
    }

    @Test
    func liveFactoryDoesNotResolveLocationUntilInvoked() throws {
        let calls = SynchronousCounter()
        let url = try uniqueLocalDatabaseStoreURL(label: "lazy-live")
        let factory = LocalDatabaseContainerFactories.live(
            locationResolver: .init(resolve: {
                calls.increment()
                return url
            })
        )

        #expect(calls.value == 0)
        _ = try factory()
        #expect(calls.value == 1)
    }

    @Test
    func inMemoryFactoryCreatesIndependentContainers() throws {
        let factory = LocalDatabaseContainerFactories.inMemory()
        let first = try factory()
        let second = try factory()

        #expect(first !== second)
        #expect(first.configurations.allSatisfy(\.isStoredInMemoryOnly))
        #expect(second.configurations.allSatisfy(\.isStoredInMemoryOnly))
    }

    @Test
    func diskFactoryUsesExactURLAndAllowsSave() throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "configuration")
        let container = try LocalDatabaseContainerFactories.disk(url: url)()
        let configuration = try #require(container.configurations.first)

        #expect(configuration.url == url)
        #expect(configuration.allowsSave)
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test
    func schemaEnforcesOneStoredEntityPerBusinessID() throws {
        let container = try LocalDatabaseContainerFactories.inMemory()()
        let firstContext = ModelContext(container)
        firstContext.autosaveEnabled = false
        firstContext.insert(
            LocalDatabaseSchemaV1.StoredExampleRecord(
                id: "same",
                payload: "first"
            )
        )
        try firstContext.save()

        let secondContext = ModelContext(container)
        secondContext.autosaveEnabled = false
        secondContext.insert(
            LocalDatabaseSchemaV1.StoredExampleRecord(
                id: "same",
                payload: "second"
            )
        )
        try secondContext.save()

        let verifier = ModelContext(container)
        let rows = try verifier.fetch(
            FetchDescriptor<
                LocalDatabaseSchemaV1.StoredExampleRecord
            >()
        )
        #expect(rows.count == 1)
        #expect(rows.first?.payload == "second")
    }
}

nonisolated
private final class DirectoryCreationRecorder: Sendable {
    private let storage = Mutex<[URL]>([])

    var urls: [URL] { storage.withLock { $0 } }

    func record(_ url: URL) {
        storage.withLock { $0.append(url) }
    }
}

nonisolated
private enum ConfigurationFixtureError: Error, Sendable {
    case directoryCreation
}

nonisolated
private final class SynchronousCounter: Sendable {
    private let storage = Mutex(0)

    var value: Int { storage.withLock { $0 } }

    func increment() {
        storage.withLock { $0 += 1 }
    }
}

private func uniqueLocalDatabaseStoreURL(label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "AppTemplate-SwiftData-\(label)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory.appending(
        path: "LocalDatabase.store",
        directoryHint: .notDirectory
    )
}
```

These file-private helpers are the complete Task 2 support surface. They retain every UUID-scoped disk fixture for inspection and never open the default live Application Support path.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task2-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65 because the resolver, location error, alias, and factories are undefined. The RED test must not invoke the default live Application Support resolver.

- [ ] **Step 3: Implement the explicit configuration boundary**

Create `LocalDatabaseStoreConfiguration.swift` with this complete shape:

```swift
import Foundation
import SwiftData

typealias LocalDatabaseContainerFactory =
    @Sendable () throws -> ModelContainer

nonisolated
enum LocalDatabaseStoreLocationError: Error, Equatable, Sendable {
    case missingBundleIdentifier
}

nonisolated
struct LocalDatabaseStoreLocationResolver: Sendable {
    let resolve: @Sendable () throws -> URL

    static func live(
        applicationSupportDirectory:
            @escaping @Sendable () throws -> URL = {
                try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
            },
        bundleIdentifier:
            @escaping @Sendable () -> String? = {
                Bundle.main.bundleIdentifier
            },
        createDirectory:
            @escaping @Sendable (URL) throws -> Void = { url in
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true
                )
            }
    ) -> LocalDatabaseStoreLocationResolver {
        LocalDatabaseStoreLocationResolver {
            guard
                let identifier = bundleIdentifier(),
                !identifier.isEmpty
            else {
                throw LocalDatabaseStoreLocationError
                    .missingBundleIdentifier
            }

            let directory = try applicationSupportDirectory()
                .appending(
                    path: identifier,
                    directoryHint: .isDirectory
                )
            try createDirectory(directory)
            return directory.appending(
                path: "LocalDatabase.store",
                directoryHint: .notDirectory
            )
        }
    }
}

nonisolated
enum LocalDatabaseContainerFactories {
    static func live(
        locationResolver: LocalDatabaseStoreLocationResolver = .live()
    ) -> LocalDatabaseContainerFactory {
        {
            try disk(url: locationResolver.resolve())()
        }
    }

    static func disk(url: URL) -> LocalDatabaseContainerFactory {
        {
            let schema = Schema(
                versionedSchema: LocalDatabaseSchemaV1.self
            )
            let configuration = ModelConfiguration(
                "LocalDatabase",
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: LocalDatabaseMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }

    static func inMemory() -> LocalDatabaseContainerFactory {
        {
            let schema = Schema(
                versionedSchema: LocalDatabaseSchemaV1.self
            )
            let configuration = ModelConfiguration(
                "LocalDatabase",
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: LocalDatabaseMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }
}
```

Do not create the container or directory while constructing a factory. Do not catch factory errors here; the facade maps and caches non-cancellation bootstrap failures in Task 6.

- [ ] **Step 4: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task2-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task2.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task2.xcresult" \
  | jq -e '.result == "Passed"
      and .failedTests == 0
      and .skippedTests == 0
      and .expectedFailures == 0
      and .totalTestCount > 0'

test "$(rg -n 'cloudKitDatabase: \.none' \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift \
  | wc -l | tr -d ' ')" = 2
test "$(rg -n 'groupContainer: \.none' \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift \
  | wc -l | tr -d ' ')" = 1
```

Expected: all selected tests pass; every container is explicitly V1-configured, in-memory containers are distinct, and the live resolver remains lazy.

- [ ] **Step 5: Self-review and commit Task 2**

```bash
git diff --check
git add \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift
git diff --cached --check
git commit -m "feat: configure SwiftData local stores"
```

---

### Task 3: Implement Single-Record SwiftData Operations and Safe Diagnostics

**Files:**

- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreHooks.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift`
- Create: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Create: `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift`

**Interfaces:**

- Consumes: V1 containers from Task 2 and operation/error values from Task 1.
- Produces: `LocalDatabaseStoreCheckpoint`, `LocalDatabaseStoreHooks.production`, typed `LocalDatabaseFailureMetadata`, and a `SwiftDataLocalStore` with `fetchRecord(id:)`, `upsert(_:)`, and `deleteRecord(id:)`.

- [ ] **Step 1: Write single-record, hook, rollback, and redaction RED tests**

Create `LocalDatabaseTestSupport.swift` with these exact reusable entry points:

```swift
import Foundation
import SwiftData
import Synchronization
import Testing
@testable import AppTemplate

nonisolated
func makeInMemoryLocalDatabaseContainer() throws -> ModelContainer {
    try LocalDatabaseContainerFactories.inMemory()()
}

nonisolated
func makeInMemoryLocalStore(
    hooks: LocalDatabaseStoreHooks = .production
) throws -> SwiftDataLocalStore {
    SwiftDataLocalStore(
        modelContainer: try makeInMemoryLocalDatabaseContainer(),
        hooks: hooks
    )
}

nonisolated
func uniqueLocalDatabaseStoreURL(label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(
            path: "AppTemplate-SwiftData-\(label)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    return directory.appending(
        path: "LocalDatabase.store",
        directoryHint: .notDirectory
    )
}

nonisolated
final class LocalDatabaseHookRecorder: Sendable {
    private struct State: Sendable {
        var checkpoints: [LocalDatabaseStoreCheckpoint] = []
        var saves: [LocalDatabaseWriteOperation] = []
        var rollbacks: [LocalDatabaseWriteOperation] = []
    }

    private let state = Mutex(State())
    private let failingCheckpoint: LocalDatabaseStoreCheckpoint?
    private let cancellingCheckpoint: LocalDatabaseStoreCheckpoint?

    init(
        failingCheckpoint: LocalDatabaseStoreCheckpoint? = nil,
        cancellingCheckpoint: LocalDatabaseStoreCheckpoint? = nil
    ) {
        self.failingCheckpoint = failingCheckpoint
        self.cancellingCheckpoint = cancellingCheckpoint
    }

    var checkpoints: [LocalDatabaseStoreCheckpoint] {
        state.withLock { $0.checkpoints }
    }

    var saves: [LocalDatabaseWriteOperation] {
        state.withLock { $0.saves }
    }

    var rollbacks: [LocalDatabaseWriteOperation] {
        state.withLock { $0.rollbacks }
    }

    func hooks() -> LocalDatabaseStoreHooks {
        LocalDatabaseStoreHooks(
            checkpoint: { [self] checkpoint in
                state.withLock { $0.checkpoints.append(checkpoint) }
                if checkpoint == cancellingCheckpoint {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
                if checkpoint == failingCheckpoint {
                    throw LocalDatabaseTestError.injectedFailure
                }
            },
            didSave: { [self] operation in
                state.withLock { $0.saves.append(operation) }
            },
            didRollback: { [self] operation in
                state.withLock { $0.rollbacks.append(operation) }
            }
        )
    }
}

nonisolated
enum LocalDatabaseTestError: Error, Equatable, Sendable {
    case injectedFailure
}
```

All temporary store helpers throw and use a new UUID-scoped directory. Production LocalDatabase sources remain free of `try!`, `try?`, and fatal termination.

Create `SwiftDataLocalStoreMutationTests.swift` with separate tests for:

```swift
import Foundation
import SwiftData
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreMutationTests {
    @Test
    func insertAndExactFetchRoundTripValue() async throws {
        let store = try makeInMemoryLocalStore()
        let record = ExampleRecord(id: "record-1", payload: "value")

        try await store.upsert(record)

        #expect(try await store.fetchRecord(id: record.id) == record)
        #expect(try await store.fetchRecord(id: "missing") == nil)
    }

    @Test
    func emptyPayloadRoundTripsWithoutNormalization() async throws {
        let store = try makeInMemoryLocalStore()
        let record = ExampleRecord(id: "empty-payload", payload: "")

        try await store.upsert(record)

        #expect(try await store.fetchRecord(id: record.id) == record)
    }

    @Test
    func updateChangesExistingEntityWithoutDuplicate() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "before")
        )

        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "after")
        )

        #expect(
            try await store.fetchRecord(id: "record-1")
                == ExampleRecord(id: "record-1", payload: "after")
        )
    }

    @Test
    func unchangedUpsertDoesNotSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let record = ExampleRecord(id: "record-1", payload: "same")
        try await store.upsert(record)

        try await store.upsert(record)

        #expect(recorder.saves == [.upsertOne])
    }

    @Test
    func missingDeleteIsNoOpAndPresentDeleteSaves() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        #expect(try await store.deleteRecord(id: "missing") == false)
        #expect(recorder.saves.isEmpty)

        try await store.upsert(
            ExampleRecord(id: "record-1", payload: "value")
        )
        #expect(try await store.deleteRecord(id: "record-1"))
        #expect(try await store.fetchRecord(id: "record-1") == nil)
        #expect(recorder.saves == [.upsertOne, .deleteOne])
    }

    @Test
    func beforeSaveFailureRollsBackAndMapsWriteOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.upsertOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            try await store.upsert(
                ExampleRecord(id: "record-1", payload: "secret")
            )
            Issue.record("Expected write failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, underlying) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .upsertOne)
            #expect(underlying is LocalDatabaseTestError)
        }

        #expect(recorder.rollbacks == [.upsertOne])
        #expect(try await store.fetchRecord(id: "record-1") == nil)
    }

    @Test
    func realSaveFailureDiscardsStaleOperationContext() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "read-only")
        do {
            let writable = try LocalDatabaseContainerFactories.disk(url: url)()
            let seedContext = ModelContext(writable)
            seedContext.autosaveEnabled = false
            seedContext.insert(
                LocalDatabaseSchemaV1.StoredExampleRecord(
                    id: "record-1",
                    payload: "durable"
                )
            )
            try seedContext.save()
        }

        let schema = Schema(versionedSchema: LocalDatabaseSchemaV1.self)
        let readOnlyConfiguration = ModelConfiguration(
            "LocalDatabase",
            schema: schema,
            url: url,
            allowsSave: false,
            cloudKitDatabase: .none
        )
        let readOnlyContainer = try ModelContainer(
            for: schema,
            migrationPlan: LocalDatabaseMigrationPlan.self,
            configurations: [readOnlyConfiguration]
        )
        let store = SwiftDataLocalStore(
            modelContainer: readOnlyContainer,
            hooks: .production
        )

        do {
            try await store.upsert(
                ExampleRecord(id: "record-1", payload: "unsaved")
            )
            Issue.record("Expected the read-only save to fail")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .upsertOne)
        }

        #expect(
            try await store.fetchRecord(id: "record-1")
                == ExampleRecord(id: "record-1", payload: "durable")
        )
    }

    @Test
    func cancellationRaisedAfterSaveDoesNotReplaceSuccess() async throws {
        let hooks = LocalDatabaseStoreHooks(
            checkpoint: { _ in },
            didSave: { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            },
            didRollback: { _ in }
        )
        let store = try makeInMemoryLocalStore(hooks: hooks)
        let record = ExampleRecord(id: "record-1", payload: "durable")
        let request = Task { () -> Result<Void, any Error> in
            do {
                try await store.upsert(record)
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        guard case .success = await request.value else {
            Issue.record("A successful save must return success")
            return
        }
        #expect(try await store.fetchRecord(id: record.id) == record)
    }

    @Test
    func readCheckpointFailureMapsExactReadOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .read(.fetchOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            _ = try await store.fetchRecord(id: "record-1")
            Issue.record("Expected read failure")
        } catch let error as LocalDatabaseError {
            guard case let .read(operation, underlying) = error else {
                Issue.record("Expected LocalDatabaseError.read")
                return
            }
            #expect(operation == .fetchOne)
            #expect(underlying is LocalDatabaseTestError)
        }
    }

    @Test
    func diagnosticMetadataCannotCarrySensitiveErrorDescription() {
        let sentinel = NSError(
            domain: "FixtureDomain",
            code: 73,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "id=record-1 payload=secret search=needle "
                    + "path=/Users/person/LocalDatabase.store"
            ]
        )

        let metadata = LocalDatabaseDiagnostics.metadata(
            operation: .write(.upsertOne),
            recordCount: 1,
            error: sentinel
        )

        #expect(metadata.operation == .write(.upsertOne))
        #expect(metadata.entityType == "StoredExampleRecord")
        #expect(metadata.recordCount == 1)
        #expect(metadata.errorDomain == "FixtureDomain")
        #expect(metadata.errorCode == 73)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task3-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65 because `SwiftDataLocalStore`, hooks, and diagnostics do not exist.

- [ ] **Step 3: Implement hooks and typed diagnostics**

Create `LocalDatabaseStoreHooks.swift`:

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

    static let production = LocalDatabaseStoreHooks(
        checkpoint: { _ in },
        didSave: { _ in },
        didRollback: { _ in }
    )
}
```

Create `LocalDatabaseDiagnostics.swift`:

```swift
import Foundation
import OSLog

nonisolated
enum LocalDatabaseDiagnosticOperation: Equatable, Sendable {
    case initialization
    case read(LocalDatabaseReadOperation)
    case write(LocalDatabaseWriteOperation)
}

nonisolated
struct LocalDatabaseFailureMetadata: Equatable, Sendable {
    let operation: LocalDatabaseDiagnosticOperation
    let entityType: String
    let recordCount: Int
    let errorDomain: String
    let errorCode: Int
}

nonisolated
enum LocalDatabaseDiagnostics {
    private static let logger = Logger(
        subsystem: "AppTemplate",
        category: "LocalDatabase"
    )

    static func metadata(
        operation: LocalDatabaseDiagnosticOperation,
        recordCount: Int,
        error: any Error
    ) -> LocalDatabaseFailureMetadata {
        let frameworkError = error as NSError
        return LocalDatabaseFailureMetadata(
            operation: operation,
            entityType: "StoredExampleRecord",
            recordCount: recordCount,
            errorDomain: frameworkError.domain,
            errorCode: frameworkError.code
        )
    }

    static func report(
        operation: LocalDatabaseDiagnosticOperation,
        recordCount: Int,
        error: any Error
    ) {
        let value = metadata(
            operation: operation,
            recordCount: recordCount,
            error: error
        )
        logger.error("operation=\(String(describing: value.operation), privacy: .public) entity=\(value.entityType, privacy: .public) count=\(value.recordCount, privacy: .public) domain=\(value.errorDomain, privacy: .public) code=\(value.errorCode, privacy: .public)")
    }
}
```

The diagnostics API has no parameter capable of receiving record content. Do not add an error description, userInfo, URL, record, ID, payload, or query parameter.

- [ ] **Step 4: Implement the single-record ModelActor engine**

Create `SwiftDataLocalStore.swift`. Use `private var hooks = .production`, because `@ModelActor` also synthesizes its one-argument initializer; the default leaves that generated initializer valid, while all application construction uses the explicit two-argument initializer.

```swift
import Foundation
import SwiftData

@ModelActor
actor SwiftDataLocalStore {
    private typealias StoredRecord =
        LocalDatabaseSchemaV1.StoredExampleRecord

    private var hooks: LocalDatabaseStoreHooks = .production

    init(
        modelContainer: ModelContainer,
        hooks: LocalDatabaseStoreHooks
    ) {
        let executorContext = ModelContext(modelContainer)
        executorContext.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: executorContext
        )
        self.modelContainer = modelContainer
        self.hooks = hooks
    }

    func fetchRecord(id: String) throws -> ExampleRecord? {
        let operation = LocalDatabaseReadOperation.fetchOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.read(operation))
            try Task.checkCancellation()
            return try storedRecord(id: id, in: context).map(value(from:))
        } catch {
            throw mapReadFailure(
                error,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func upsert(_ record: ExampleRecord) throws {
        let operation = LocalDatabaseWriteOperation.upsertOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()

            if let stored = try storedRecord(id: record.id, in: context) {
                guard stored.payload != record.payload else { return }
                stored.payload = record.payload
            } else {
                context.insert(
                    StoredRecord(id: record.id, payload: record.payload)
                )
            }

            try save(context: context, operation: operation)
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    func deleteRecord(id: String) throws -> Bool {
        let operation = LocalDatabaseWriteOperation.deleteOne
        try Task.checkCancellation()
        let context = makeOperationContext()
        do {
            try hooks.checkpoint(.writePreparation(operation))
            try Task.checkCancellation()
            guard let stored = try storedRecord(id: id, in: context) else {
                return false
            }
            context.delete(stored)
            try save(context: context, operation: operation)
            return true
        } catch {
            throw rollbackAndMapWriteFailure(
                error,
                context: context,
                operation: operation,
                recordCount: 1
            )
        }
    }

    private func makeOperationContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
    }

    private func storedRecord(
        id: String,
        in context: ModelContext
    ) throws -> StoredRecord? {
        var descriptor = FetchDescriptor<StoredRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func value(from stored: StoredRecord) -> ExampleRecord {
        ExampleRecord(id: stored.id, payload: stored.payload)
    }

    private func save(
        context: ModelContext,
        operation: LocalDatabaseWriteOperation
    ) throws {
        try hooks.checkpoint(.beforeSave(operation))
        try Task.checkCancellation()
        try context.save()
        hooks.didSave(operation)
    }

    private func mapReadFailure(
        _ error: any Error,
        operation: LocalDatabaseReadOperation,
        recordCount: Int
    ) -> any Error {
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .read(operation),
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.read(
            operation: operation,
            underlying: error
        )
    }

    private func rollbackAndMapWriteFailure(
        _ error: any Error,
        context: ModelContext,
        operation: LocalDatabaseWriteOperation,
        recordCount: Int
    ) -> any Error {
        context.rollback()
        hooks.didRollback(operation)
        if error is CancellationError { return error }
        LocalDatabaseDiagnostics.report(
            operation: .write(operation),
            recordCount: recordCount,
            error: error
        )
        return LocalDatabaseError.write(
            operation: operation,
            underlying: error
        )
    }
}
```

Every storage-requiring engine call creates exactly one operation context; the empty-batch fast path creates none. No context is reused after returning or throwing. This is deliberate: an Xcode 26.6 runtime probe showed that `rollback()` after a real `save()` failure can leave an unsaved registered-model value visible through the same context even though `hasChanges == false`; a fresh context reads the durable value. Do not expose `StoredRecord`, any context, `modelExecutor`, or `modelContainer`. Do not test thread identity; the `ModelActor` promise is serialization.

- [ ] **Step 5: Run focused GREEN and inspect the privacy boundary**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task3-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task3.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task3.xcresult" \
  | jq -e '.result == "Passed"
      and .failedTests == 0
      and .skippedTests == 0
      and .expectedFailures == 0
      and .passedTests == .totalTestCount
      and .totalTestCount > 0'

if rg -n 'logger\..*(id|payload|searchText|storeURL|localizedDescription|userInfo)' \
  AppTemplate/App/Services/LocalDatabase; then
  exit 1
fi
```

Expected: tests and summary assertion pass, the sentinel description cannot enter `LocalDatabaseFailureMetadata`, and the source scan has no match.

- [ ] **Step 6: Self-review and commit Task 3**

```bash
git diff --check
git add \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreHooks.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift
git diff --cached --check
git commit -m "feat: add SwiftData record mutations"
```

---

### Task 4: Add Batch Mutations, Delete-All, and Pre-Save Cancellation

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift`

**Interfaces:**

- Consumes: Task 3's operation-scoped-context invariant, `save(context:operation:)`, failed-context discard mapping, and hooks.
- Produces: synchronous actor-isolated `upsert(_ records: [ExampleRecord]) throws` and `deleteAllRecords() throws -> Int`.

- [ ] **Step 1: Write batch, delete-all, rollback, and cancellation RED tests**

Create `SwiftDataLocalStoreBatchTests.swift` with separate tests proving:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreBatchTests {
    @Test
    func batchInsertsAndUpdatesWithOneSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(recorder.saves == [.upsertBatch])
        #expect(
            try await store.fetchRecord(id: "a")
                == ExampleRecord(id: "a", payload: "one")
        )

        try await store.upsert([
            ExampleRecord(id: "a", payload: "updated"),
            ExampleRecord(id: "c", payload: "three")
        ])
        #expect(recorder.saves == [.upsertBatch, .upsertBatch])
    }

    @Test
    func emptyAndFullyUnchangedBatchesDoNotSave() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [ExampleRecord(id: "a", payload: "same")]

        try await store.upsert([])
        #expect(recorder.saves.isEmpty)
        try await store.upsert(records)
        try await store.upsert(records)
        #expect(recorder.saves == [.upsertBatch])
    }

    @Test
    func failedBatchRollsBackEveryPendingChange() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.upsertBatch)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            try await store.upsert([
                ExampleRecord(id: "a", payload: "one"),
                ExampleRecord(id: "b", payload: "two")
            ])
            Issue.record("Expected batch write failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .upsertBatch)
        }

        #expect(recorder.rollbacks == [.upsertBatch])
        #expect(try await store.fetchRecord(id: "a") == nil)
        #expect(try await store.fetchRecord(id: "b") == nil)
    }

    @Test
    func deleteAllReturnsCountAndSavesOnlyWhenNonempty() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        #expect(try await store.deleteAllRecords() == 0)
        #expect(recorder.saves.isEmpty)
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(try await store.deleteAllRecords() == 2)
        #expect(recorder.saves == [.upsertBatch, .deleteAll])
        #expect(try await store.fetchRecord(id: "a") == nil)
    }

    @Test
    func cancellationAtPreSaveCheckpointRollsBackChildTask() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .beforeSave(.upsertBatch)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let request = Task { () -> Result<Void, any Error> in
            do {
                try await store.upsert([
                    ExampleRecord(id: "a", payload: "one")
                ])
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        switch await request.value {
        case .success:
            Issue.record("Expected cancellation")
        case let .failure(error):
            #expect(error is CancellationError)
        }
        #expect(recorder.rollbacks == [.upsertBatch])
        #expect(try await store.fetchRecord(id: "a") == nil)
    }

    @Test
    func failedDeleteOneKeepsDurableRecord() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.deleteOne)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let record = ExampleRecord(id: "a", payload: "durable")
        try await store.upsert(record)

        do {
            _ = try await store.deleteRecord(id: record.id)
            Issue.record("Expected delete failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .deleteOne)
        }
        #expect(recorder.rollbacks == [.deleteOne])
        #expect(try await store.fetchRecord(id: record.id) == record)
    }

    @Test
    func cancelledDeleteAllKeepsEveryDurableRecord() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .beforeSave(.deleteAll)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ]
        try await store.upsert(records)
        let request = Task { () -> Result<Int, any Error> in
            do { return .success(try await store.deleteAllRecords()) }
            catch { return .failure(error) }
        }

        guard case let .failure(error) = await request.value else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.rollbacks == [.deleteAll])
        #expect(try await store.fetchRecord(id: "a") == records[0])
        #expect(try await store.fetchRecord(id: "b") == records[1])
    }

    @Test
    func failedDeleteAllMapsOperationAndKeepsDurableRecords() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .beforeSave(.deleteAll)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = [
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ]
        try await store.upsert(records)

        do {
            _ = try await store.deleteAllRecords()
            Issue.record("Expected delete-all failure")
        } catch let error as LocalDatabaseError {
            guard case let .write(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.write")
                return
            }
            #expect(operation == .deleteAll)
        }
        #expect(recorder.rollbacks == [.deleteAll])
        #expect(try await store.fetchRecord(id: "a") == records[0])
        #expect(try await store.fetchRecord(id: "b") == records[1])
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task4-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65 because the batch and delete-all engine methods do not exist.

- [ ] **Step 3: Implement batch upsert and type-level delete**

Add these methods inside `SwiftDataLocalStore`:

```swift
func upsert(_ records: [ExampleRecord]) throws {
    guard !records.isEmpty else { return }
    let operation = LocalDatabaseWriteOperation.upsertBatch
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()

        let ids = records.map(\.id)
        let descriptor = FetchDescriptor<StoredRecord>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let existing = try context.fetch(descriptor)
        let existingByID = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.id, $0) }
        )
        var changed = false

        for record in records {
            if let stored = existingByID[record.id] {
                if stored.payload != record.payload {
                    stored.payload = record.payload
                    changed = true
                }
            } else {
                context.insert(
                    StoredRecord(id: record.id, payload: record.payload)
                )
                changed = true
            }
        }

        guard changed else { return }
        try save(context: context, operation: operation)
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            context: context,
            operation: operation,
            recordCount: records.count
        )
    }
}

func deleteAllRecords() throws -> Int {
    let operation = LocalDatabaseWriteOperation.deleteAll
    try Task.checkCancellation()
    let context = makeOperationContext()
    var recordCount = 0
    do {
        try hooks.checkpoint(.writePreparation(operation))
        try Task.checkCancellation()
        let descriptor = FetchDescriptor<StoredRecord>()
        recordCount = try context.fetchCount(descriptor)
        guard recordCount > 0 else { return 0 }
        try context.delete(
            model: StoredRecord.self,
            where: nil,
            includeSubclasses: false
        )
        try save(context: context, operation: operation)
        return recordCount
    } catch {
        throw rollbackAndMapWriteFailure(
            error,
            context: context,
            operation: operation,
            recordCount: recordCount
        )
    }
}
```

The captured-ID `#Predicate` shape has been compile- and runtime-probed against the local SwiftData SDK. Do not replace type-level delete with a fetch of every entity or `ModelContainer.deleteAllData()`.

- [ ] **Step 4: Run batch GREEN plus all mutation tests**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task4-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task4.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task4.xcresult" --compact \
| jq -e '.result == "Passed"
    and .totalTestCount > 0
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
    and .passedTests == .totalTestCount'
```

Expected: every selected test passes; child cancellation is returned as `CancellationError`, the test runner is not marked cancelled, and no test is skipped.

- [ ] **Step 5: Self-review and commit Task 4**

```bash
git diff --check
git add \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift
git diff --cached --check
git commit -m "feat: add SwiftData batch mutations"
```

---

### Task 5: Add Bounded Normalized Queries and Progress Cancellation

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift`

**Interfaces:**

- Consumes: `ExampleQuery`, clean-context save/rollback invariant, `.read(.fetchMany)`, and `.readProgress(.fetchMany)`.
- Produces: synchronous actor-isolated `fetchRecords(matching:) throws -> [ExampleRecord]` with bounded output and fixed-size lazy traversal.

- [ ] **Step 1: Write ordering, normalization, traversal, failure, and cancellation RED tests**

Create `SwiftDataLocalStoreQueryTests.swift`. Use one fresh store per test and cover these exact cases:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct SwiftDataLocalStoreQueryTests {
    @Test
    func unfilteredResultsUseStoreIDOrderAndLimit() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "c", payload: "three"),
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        let records = try await store.fetchRecords(
            matching: ExampleQuery(limit: 2)
        )

        #expect(records.map(\.id) == ["a", "b"])
    }

    @Test
    func searchUsesTrimmedCaseDiacriticAndWidthInsensitiveSubstring() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "a", payload: "Résumé Café"),
            ExampleRecord(id: "b", payload: "ＰＡＹＬＯＡＤ value"),
            ExampleRecord(id: "c", payload: "other")
        ])

        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "  cafe  ")
            ).map(\.id) == ["a"]
        )
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "payload")
            ).map(\.id) == ["b"]
        )
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "   ")
            ).count == 3
        )
    }

    @Test
    func filteredSearchContinuesPastFirstStorageBatch() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        let records = (0..<130).map { index in
            ExampleRecord(
                id: String(format: "item-%03d", index),
                payload: index == 129 ? "needle" : "haystack"
            )
        }
        try await store.upsert(records)

        let result = try await store.fetchRecords(
            matching: ExampleQuery(searchText: "needle", limit: 1)
        )

        #expect(result.map(\.id) == ["item-129"])
        #expect(
            recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func filteredSearchStopsBeforeUnneededProgressCheckpoint() async throws {
        let recorder = LocalDatabaseHookRecorder()
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<130).map { index in
                ExampleRecord(
                    id: String(format: "item-%03d", index),
                    payload: index == 0 ? "needle" : "haystack"
                )
            }
        )

        let result = try await store.fetchRecords(
            matching: ExampleQuery(searchText: "needle", limit: 1)
        )

        #expect(result.map(\.id) == ["item-000"])
        #expect(
            !recorder.checkpoints.contains(.readProgress(.fetchMany))
        )
    }

    @Test
    func filteredSearchReturnsEmptyWhenNothingMatches() async throws {
        let store = try makeInMemoryLocalStore()
        try await store.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])

        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(searchText: "missing", limit: 1)
            ).isEmpty
        )
    }

    @Test
    func filteredReadCancellationUsesChildAndLeavesStoreUsable() async throws {
        let recorder = LocalDatabaseHookRecorder(
            cancellingCheckpoint: .readProgress(.fetchMany)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())
        try await store.upsert(
            (0..<130).map {
                ExampleRecord(
                    id: String(format: "item-%03d", $0),
                    payload: "haystack"
                )
            }
        )
        let request = Task { () -> Result<[ExampleRecord], any Error> in
            do {
                return .success(
                    try await store.fetchRecords(
                        matching: ExampleQuery(searchText: "missing")
                    )
                )
            } catch {
                return .failure(error)
            }
        }

        switch await request.value {
        case .success:
            Issue.record("Expected cancellation")
        case let .failure(error):
            #expect(error is CancellationError)
        }
        #expect(
            try await store.fetchRecords(
                matching: ExampleQuery(limit: 1)
            ).count == 1
        )
    }

    @Test
    func fetchManyCheckpointFailureMapsReadOperation() async throws {
        let recorder = LocalDatabaseHookRecorder(
            failingCheckpoint: .read(.fetchMany)
        )
        let store = try makeInMemoryLocalStore(hooks: recorder.hooks())

        do {
            _ = try await store.fetchRecords(matching: ExampleQuery())
            Issue.record("Expected read failure")
        } catch let error as LocalDatabaseError {
            guard case let .read(operation, _) = error else {
                Issue.record("Expected LocalDatabaseError.read")
                return
            }
            #expect(operation == .fetchMany)
        }
    }
}
```

- [ ] **Step 2: Run the focused query suite and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task5-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65 because `fetchRecords(matching:)` does not exist.

- [ ] **Step 3: Implement bounded output and lazy batched traversal**

Add this method and normalizer inside `SwiftDataLocalStore`:

```swift
func fetchRecords(
    matching query: ExampleQuery
) throws -> [ExampleRecord] {
    let operation = LocalDatabaseReadOperation.fetchMany
    try Task.checkCancellation()
    let context = makeOperationContext()
    do {
        try hooks.checkpoint(.read(operation))
        try Task.checkCancellation()

        var descriptor = FetchDescriptor<StoredRecord>(
            sortBy: [SortDescriptor(\StoredRecord.id)]
        )
        guard let normalizedSearch = normalizedSearch(query.searchText) else {
            descriptor.fetchLimit = query.limit
            return try context.fetch(descriptor).map(value(from:))
        }

        descriptor.includePendingChanges = false
        let storedRecords = try context.fetch(
            descriptor,
            batchSize: 128
        )
        var matches: [ExampleRecord] = []
        var examined = 0

        for stored in storedRecords {
            examined += 1
            let normalizedPayload = stored.payload.folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive,
                    .widthInsensitive
                ],
                locale: nil
            )
            if normalizedPayload.contains(normalizedSearch) {
                matches.append(value(from: stored))
            }
            if examined.isMultiple(of: 128) {
                try hooks.checkpoint(.readProgress(operation))
                try Task.checkCancellation()
            }
            if matches.count == query.limit { return matches }
        }

        try Task.checkCancellation()
        return matches
    } catch {
        throw mapReadFailure(
            error,
            operation: operation,
            recordCount: query.limit
        )
    }
}

private func normalizedSearch(_ searchText: String?) -> String? {
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
```

Do not persist normalized text and do not add cursor fields. `fetch(_:batchSize:)` plus `includePendingChanges = false` is valid because every earlier write on the engine saved or rolled back.

- [ ] **Step 4: Run all engine suites GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task5-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task5.xcresult" \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task5.xcresult" --compact \
| jq -e '.result == "Passed"
    and .totalTestCount > 0
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
    and .passedTests == .totalTestCount'
```

Expected: all suites pass. The 130-record fixture proves traversal beyond the first batch; cancellation is observed inside the child request, and the runner test passes rather than being recorded as cancelled.

- [ ] **Step 5: Self-review and commit Task 5**

```bash
git diff --check
git add \
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift \
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift
git diff --cached --check
git commit -m "feat: add bounded SwiftData queries"
```

---

### Task 6: Add the Lazy Facade, Public API, Composition, and Reopen Coverage

**Files:**

- Modify: `AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift`
- Modify: `AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift`
- Modify: `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift`
- Modify: `AppTemplateTests/App/Composition/AppDependenciesTests.swift`
- Modify: `AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift`
- Create: `AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift`

**Interfaces:**

- Consumes: the six synchronous actor-isolated `SwiftDataLocalStore` operations, `LocalDatabaseContainerFactory`, `LocalDatabaseStoreHooks`, validators, and error categories from Tasks 1–5.
- Produces: the six-method `ILocalDatabaseService`, lazy/cached `LocalDatabaseService`, persistent live composition, isolated preview/UI-test composition, and public integration coverage.

- [ ] **Step 1: Extend test support with deterministic factory and cancellation controls**

Append these exact helpers to `LocalDatabaseTestSupport.swift`:

```swift
nonisolated
final class LocalDatabaseContainerFactoryRecorder: Sendable {
    private let callCounter = Mutex(0)
    private let make: @Sendable (Int) throws -> ModelContainer

    init(
        make: @escaping @Sendable (Int) throws -> ModelContainer
    ) {
        self.make = make
    }

    var callCount: Int {
        callCounter.withLock { $0 }
    }

    var factory: LocalDatabaseContainerFactory {
        { [self] in
            let invocation = callCounter.withLock {
                $0 += 1
                return $0
            }
            return try make(invocation)
        }
    }
}

nonisolated
enum LocalDatabasePreCancelledInvocation:
    CaseIterable,
    CustomTestStringConvertible,
    Sendable
{
    case fetchOne
    case fetchMany
    case upsertOne
    case upsertBatch
    case deleteOne
    case deleteAll

    var testDescription: String { String(describing: self) }

    func invoke(on service: any ILocalDatabaseService) async throws {
        switch self {
        case .fetchOne:
            _ = try await service.fetchRecord(id: "record-1")
        case .fetchMany:
            _ = try await service.fetchRecords(matching: ExampleQuery())
        case .upsertOne:
            try await service.upsert(
                ExampleRecord(id: "record-1", payload: "value")
            )
        case .upsertBatch:
            try await service.upsert([
                ExampleRecord(id: "record-1", payload: "value")
            ])
        case .deleteOne:
            _ = try await service.deleteRecord(id: "record-1")
        case .deleteAll:
            _ = try await service.deleteAllRecords()
        }
    }
}

private actor ControlledLocalDatabaseOperationStart {
    private var didStart = false
    private var isReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func suspendBeforeOperation() async {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
        guard !isReleased else { return }
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        isReleased = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

nonisolated
func resultOfPreCancelledChildTask<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> Result<Value, any Error> {
    let gate = ControlledLocalDatabaseOperationStart()
    let child = Task {
        await gate.suspendBeforeOperation()
        do {
            return Result<Value, any Error>.success(try await operation())
        } catch {
            return Result<Value, any Error>.failure(error)
        }
    }

    await gate.waitUntilStarted()
    child.cancel()
    await gate.release()
    return await child.value
}
```

The recorder invokes `make` after releasing the `Mutex`; test closures may safely query the recorder or build SwiftData objects. The child helper cancels only its child, never the Swift Testing runner task.

- [ ] **Step 2: Write facade state-machine RED tests**

Replace the empty-interface test in `LocalDatabaseServiceTests.swift` with these named behaviors. Use `LocalDatabaseContainerFactoryRecorder`, a fresh in-memory container per recorder, and `resultOfPreCancelledChildTask`:

```swift
import SwiftData
import Testing
@testable import AppTemplate

struct LocalDatabaseServiceTests {
    @Test
    func invalidInputAndEmptyBatchDoNotInitializeStore() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        await expectValidation(.emptyID) {
            _ = try await service.fetchRecord(id: " \n")
        }
        await expectValidation(
            .invalidLimit(actual: 0, allowed: 1...200)
        ) {
            _ = try await service.fetchRecords(
                matching: ExampleQuery(limit: 0)
            )
        }
        try await service.upsert([])
        #expect(recorder.callCount == 0)
    }

    @Test
    func preCancellationPrecedesValidationAndInitialization() async {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        let result = await resultOfPreCancelledChildTask {
            try await service.fetchRecord(id: "")
        }

        guard case let .failure(error) = result else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 0)
    }

    @Test
    func validAndConcurrentCallsInitializeExactlyOnce() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { _ in
            try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(
            containerFactory: recorder.factory
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    try await service.upsert(
                        ExampleRecord(
                            id: "record-\(index)",
                            payload: "value-\(index)"
                        )
                    )
                }
            }
            try await group.waitForAll()
        }

        #expect(recorder.callCount == 1)
        #expect(
            try await service.fetchRecords(
                matching: ExampleQuery(limit: 200)
            ).count == 100
        )
    }

    @Test
    func factoryCancellationIsRetriedButOtherFailureIsCached() async throws {
        let cancelled = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 { throw CancellationError() }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let retryingService = LocalDatabaseService(
            containerFactory: cancelled.factory
        )
        await expectCancellation {
            _ = try await retryingService.fetchRecord(id: "record-1")
        }
        #expect(
            try await retryingService.fetchRecord(id: "record-1") == nil
        )
        #expect(cancelled.callCount == 2)

        let failed = LocalDatabaseContainerFactoryRecorder { _ in
            throw LocalDatabaseTestError.injectedFailure
        }
        let failedService = LocalDatabaseService(
            containerFactory: failed.factory
        )
        await expectInitializationFailure {
            _ = try await failedService.fetchRecord(id: "record-1")
        }
        await expectInitializationFailure {
            _ = try await failedService.fetchRecord(id: "record-2")
        }
        #expect(failed.callCount == 1)

        await expectValidation(.emptyID) {
            _ = try await failedService.fetchRecord(id: "")
        }
        try await failedService.upsert([])
        let preCancelled = await resultOfPreCancelledChildTask {
            try await failedService.fetchRecord(id: "record-3")
        }
        guard case let .failure(preCancelledError) = preCancelled else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(preCancelledError is CancellationError)
        #expect(failed.callCount == 1)
    }

    @Test
    func cancellationRaisedBySuccessfulFactoryIsObservedBeforeEngineWork() async throws {
        let recorder = LocalDatabaseContainerFactoryRecorder { invocation in
            if invocation == 1 {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            return try makeInMemoryLocalDatabaseContainer()
        }
        let service = LocalDatabaseService(containerFactory: recorder.factory)
        let first = Task { () -> Result<ExampleRecord?, any Error> in
            do {
                return .success(
                    try await service.fetchRecord(id: "record-1")
                )
            } catch {
                return .failure(error)
            }
        }

        guard case let .failure(error) = await first.value else {
            Issue.record("Expected CancellationError")
            return
        }
        #expect(error is CancellationError)
        #expect(recorder.callCount == 1)
        #expect(try await service.fetchRecord(id: "record-1") == nil)
        #expect(recorder.callCount == 2)
    }
}

private func expectValidation(
    _ expected: LocalDatabaseValidationError,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected LocalDatabaseError.validation")
    } catch let error as LocalDatabaseError {
        guard case let .validation(actual) = error else {
            Issue.record("Expected LocalDatabaseError.validation")
            return
        }
        #expect(actual == expected)
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}

private func expectCancellation(
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected CancellationError")
    } catch {
        #expect(error is CancellationError)
    }
}

private func expectInitializationFailure(
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected LocalDatabaseError.initialization")
    } catch let error as LocalDatabaseError {
        guard case .initialization = error else {
            Issue.record("Expected LocalDatabaseError.initialization")
            return
        }
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
}
```

Add the remaining boundary cases as parameterized tests in the same suite with these exact input/expectation pairs:

```swift
extension LocalDatabaseServiceTests {
@Test(arguments: [1, 200])
func inclusiveQueryLimitsInitializeAndSucceed(limit: Int) async throws {
    let recorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let service = LocalDatabaseService(containerFactory: recorder.factory)

    #expect(
        try await service.fetchRecords(
            matching: ExampleQuery(limit: limit)
        ).isEmpty
    )
    #expect(recorder.callCount == 1)
}

@Test(arguments: [0, 201])
func outOfRangeQueryLimitsFailBeforeInitialization(limit: Int) async {
    let recorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let service = LocalDatabaseService(containerFactory: recorder.factory)

    await expectValidation(
        .invalidLimit(actual: limit, allowed: 1...200)
    ) {
        _ = try await service.fetchRecords(
            matching: ExampleQuery(limit: limit)
        )
    }
    #expect(recorder.callCount == 0)
}

@Test(arguments: ["", " ", "\n\t"])
func blankIDsFailBeforeInitialization(id: String) async {
    let recorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let service = LocalDatabaseService(containerFactory: recorder.factory)

    await expectValidation(.emptyID) {
        _ = try await service.deleteRecord(id: id)
    }
    #expect(recorder.callCount == 0)
}

@Test
func batchOfFiveHundredSucceedsAndFiveHundredOneFailsBeforeInitialization() async throws {
    let validRecorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let validService = LocalDatabaseService(
        containerFactory: validRecorder.factory
    )
    let fiveHundred = (0..<500).map {
        ExampleRecord(id: "valid-\($0)", payload: "value")
    }
    try await validService.upsert(fiveHundred)
    #expect(validRecorder.callCount == 1)

    let invalidRecorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let invalidService = LocalDatabaseService(
        containerFactory: invalidRecorder.factory
    )
    let fiveHundredOne = (0..<501).map {
        ExampleRecord(id: "invalid-\($0)", payload: "value")
    }
    await expectValidation(
        .batchTooLarge(actual: 501, maximum: 500)
    ) {
        try await invalidService.upsert(fiveHundredOne)
    }
    #expect(invalidRecorder.callCount == 0)
}

@Test
func exactDuplicateBatchIDsFailButCaseDistinctIDsSucceed() async throws {
    let duplicateRecorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let duplicateService = LocalDatabaseService(
        containerFactory: duplicateRecorder.factory
    )
    await expectValidation(.duplicateID) {
        try await duplicateService.upsert([
            ExampleRecord(id: "same", payload: "one"),
            ExampleRecord(id: "same", payload: "two")
        ])
    }
    #expect(duplicateRecorder.callCount == 0)

    let distinctRecorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let distinctService = LocalDatabaseService(
        containerFactory: distinctRecorder.factory
    )
    try await distinctService.upsert([
        ExampleRecord(id: "same", payload: "one"),
        ExampleRecord(id: "SAME", payload: "two")
    ])
    #expect(distinctRecorder.callCount == 1)
}

@Test(arguments: LocalDatabasePreCancelledInvocation.allCases)
func everyPreCancelledPublicOperationSkipsInitialization(
    invocation: LocalDatabasePreCancelledInvocation
) async {
    let recorder = LocalDatabaseContainerFactoryRecorder { _ in
        try makeInMemoryLocalDatabaseContainer()
    }
    let service = LocalDatabaseService(containerFactory: recorder.factory)

    let result = await resultOfPreCancelledChildTask {
        try await invocation.invoke(on: service)
    }
    guard case let .failure(error) = result else {
        Issue.record("Expected CancellationError")
        return
    }
    #expect(error is CancellationError)
    #expect(recorder.callCount == 0)
}
}
```

The `LocalDatabasePreCancelledInvocation` implementation is already defined in Step 1. These cases assert literal factory counts and cover both inclusive bounds and their adjacent rejected values.

- [ ] **Step 3: Write persistence, composition, and isolation RED tests**

Create `LocalDatabasePersistenceTests.swift` with these exact integration tests:

```swift
import Testing
@testable import AppTemplate

struct LocalDatabasePersistenceTests {
    @Test
    func reopeningDiskStoreRetainsMutations() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        try await firstService?.upsert(
            ExampleRecord(id: "a", payload: "updated")
        )
        _ = try await firstService?.deleteRecord(id: "b")
        let detachedValue = try #require(
            try await firstService?.fetchRecord(id: "a")
        )
        firstService = nil
        #expect(releasedService == nil)
        #expect(detachedValue == ExampleRecord(id: "a", payload: "updated"))

        let reopened = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        #expect(
            try await reopened.fetchRecord(id: "a")
                == ExampleRecord(id: "a", payload: "updated")
        )
        #expect(try await reopened.fetchRecord(id: "b") == nil)
    }

    @Test
    func reopeningDiskStoreRetainsDeleteAll() async throws {
        let url = try uniqueLocalDatabaseStoreURL(label: "reopen-delete-all")
        var firstService: LocalDatabaseService? = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        weak let releasedService = firstService
        try await firstService?.upsert([
            ExampleRecord(id: "a", payload: "one"),
            ExampleRecord(id: "b", payload: "two")
        ])
        #expect(try await firstService?.deleteAllRecords() == 2)
        firstService = nil
        #expect(releasedService == nil)

        let reopened = LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.disk(url: url)
        )
        #expect(
            try await reopened.fetchRecords(
                matching: ExampleQuery(limit: 10)
            ).isEmpty
        )
    }
}
```

In `AppDependenciesTests.swift`, add:

```swift
@Test
func liveGraphDefersResolverUntilFirstValidDatabaseOperation() async {
    let calls = Mutex(0)
    let dependencies = AppDependencies.live(
        localDatabaseStoreLocationResolver: .init(resolve: {
            calls.withLock { $0 += 1 }
            throw LocalDatabaseTestError.injectedFailure
        })
    )

    #expect(calls.withLock { $0 } == 0)
    do {
        _ = try await dependencies.localDatabase.fetchRecord(id: "record-1")
        Issue.record("Expected initialization failure")
    } catch let error as LocalDatabaseError {
        guard case .initialization = error else {
            Issue.record("Expected LocalDatabaseError.initialization")
            return
        }
    } catch {
        Issue.record("Unexpected error type: \(type(of: error))")
    }
    #expect(calls.withLock { $0 } == 1)
}

@Test
func previewAndUITestingGraphsUseFreshDatabases() async throws {
    let settings = SettingsDependencies(
        appInfo: AppInfoService(displayName: "Preview", version: "1")
    )
    let firstPreview = AppDependencies.preview(settings: settings)
    let secondPreview = AppDependencies.preview(settings: settings)
    try await firstPreview.localDatabase.upsert(
        ExampleRecord(id: "preview", payload: "first")
    )
    #expect(
        try await secondPreview.localDatabase.fetchRecord(id: "preview")
            == nil
    )

    let state = AppState(
        isAuthenticated: true,
        hasCompletedOnboarding: true,
        isMaintenanceEnabled: false
    )
    let firstUI = AppDependencies.uiTesting(initialState: state)
    let secondUI = AppDependencies.uiTesting(initialState: state)
    try await firstUI.localDatabase.upsert(
        ExampleRecord(id: "ui", payload: "first")
    )
    #expect(
        try await secondUI.localDatabase.fetchRecord(id: "ui") == nil
    )
}
```

Import `Synchronization` in `AppDependenciesTests.swift`. Replace its empty private test actor with:

```swift
private actor InjectedLocalDatabaseService: ILocalDatabaseService {
    func fetchRecord(id: String) async throws -> ExampleRecord? { nil }

    func fetchRecords(
        matching query: ExampleQuery
    ) async throws -> [ExampleRecord] { [] }

    func upsert(_ record: ExampleRecord) async throws {}
    func upsert(_ records: [ExampleRecord]) async throws {}
    func deleteRecord(id: String) async throws -> Bool { false }
    func deleteAllRecords() async throws -> Int { 0 }
}
```

Keep the existing preview/test identity assertions unchanged.

- [ ] **Step 4: Run the facade/composition suites and verify RED**

```bash
set -euo pipefail
red_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task6-RED.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: exit 65 because the protocol, facade initializer/methods, and new `AppDependencies.live` parameter do not exist. No test may reach the real Application Support directory.

- [ ] **Step 5: Expand the public protocol**

Replace `ILocalDatabaseService.swift` with:

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

- [ ] **Step 6: Implement the lazy actor facade**

Replace `LocalDatabaseService.swift` with:

```swift
actor LocalDatabaseService: ILocalDatabaseService {
    private enum State {
        case uninitialized(LocalDatabaseContainerFactory)
        case ready(SwiftDataLocalStore)
        case failed(LocalDatabaseError)
    }

    private var state: State
    private let hooks: LocalDatabaseStoreHooks

    init(
        containerFactory: @escaping LocalDatabaseContainerFactory,
        hooks: LocalDatabaseStoreHooks = .production
    ) {
        state = .uninitialized(containerFactory)
        self.hooks = hooks
    }

    func fetchRecord(id: String) async throws -> ExampleRecord? {
        try Task.checkCancellation()
        try mapValidation { try LocalDatabaseValidator.validate(id: id) }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetchRecord(id: id)
    }

    func fetchRecords(
        matching query: ExampleQuery
    ) async throws -> [ExampleRecord] {
        try Task.checkCancellation()
        try mapValidation {
            try LocalDatabaseValidator.validate(query: query)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.fetchRecords(matching: query)
    }

    func upsert(_ record: ExampleRecord) async throws {
        try Task.checkCancellation()
        try mapValidation {
            try LocalDatabaseValidator.validate(record: record)
        }
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(record)
    }

    func upsert(_ records: [ExampleRecord]) async throws {
        try Task.checkCancellation()
        try mapValidation {
            try LocalDatabaseValidator.validate(records: records)
        }
        guard !records.isEmpty else { return }
        let store = try resolveStore()
        try Task.checkCancellation()
        try await store.upsert(records)
    }

    func deleteRecord(id: String) async throws -> Bool {
        try Task.checkCancellation()
        try mapValidation { try LocalDatabaseValidator.validate(id: id) }
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.deleteRecord(id: id)
    }

    func deleteAllRecords() async throws -> Int {
        try Task.checkCancellation()
        let store = try resolveStore()
        try Task.checkCancellation()
        return try await store.deleteAllRecords()
    }

    private func resolveStore() throws -> SwiftDataLocalStore {
        switch state {
        case let .ready(store):
            return store
        case let .failed(error):
            throw error
        case let .uninitialized(factory):
            do {
                let container = try factory()
                try Task.checkCancellation()
                let store = SwiftDataLocalStore(
                    modelContainer: container,
                    hooks: hooks
                )
                state = .ready(store)
                return store
            } catch let error as CancellationError {
                state = .uninitialized(factory)
                throw error
            } catch {
                LocalDatabaseDiagnostics.report(
                    operation: .initialization,
                    recordCount: 0,
                    error: error
                )
                let mapped = LocalDatabaseError.initialization(
                    underlying: error
                )
                state = .failed(mapped)
                throw mapped
            }
        }
    }

    private func mapValidation(
        _ operation: () throws -> Void
    ) throws {
        do {
            try operation()
        } catch let error as LocalDatabaseValidationError {
            throw LocalDatabaseError.validation(error)
        }
    }
}
```

The factory is synchronous and `state = .ready` happens before the first engine `await`; concurrent first calls therefore cannot duplicate initialization. Do not add a zero-argument initializer.

- [ ] **Step 7: Compose live disk and isolated in-memory graphs**

Change only the LocalDatabase construction points in `AppDependencies.swift`:

```swift
static func live(
    localDatabaseStoreLocationResolver:
        LocalDatabaseStoreLocationResolver = .live()
) -> AppDependencies {
    AppDependencies(
        localDatabase: LocalDatabaseService(
            containerFactory: LocalDatabaseContainerFactories.live(
                locationResolver: localDatabaseStoreLocationResolver
            )
        ),
        remote: RemoteService(),
        appStateStorage: UserDefaultsAppStateStorage(),
        settings: SettingsDependencies(appInfo: AppInfoService())
    )
}
```

In `uiTesting(initialState:)`, construct:

```swift
localDatabase: LocalDatabaseService(
    containerFactory: LocalDatabaseContainerFactories.inMemory()
),
```

Change the preview default to:

```swift
localDatabaseService: any ILocalDatabaseService = LocalDatabaseService(
    containerFactory: LocalDatabaseContainerFactories.inMemory()
),
```

Leave `AppDependencies.test(...)`, `AppTemplateApp`, `AppStateStore`, remote composition, and settings composition unchanged.

- [ ] **Step 8: Run focused GREEN**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-SwiftData-Task6-GREEN.XXXXXX)"
test -d "$green_root"
test ! -L "$green_root"

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Task6.xcresult" \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcrun xcresulttool get test-results summary \
  --path "$green_root/Task6.xcresult" --compact \
| jq -e '.result == "Passed"
    and .totalTestCount > 0
    and .failedTests == 0
    and .skippedTests == 0
    and .expectedFailures == 0
    and .passedTests == .totalTestCount'
```

Expected: all selected suites pass, including the real read-only save-failure recovery test, exactly-once lazy initialization, 100 concurrent writes, disk reopen, and graph isolation.

- [ ] **Step 9: Self-review and commit Task 6**

```bash
git diff --check
git add \
  AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift \
  AppTemplate/App/AppDependencies/AppDependencies.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift \
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift \
  AppTemplateTests/App/Composition/AppDependenciesTests.swift \
  AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift
git diff --cached --check
git commit -m "feat: compose SwiftData local service"
```

---

### Task 7: Document the Reference Store and Run the Complete Acceptance Matrix

**Files:**

- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`
- Verify only: every implementation and test file listed in the File Map

**Interfaces:**

- Consumes: the completed public behavior and verified implementation from Tasks 1–6.
- Produces: accurate user-facing boundaries, a release checklist for persistence/migration decisions, a closed scope audit, and nine retained local verification artifacts.

- [ ] **Step 1: Update the README contract**

Replace the opening capability paragraph with this text:

```markdown
AppTemplate is a SwiftUI application template for iOS, iPadOS, and macOS. It
provides typed scene-local navigation, persisted demo app policy, explicit
dependency injection, deep links, previews, unit and UI tests, a hardened
network layer, and a local-only SwiftData reference store for `ExampleRecord`.
Platform verification is performed locally.
```

Replace the persistence portion of `## Scope` with:

```markdown
The template includes an intentionally small SwiftData reference store for the
sample `ExampleRecord` value. It demonstrates a Sendable service facade, an
internal ModelActor, explicit schema versioning, lazy disk bootstrap, isolated
in-memory preview/UI-test composition, bounded reads, explicit saves, and
failure-safe operation contexts. It does not choose product entities, a
feature-specific repository contract, retention policy, backup policy,
application-level encryption, CloudKit synchronization, App Group sharing, or
cross-process access. Replace the sample boundary deliberately when adding a
real feature; do not encode unrelated domain data into `payload` merely to
reuse it.

`AppStateStore` remains a separate UserDefaults-backed launch-policy store. It
is not migrated to SwiftData by this reference implementation.
```

- [ ] **Step 2: Replace the local-service section in architecture docs**

Under `## Application state and root policy` in `docs/ARCHITECTURE.md`, add:

```markdown
This launch-policy state remains owned by `AppStateStore` and
`IAppStateStorage` in UserDefaults. The local SwiftData reference store does not
participate in root selection or startup restoration.
```

Under `## Dependency injection and services`, replace the empty LocalDatabase scaffold wording with:

```markdown
### Local SwiftData reference store

`ILocalDatabaseService` is a Sendable, `ExampleRecord`-specific value API.
`LocalDatabaseService` is an actor facade that performs cancellation and pure
validation before lazily creating a `ModelContainer`. It caches successful
bootstrap and non-cancellation bootstrap failures without erasing the store or
falling back to memory.

`SwiftDataLocalStore` is the internal ModelActor. SwiftData entities and
`ModelContext` instances never leave it. Each synchronous engine operation uses
a fresh private context with autosave disabled; a state-changing operation
saves once, a documented no-op saves zero times, and a failed operation rolls
back and discards its context so stale registered models cannot leak into the
next call. Returned `ExampleRecord` values remain usable independently of the
service and container.

The live store is resolved lazily at
`Application Support/<bundle identifier>/LocalDatabase.store`. Preview and UI
test graphs each create a fresh in-memory container. Schema V1 contains only
the internal stored-example entity, and the migration plan intentionally has no
stages because no earlier schema shipped. CloudKit is explicitly disabled.

The failure contract distinguishes validation, initialization (including
migration/container load), read, and public write-operation failures.
Diagnostics expose only operation, fixed entity type, record count, NSError
domain, and NSError code. They never include IDs, payloads, search text, error
descriptions, userInfo, store contents, or user-specific paths.

This is a reference store, not a generic repository and not product feature
storage. A real feature should define a semantic protocol over its domain
values, adapt or replace this sample internally, and inject that feature
protocol into its ViewModel.
```

- [ ] **Step 3: Add exact customization guidance**

In `docs/CUSTOMIZATION.md`, split the service guidance into `### Local SwiftData reference store` and `### Remote service`. Put this checklist under the local heading:

```markdown
Before shipping product data:

1. Replace `ExampleRecord` and `ILocalDatabaseService` with feature-semantic
   values and operations; do not use `payload` as an untyped domain envelope.
2. Keep SwiftData entities, contexts, containers, predicates, and identifiers
   behind the persistence implementation. ViewModels receive a feature
   protocol, never SwiftData or `AppDependencies`.
3. Keep the live URL stable at
   `Application Support/<bundle identifier>/LocalDatabase.store`, or design and
   test an explicit move before changing it.
4. Retain every shipped `VersionedSchema`. Add a real migration stage only when
   a transition exists, and verify that transition with a disk fixture created
   from the earlier schema.
5. Decide retention, user-visible deletion, backup/restore, import/export, and
   recovery from initialization or migration failure. Never silently erase or
   replace an unreadable store with memory.
6. Decide separately whether CloudKit, App Groups, cross-process access, or
   application-level encryption is required. The template configures
   `cloudKitDatabase: .none` and provides none of those guarantees.
7. Preserve explicit-save tests, documented no-op tests, deterministic failure
   and cancellation tests, and reopen tests for the final feature contract.
8. Keep `AppStateStore` in UserDefaults unless an independently designed
   asynchronous startup and migration flow replaces it.
```

Retain the existing remote-service customization content verbatim under `### Remote service`.

- [ ] **Step 4: Update the release checklist**

In `docs/RELEASE_CHECKLIST.md` under `## Behavior, tests, and migration`, replace the empty-scaffold item and add these exact items:

```markdown
- [ ] Replace or explicitly accept the sample-only `ExampleRecord` SwiftData
  contract; confirm no product domain is hidden in its payload string.
- [ ] Reopen a temporary disk store in a second container and verify inserts,
  updates, single deletion, and bulk deletion.
- [ ] For every schema after V1, retain the prior schema and pass disk-backed
  transition fixtures. V1 has no fake predecessor or migration stage.
- [ ] Exercise initialization and migration failure recovery without automatic
  erase, retry loops, or in-memory fallback.
- [ ] Confirm retention, deletion, backup/restore, and corrupted-store support
  policy for product data.
- [ ] Confirm explicit decisions for CloudKit/sync, App Groups/cross-process
  access, and application-level encryption; the template enables none.
- [ ] Run unit-test bundles locally on macOS, iPhone 17 / iOS 26.5, and iPad
  (A16) / iOS 26.5 with Swift and Clang warnings treated as errors.
- [ ] Run the complete macOS scheme and the full UI-test bundle on both listed
  iOS simulator destinations with zero failures, skips, or expected failures.
- [ ] Build Release for generic macOS and unsigned generic iOS with warnings
  treated as errors; perform distribution signing/archive checks separately.
```

Keep the existing privacy, macOS entitlement, signing, archive, and distribution checks unchanged.

- [ ] **Step 5: Run documentation and implementation scope guards**

```bash
set -euo pipefail

base="$(git merge-base HEAD main)"
test -n "$base"

changed_paths="$({
  git diff --name-only "$base"...HEAD
  git diff HEAD --name-only
  git ls-files --others --exclude-standard
} | sed '/^$/d' | LC_ALL=C sort -u)"

allowed_paths=(
  README.md
  docs/ARCHITECTURE.md
  docs/CUSTOMIZATION.md
  docs/RELEASE_CHECKLIST.md
  docs/superpowers/plans/2026-08-10-swiftdata-local-service.md
  docs/superpowers/specs/2026-08-10-swiftdata-local-service-design.md
  AppTemplate/App/AppDependencies/AppDependencies.swift
  AppTemplate/App/Models/Local/ExampleQuery.swift
  AppTemplate/App/Services/LocalDatabase/ILocalDatabaseService.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseError.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseSchema.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseService.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreConfiguration.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseStoreHooks.swift
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseValidator.swift
  AppTemplate/App/Services/LocalDatabase/SwiftDataLocalStore.swift
  AppTemplateTests/App/Composition/AppDependenciesTests.swift
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseContractTests.swift
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabasePersistenceTests.swift
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseServiceTests.swift
  AppTemplateTests/App/Services/LocalDatabase/LocalDatabaseStoreConfigurationTests.swift
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreBatchTests.swift
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreMutationTests.swift
  AppTemplateTests/App/Services/LocalDatabase/SwiftDataLocalStoreQueryTests.swift
  AppTemplateTests/TestSupport/LocalDatabase/LocalDatabaseTestSupport.swift
)

for path in "${allowed_paths[@]}"; do
  test -f "$path"
done

unexpected_paths="$(
  comm -23 \
    <(printf '%s\n' "$changed_paths" | sed '/^$/d' | LC_ALL=C sort -u) \
    <(printf '%s\n' "${allowed_paths[@]}" | LC_ALL=C sort -u)
)"
if test -n "$unexpected_paths"; then
  printf 'Unexpected implementation paths:\n%s\n' "$unexpected_paths" >&2
  exit 1
fi

test -z "$(git diff --name-only "$base" -- \
  AppTemplate/App/Models/Local/ExampleRecord.swift \
  AppTemplate/App/Entry/AppTemplateApp.swift \
  AppTemplate/Features \
  AppTemplate/App/ApplicationState \
  AppTemplate/App/Navigation \
  AppTemplateUITests \
  AppTemplate.xcodeproj/project.pbxproj \
  AppTemplate.xcodeproj/xcshareddata \
  Config \
  .github)"

if rg -n '@Query' AppTemplate AppTemplateTests; then exit 1; fi
if rg -l 'import SwiftData|ModelContext|ModelContainer|PersistentModel|PersistentIdentifier' \
  AppTemplate/App --glob '*.swift' \
  | rg -v '^AppTemplate/App/Services/LocalDatabase/'; then
  exit 1
fi
if rg -n 'ILocalDatabaseService|LocalDatabaseService|ExampleRecord' \
  AppTemplate/Features; then exit 1; fi
if rg -n 'fatalError|try[!?]|deleteAllData\(' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi
if rg --pcre2 -n 'localizedDescription|userInfo|storeURL|\bExample(Record|Query)\b|payload|searchText' \
  AppTemplate/App/Services/LocalDatabase/LocalDatabaseDiagnostics.swift; then
  exit 1
fi
if rg --pcre2 -n 'cloudKitDatabase:\s*\.(?!none)|groupContainer:\s*\.(?!none)' \
  AppTemplate/App/Services/LocalDatabase --glob '*.swift'; then
  exit 1
fi

git diff --check
```

Expected: every guard exits zero. The only SwiftData app imports/types are within the production LocalDatabase tree; no forbidden product/UI/project/automation path changed.

- [ ] **Step 6: Run the complete nine-gate local matrix**

Run this script from the worktree root exactly once; keep the printed temporary root and every result bundle for review:

```bash
set -euo pipefail

verification_root="$(mktemp -d /tmp/AppTemplate-SwiftData-final.XXXXXX)"
test -n "$verification_root"
test -d "$verification_root"
test ! -L "$verification_root"
case "$verification_root" in
  /tmp/AppTemplate-SwiftData-final.*) ;;
  *) exit 1 ;;
esac

gate_names=(
  focused-macOS
  units-macOS
  units-iPhone17
  units-iPadA16
  scheme-macOS
  ui-iPhone17
  ui-iPadA16
  release-macOS
  release-iOS
)

for gate_name in "${gate_names[@]}"; do
  test ! -e "$verification_root/DerivedData-$gate_name"
  test ! -e "$verification_root/$gate_name.xcresult"
done

assert_test_bundle() {
  local result_bundle="$1"
  test -d "$result_bundle"
  xcrun xcresulttool get test-results summary \
    --path "$result_bundle" --compact \
  | jq -e '
      .result == "Passed"
      and .totalTestCount > 0
      and .failedTests == 0
      and .skippedTests == 0
      and .expectedFailures == 0
      and .passedTests == .totalTestCount
    '
}

run_test_gate() {
  local gate_name="$1"
  local destination="$2"
  shift 2
  local derived_data="$verification_root/DerivedData-$gate_name"
  local result_bundle="$verification_root/$gate_name.xcresult"

  xcodebuild test \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
  assert_test_bundle "$result_bundle"
}

run_build_gate() {
  local gate_name="$1"
  local destination="$2"
  shift 2
  local derived_data="$verification_root/DerivedData-$gate_name"
  local result_bundle="$verification_root/$gate_name.xcresult"

  xcodebuild build \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration Release \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    "$@" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
  test -d "$result_bundle"
}

run_test_gate focused-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests/LocalDatabaseContractTests \
  -only-testing:AppTemplateTests/LocalDatabaseStoreConfigurationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreMutationTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreBatchTests \
  -only-testing:AppTemplateTests/SwiftDataLocalStoreQueryTests \
  -only-testing:AppTemplateTests/LocalDatabaseServiceTests \
  -only-testing:AppTemplateTests/LocalDatabasePersistenceTests \
  -only-testing:AppTemplateTests/AppDependenciesTests \
  -only-testing:AppTemplateTests/ExampleLocalModelTests

run_test_gate units-macOS 'platform=macOS' \
  -only-testing:AppTemplateTests
run_test_gate units-iPhone17 \
  'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -only-testing:AppTemplateTests
run_test_gate units-iPadA16 \
  'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -only-testing:AppTemplateTests
run_test_gate scheme-macOS 'platform=macOS'
run_test_gate ui-iPhone17 \
  'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -only-testing:AppTemplateUITests
run_test_gate ui-iPadA16 \
  'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -only-testing:AppTemplateUITests
run_build_gate release-macOS 'generic/platform=macOS'
run_build_gate release-iOS 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO

printf '%s\n' "$verification_root"
```

Expected: all nine `xcodebuild` invocations exit zero. Every test xcresult is `Passed`, has a positive test count, and has zero failed, skipped, or expected-failure tests. Do not disable signing for simulator/UI gates or macOS Release; only generic iOS Release uses `CODE_SIGNING_ALLOWED=NO`.

- [ ] **Step 7: Run final invariant scans and commit documentation**

```bash
set -euo pipefail

test "$(rg -n '^### Task [1-7]:' \
  docs/superpowers/plans/2026-08-10-swiftdata-local-service.md \
  | wc -l | tr -d ' ')" = 7

placeholder_pattern='TO''DO|TB''D|implement la''ter|fill in de''tails|similar to ta''sk|same as ta''sk'
if rg -n -i "$placeholder_pattern" \
  README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md \
  docs/superpowers/specs/2026-08-10-swiftdata-local-service-design.md \
  docs/superpowers/plans/2026-08-10-swiftdata-local-service.md; then
  exit 1
fi

git diff --check
git add \
  README.md \
  docs/ARCHITECTURE.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md
git diff --cached --check
git commit -m "docs: explain SwiftData local storage"
git status --short
```

Expected: the task-count and placeholder scans pass, the documentation commit succeeds, and `git status --short` is empty. Do not create a cleanup commit after the acceptance matrix; any implementation change requires rerunning the affected focused gate and the complete Task 7 matrix.

---

## Plan Self-Review Checklist

- [x] Spec coverage: map every design principle, public method, validation rule, query rule, save/no-op rule, failure category, cancellation checkpoint, composition rule, diagnostic restriction, documentation obligation, and acceptance gate to Tasks 1–7.
- [x] Rollback evidence: keep the real `allowsSave: false` regression test. Confirm the failed context is discarded and the next same-engine operation uses a new context; never weaken this to a hook-only failure test.
- [x] Type consistency: verify `LocalDatabaseContainerFactories.live`, `.disk`, `.inMemory`, `LocalDatabaseStoreLocationResolver.live`, all operation enum cases, six protocol methods, and suite selectors use identical spelling throughout the plan.
- [x] Placeholder scan: reject every prohibited placeholder phrase from the writing-plans skill and any step that refers to an unstated command or undefined type.
- [x] TDD shape: every task has an observable RED, minimal GREEN implementation, warnings-as-errors focused gate with positive xcresult count, self-review, and one commit.
- [x] Scope: confirm no edit to `ExampleRecord`, `AppTemplateApp`, features, application state, navigation, UI tests, Xcode project/scheme, packages, config, entitlements, privacy manifest, or hosted automation.
