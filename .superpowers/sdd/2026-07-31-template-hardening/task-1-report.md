# Task 1 — Safe Application-State Persistence Boundary

## What changed

- Moved application-state production and test files into the requested
  `ApplicationState` hierarchy using filesystem moves; old state service/test
  directories are absent.
- Made `IAppStateStorage` operations throwing and added the required typed
  persistence failure, status, and mutation-result contracts.
- Hardened `AppStateStore`: it writes before committing in-memory state,
  rejects mutations after any persistence failure, preserves future-schema
  bytes without repair, and uses read-only initial state for failed loads.
- Kept repair behavior for invalid, corrupt, and legacy schemas; an encoding or
  save failure during repair makes the store read-only.
- Added lock-protected `InMemoryAppStateStorage`, including data and state
  fixture initializers, and made the preview dependency graph use it by
  default.
- Updated the flow coordinator to regard only `.persisted` as a state change.

## Files changed

- `AppTemplate/App/ApplicationState/` (moved state, store, diagnostics, and
  persistence boundary; added `Persistence/InMemoryAppStateStorage.swift`)
- `AppTemplate/App/AppDependencies/AppDependencies.swift`
- `AppTemplate/App/Navigation/Routing/AppFlowCoordinator.swift`
- `AppTemplateTests/App/ApplicationState/` (moved/extended store and
  UserDefaults tests; added in-memory tests and relocated storage spy)
- `AppTemplateTests/App/Composition/AppDependenciesTests.swift`

## RED evidence

1. Command:
   ```bash
   xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
     -destination 'platform=macOS' \
     -only-testing:AppTemplateTests/AppStateStoreTests
   ```
   Result: expected failure. The compiler reported the missing throwing storage
   conformance, missing `persistenceStatus`, missing typed mutation results,
   and missing `encode` initializer dependency. This proves the new
   future-schema and failure-ordering tests required production changes.

2. Command:
   ```bash
   xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
     -destination 'platform=macOS' \
     -only-testing:AppTemplateTests/InMemoryAppStateStorageTests
   ```
   Result: expected failure. The compiler reported
   `cannot find 'InMemoryAppStateStorage' in scope` for each deterministic
   storage test, proving the adapter did not exist.

3. Command:
   ```bash
   xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
     -destination 'platform=macOS' \
     -only-testing:AppTemplateTests/AppDependenciesTests/previewGraphUsesInMemoryStateStorageByDefault
   ```
   Result: expected failure: missing required `appStateStorage` argument to
   `AppDependencies.preview()`, proving the preview default was absent.

## GREEN and verification evidence

- Focused store GREEN: the first RED command above, rerun after implementation,
  exited 0 with all `AppStateStoreTests` passing.
- Focused in-memory GREEN: the second RED command, rerun after implementation,
  exited 0 with all five `InMemoryAppStateStorageTests` passing.
- Focused DI GREEN:
  ```bash
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination 'platform=macOS' \
    -only-testing:AppTemplateTests/AppDependenciesTests
  ```
  exited 0 with all four dependency tests passing.
- Required affected suite:
  ```bash
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination 'platform=macOS' \
    -only-testing:AppTemplateTests/AppStateStoreTests \
    -only-testing:AppTemplateTests/UserDefaultsAppStateStorageTests \
    -only-testing:AppTemplateTests/InMemoryAppStateStorageTests \
    -only-testing:AppTemplateTests/AppFlowCoordinatorTests
  ```
  exited 0; all selected tests passed.
- Full suite:
  ```bash
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination 'platform=macOS,arch=arm64'
  ```
  exited 0 with `** TEST SUCCEEDED **`; no compiler warnings were emitted.

## Self-review

- Confirmed the public persistence interfaces exactly match the brief,
  including nonisolated declarations and typed failures/results.
- Confirmed all persistence access in the in-memory adapter and test spy is
  lock protected.
- Confirmed future schemas do not write/remove or log payload/error contents;
  `setState` saves before changing `state`.
- Confirmed deployment targets remain 26.0 and approachable concurrency plus
  default MainActor settings remain enabled.
- Ran `git diff --check`: no whitespace errors.

## Concerns

None. The test commands using an unspecified macOS architecture print Xcode's
standard multiple-destination selection notice; the final full-suite command
specified `arch=arm64` and had no warnings.
