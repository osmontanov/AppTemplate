# AppTemplate — guide for AI agents and new contributors

AppTemplate is a **reference template** for iOS/macOS SwiftUI apps (Swift 6, default
MainActor isolation). It ships with a fully working example — a "connected mini store"
backed by the public DummyJSON API — plus seven "service labs" that demonstrate every
infrastructure service. Read `docs/ARCHITECTURE.md` for the layer map and
`docs/CUSTOMIZATION.md` for the adoption order before changing anything.

## Framework vs example vs labs

| Part | Status when building a new app from this template |
|---|---|
| `AppTemplate/App/**` (Entry, AppDependencies, Networking, Services, Repositories/Session, Navigation, Session, ApplicationState, Models/Session+State, Utilities) | **Framework — keep.** Adapt names/endpoints, preserve structure and patterns |
| `AppTemplate/Features/Store/**`, `App/Repositories/{Products,Store}`, `App/Models/{Domain,Remote,Store}`, `App/Services/Remote` (DummyJSON) | **Example — replace** with your product's features; copy the patterns, not the store |
| `AppTemplate/Features/Services/**` (labs) | **Optional teaching content — delete or keep** |
| `Features/Onboarding`, `Features/Maintenance`, `Features/Authentication` | Framework skeletons — adapt content, keep the flow wiring |
| `AppTemplateTests/Project/*`, `Scripts/*` | **Framework — keep.** The gate itself is product-agnostic; only the rows inside `Scripts/release-required-*.tsv` name this example's tests, so swap those rows (and rerun the checksum script) as your suites replace them |

## Non-negotiable conventions

- **DI:** constructor injection only, no container. `AppDependencies` is the single
  composition root with four factories (`live` / `uiTesting` / `preview` / `test`).
  Production impl has no suffix; doubles are `InMemory*` / `FailClosed*` /
  `Scripted*`; UI-test decorators are `UITest*`.
- **Protocol names:** `I*` marks a contract handed through a dependency container
  (`IKeychainService`, `ICartRepository`, `ISessionActions`). Everything else keeps
  its bare name: conformance contracts a value type adopts (`LocalDatabaseModel`,
  `NavigationRoute`, `NetworkTarget`) and seams internal to one subsystem
  (`NetworkTransport`, `ImageHTTPTransport`, `LocalNotificationCenterClient`).
  Within either group, follow Swift's own rule — a noun for what a thing *is*
  (`IProductRepository`), `-ing`/`-able` for a capability (`IAppStateInspecting`,
  `KeychainSecItemExecuting`).
- **Screen module:** `Screens/<Name>/{Model,State,ViewModel,View,Navigation}` —
  every screen in `Features/**`, labs included, no flat files beside the folders.
  `Model` — `Equatable Sendable` value; `State` — finite-state enum;
  `ViewModel` — `@MainActor @Observable final class` with `private(set)` state;
  `View` creates its VM in `init` via `_vm = State(initialValue:)`. Create a
  subfolder only when it has real content — no empty placeholder types.
- **Concurrency:** targets build with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
  Every value type and protocol is explicitly `nonisolated` + `Sendable`.
  Stateful services are `actor`s. `@unchecked Sendable` requires a `Mutex`/`NSLock`
  and a justification comment. Races are handled with generation counters
  (recheck after every `await`), monotonic revisions, and `AsyncOperationGate` —
  never ad-hoc locking in async code.
- **Time:** always through an injected `AppClock` (`now`/`monotonicNow`/`sleep`).
  Never call `Date()`/`Task.sleep` directly in logic.
