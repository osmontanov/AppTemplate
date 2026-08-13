# Connected Mini Store Implementation Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the disconnected examples with one coherent Store and a complete Services playground while keeping every intermediate commit compilable and testable.

**Architecture:** Build bottom-up through eight ordered phase plans. Security and deterministic test seams land first, persistence and session semantics land before their UI consumers, typed Store/Services navigation lands before protected actions, and notification integration lands before the full Services lab. Existing examples stay available until the replacement acceptance gate passes in phase 8.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, SwiftData, Security, UserNotifications, Swift Testing, XCTest, XCUITest, Xcode String Catalogs

**Normative design:** [`2026-08-13-connected-mini-store-design.md`](../specs/2026-08-13-connected-mini-store-design.md)

## Global Constraints

- Execute phases in order. A phase consumes only committed interfaces from an earlier phase.
- Follow test-driven development inside every task: RED, confirm the expected failure, implement the smallest production change, GREEN, then commit.
- Every task-level commit must compile. Do not leave a renamed shared type with unmodified call sites for a later commit.
- New source files are discovered through the synchronized Xcode groups. Do not modify `AppTemplate.xcodeproj/project.pbxproj` for file membership.
- Preserve the existing unrelated working-tree changes in `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, and `graphify-out/`.
- Do not remove legacy Home, Browse, Projects, or Settings sources until phase 8 proves that Store and Services replace them.
- Automated tests and previews are offline. An unknown UI-test scenario or an unscripted request fails closed.
- Every scripted XCUITest finishes by asserting the launched app's phase-1 `ui-test.script-status.exhausted` marker; pending, failed, or timeout is a test failure.
- `AppDependencies` owns app-scoped actors. Views and feature ViewModels receive narrow semantic dependency slices.
- Scene navigation is local to a window. Session, AppState policy, persistence repositories, notification categories, and notification response dispatch are app-scoped.
- Tokens, passwords, raw Keychain values, notification note text, arbitrary metadata, response bodies, and unredacted errors never enter diagnostics or replay history.

### Protected working-copy baseline (run once before Phase 1)

The existing project-file, String Catalog, and `graphify-out/` changes belong to the user. Before the first RED command, capture their exact bytes outside the worktree; do not wait until phase 8, because later drift must never become the accepted baseline:

```bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
[[ -n "$repo_root" && "$(pwd -P)" == "$repo_root" ]] || exit 64
git_common_dir="$(git rev-parse --git-common-dir)"
[[ "$git_common_dir" == /* ]] || git_common_dir="$repo_root/$git_common_dir"
baseline_dir="$git_common_dir/codex-connected-mini-store-baseline"
[[ "$baseline_dir" == "$git_common_dir/"* ]] || exit 64
[[ ! -e "$baseline_dir" && ! -L "$baseline_dir" ]] || exit 65
umask 077
staging_dir="$(mktemp -d "$git_common_dir/codex-connected-mini-store-baseline.tmp.XXXXXX")"
[[ -d "$staging_dir" && ! -L "$staging_dir" ]] || exit 65
test -f AppTemplate.xcodeproj/project.pbxproj && test ! -L AppTemplate.xcodeproj/project.pbxproj
test -f AppTemplate/Resources/Localizable.xcstrings && test ! -L AppTemplate/Resources/Localizable.xcstrings
test -d graphify-out && test ! -L graphify-out
shasum -a 256 AppTemplate.xcodeproj/project.pbxproj AppTemplate/Resources/Localizable.xcstrings > "$staging_dir/protected.sha256"
cp -p AppTemplate.xcodeproj/project.pbxproj "$staging_dir/project.pbxproj.copy"
cp -p AppTemplate/Resources/Localizable.xcstrings "$staging_dir/Localizable.xcstrings.copy"
find graphify-out -type f -exec shasum -a 256 {} + | LC_ALL=C sort > "$staging_dir/graphify.sha256"
find graphify-out -print | LC_ALL=C sort > "$staging_dir/graphify.paths"
find graphify-out -type l -print > "$staging_dir/graphify.symlinks"
test ! -s "$staging_dir/graphify.symlinks"
tar -cpf "$staging_dir/graphify-out.tar" graphify-out
test -s "$staging_dir/protected.sha256"
test -s "$staging_dir/graphify.paths"
test -s "$staging_dir/graphify-out.tar"
cmp AppTemplate.xcodeproj/project.pbxproj "$staging_dir/project.pbxproj.copy"
cmp AppTemplate/Resources/Localizable.xcstrings "$staging_dir/Localizable.xcstrings.copy"
tar -tf "$staging_dir/graphify-out.tar" >/dev/null
mkdir "$baseline_dir"
for name in protected.sha256 graphify.sha256 graphify.paths graphify.symlinks project.pbxproj.copy Localizable.xcstrings.copy graphify-out.tar; do
  test -f "$staging_dir/$name" && test ! -L "$staging_dir/$name"
  mv "$staging_dir/$name" "$baseline_dir/$name"
done
test -s "$baseline_dir/protected.sha256" && test -s "$baseline_dir/graphify.paths" && test -s "$baseline_dir/graphify-out.tar"
rmdir "$staging_dir"
```

The two `.copy` files and `graphify-out.tar` are recovery material containing the exact protected bytes; the hash/path/no-symlink manifests are immutable verification fingerprints. After every task GREEN and again immediately before every `git add`, recompute into fresh `mktemp` files under the same validated baseline directory and compare all four manifests with `cmp`; also `cmp` the two live files with their copies. Run the whole block under `set -euo pipefail`, so a failed `find`, `shasum`, `sort`, or comparison cannot yield a false match. Any byte/path/symlink drift stops the task before staging; recover only by an explicit user-approved operation from these copies/archive, never automatically. Never rewrite the baseline after Phase 1 begins. At every commit, `git diff --cached --name-only` must exclude the three protected targets.

## Phase Order and Handoffs

| Done | Phase | Produces | Consumed by |
| --- | --- | --- | --- |
| - [ ] | [1. Security and deterministic harness](2026-08-13-connected-mini-store-phase-1-security-harness.md) | `AppClock`, cookie-free auth transport, credential redirect policy, safe diagnostics, bounded image loader, typed DummyJSON remote boundary, fail-closed scripted scenarios | 3, 4, 6, 7 |
| - [ ] | [2. Persistence foundations](2026-08-13-connected-mini-store-phase-2-persistence.md) | AppState schema 2, SwiftData V2 migration, cursor repository, atomic favorites/cart, Store preferences | 3, 4, 5, 7 |
| - [ ] | [3. Session subsystem](2026-08-13-connected-mini-store-phase-3-session.md) | actor-confined session repository, app-owned controller, restoration/refresh/login/sign-out state machine, root policy | 4, 5, 7 |
| - [ ] | [4. Guest Store and adaptive shell](2026-08-13-connected-mini-store-phase-4-guest-shell.md) | exactly two sections, typed routes/snapshot 5, adaptive Store/Services shell, guest catalog/detail/reviews/cart, scene-local `ISceneNavigationActions` | 5, 6, 7, 8 |
| - [ ] | [5. Protected navigation](2026-08-13-connected-mini-store-phase-5-protected-navigation.md) | scene router reconciliation, Authentication persistence retry, Favorites, public Profile/protected Account, protected links | 6, 7, 8 |
| - [ ] | [6. Product reminders](2026-08-13-connected-mini-store-phase-6-product-reminders.md) | reminder use case, immutable Store category, `IAppNotificationCategoryCatalog`, sole `LocalNotificationEventHistory`/read facade, typed response dispatcher, eligible-scene queue, bridge sequencing | 7, 8 |
| - [ ] | [7. Services learning labs](2026-08-13-connected-mini-store-phase-7-services-labs.md) | guided examples for every service operation, scoped labs, safe replay history, App State inspector | 8 |
| - [ ] | [8. Accessibility and replacement cleanup](2026-08-13-connected-mini-store-phase-8-accessibility-cleanup.md) | localized/adaptive/accessibility gates, split UI-test robots, removal of superseded examples, final documentation | release candidate |

## Ownership Invariants

| Concern | Sole semantic owner | Forbidden shortcut |
| --- | --- | --- |
| Access and refresh tokens | `SessionRepository` actor | Token fields in AppState, ViewModels, diagnostics, or Services labs |
| Visible session state | App-owned `SessionController` on `@MainActor` | A controller per scene or a network task owned by a view |
| Store and Services paths | Scene-owned typed routers | App-global paths or nested platform `NavigationSplitView` containers |
| Favorite/cart mutations | App-owned repository actors | Direct SwiftData writes from Views or independent window contexts |
| Notification category replacement | App-owned `IAppNotificationCategoryCatalog` | Raw `setCategories` in a Services ViewModel |
| Notification response semantics | Typed app response dispatcher | Business navigation driven by an event-history subscriber |
| Notification scene selection | Navigation coordinator | Parsing action identifiers or metadata in a scene registry |
| Network diagnostics | Allowlisted bounded recorder | Retaining requests, responses, target descriptions, bodies, or underlying errors |
| Services demo keys | Physical `AppTemplate.ServicesLab` namespace and closed key catalog | User-entered physical Keychain/UserDefaults keys |

## Cross-Phase Compatibility Gates

- [ ] Before phase 2, phase 1 has no live-network escape in previews or tests and all secret-sentinel tests pass.
- [ ] Before phase 3, a real V1 SwiftData file reopens under V2, preserves ExampleRecord bytes, and can use favorite/cart entities.
- [ ] Before phase 4, local Keychain restoration always leaves Restoring within the injected three-second deadline and remote validation never controls the root.
- [ ] Before phase 5, schema-5 route fixtures and V2/V3/V4 navigation migrations pass without importing legacy route types.
- [ ] Before phase 6, protected action reconciliation is idempotent across two scenes and Profile remains public after Sign Out.
- [ ] Before phase 7, default tap, Open Product, Favorite, and Remind Later each have one semantic owner and the callback-order test passes.
- [ ] Before deleting legacy sources in phase 8, replacement unit tests, UI journeys, previews, and macOS/iPhone/iPad builds pass.

## Verification Commands

Run focused commands from each phase plan after its tasks. At every phase boundary, run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

If the macOS runner exits before test bootstrap, record the full `xcresult` path and prove whether the failure is infrastructure-level before changing assertions. A failing or skipped required test is never converted into a successful gate.

## Final Release Gate

- [ ] Run the complete macOS unit and UI suites with warnings as errors.
- [ ] Run the complete iPhone and iPad unit/UI suites required by phase 8.
- [ ] Perform live DummyJSON catalog, login, profile, refresh, and diagnostics smoke checks.
- [ ] Perform real local-notification permission, scheduling, action, attachment, cancellation, and denial checks.
- [ ] Verify VoiceOver, keyboard focus, largest Dynamic Type, long-string localization, RTL, Reduce Motion, and compact toolbar overflow.
- [ ] Confirm `rg` finds no active Home/Browse/Projects/Settings routes or copy outside frozen migration fixtures and historical documents.
- [ ] Confirm the final diff contains no secrets, generated result bundles, or unrelated working-tree files.