- **Errors:** typed `Equatable Sendable` enums per layer. Session-layer operations
  return result enums instead of throwing. `CancellationError` is never wrapped and
  is always handled as its own case (roll back, don't publish an error).
- **Persistence:** everything durable carries a `schemaVersion`; decode via an
  envelope peek; migrate with write-back; never overwrite data from a future schema;
  degrade to an observable read-only/repair state instead of crashing.
- **Validation at boundaries:** hardened `Codable` (`rejectUnknownKeys`) for
  anything read back from the OS or disk (routes, snapshots, notification
  envelopes); allowlists and magic-byte checks for remote bytes.
- **Accessibility & localization:** every screen/action/result gets a stable
  identifier through `AppAccessibilityIdentifier` (the catalog is frozen by
  `AccessibilityIdentifierTests`); user-facing strings go through `AppText` into
  the `AppText` table only. Pass the English text itself as the key
  (`AppText.string("Sign in")`); use the explicit-key overload
  (`AppText.string("services.keychain.revealedValue", defaultValue: "\(a): \(b)")`)
  only when interpolation would make different strings collide on one format key.
- **Comments:** the codebase is intentionally comment-free; add a comment only for
  a non-obvious constraint the code cannot express.

## Testing

- Unit tests: Swift Testing (`@Test`, `#expect`), app-hosted, mirrored structure
  (`AppTemplateTests/App/...` mirrors `AppTemplate/App/...`). Every behavioral
  change ships with a test. Doubles implement the same `I*` protocols production
  uses; deterministic races are built from continuation barriers, not sleeps.
- UI tests: XCTest + Robot pattern. Journeys contain no selectors — only robots do.
  The app under UI test runs fully scripted (network, images, notifications,
  frozen clock); scripts signal completion through
  `ui-test.script-status.{pending|exhausted|failed}`.
- `XCResultRequiredTestsVerifierTests` needs binaries compiled by
  `Scripts/verify-release.zsh`; without them the suite skips
  itself. The release gate is the canonical full check.

## Frozen contracts — read before touching

These are deliberately frozen and break loudly when edited in one place only:

1. **Manifest hashes.** `Scripts/release-manifest-checksums.tsv` is the single
   source: `Scripts/verify-release.zsh` refuses to run when a required-tests
   manifest no longer matches its recorded hash, and `ProjectConfigurationTests`
   fails when that file is itself stale. After editing a manifest run
   `Scripts/update-release-manifest-checksums.zsh` — never hand-edit a hash.
2. **Accessibility identifier catalog** — `AccessibilityIdentifierTests`.
3. **Wire formats** — route tags, navigation snapshot schema (v5), notification
   envelope (v1), stored session envelope (v1).
4. **Localization producers** — the regexp manifest in
   `AppTextLocalizationTests` lists every file allowed to produce visible text.

## Checklists

**Add a screen:** create `Screens/<Name>/` with only the needed subfolders → route
case in the feature's `*Route` (hardened Codable) → destination mapping in the
feature's `*FlowView` → accessibility identifiers → mirrored tests (+ journey robot
step if it's on a golden path).

**Add a service:** protocol `I<Name>Service` + production impl (+`InMemory*` double
if stateful) under `App/Services/<Name>/` → add the stored property and a
`compose` parameter in `AppDependencies`, then pass it from every factory (both
steps are compile errors until done) → mirrored tests → if user-facing, consider a
lab screen.

**Schema migration (SwiftData):** add `LocalDatabaseSchemaV<N+1>` + a
`MigrationStage` in `LocalDatabaseMigrationPlan` → keep old `Stored*` classes in the
old schema enum → migration test proving old data survives.

**Make a test required for release:** add its row (`platform<TAB>Suite/test()`,
rows kept `LC_ALL=C` sorted) to `Scripts/release-required-unit-tests.tsv` or
`Scripts/release-required-ui-tests.tsv` → run
`Scripts/update-release-manifest-checksums.zsh`.

**Rename the template:** `Config/Template.xcconfig` (`APP_BUNDLE_IDENTIFIER`,
`APP_URL_SCHEME`, `APP_DEVELOPMENT_TEAM`) → the `apptemplate` URL scheme constant in
`DeepLinkParser`/`AppNotificationIdentifiers` → `"AppTemplate"` namespaces
(UserDefaults, Keychain service, notification namespace, `@SceneStorage` key) →
`AppInfoService` fallbacks.

## Known intentional gaps

- `AppTemplate/Resources/PrivacyInfo.xcprivacy` declares what *this* code does:
  no tracking, no collected data, and required-reason entries for UserDefaults
  (CA92.1) and the file timestamps the attachment stager reads (C617.1). Revisit
  every entry for your own product and its SDKs before submitting.
- String extraction is off (`SWIFT_EMIT_LOC_STRINGS = NO`): the catalogs are
  maintained by hand, because the extractor cannot see the table `AppText` passes
  and would refill `Localizable.xcstrings` with a duplicate of every key.
- The remote layer names its backend in exactly one value, `RemoteOrigin.dummyJSON`,
  and `RemoteService` rejects any base URL that origin does not permit. Pointing at
  another host is an injected `RemoteOrigin`; the paths and payloads still belong to
  `DummyJSONTarget`, so a real backend swap replaces that target.
- The image pipeline is deliberately fail-closed and memory-cache-only
  (`CachingImageLoader` over `ProductImageLoader`); add disk caching consciously.
