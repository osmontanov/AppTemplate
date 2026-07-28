# Domain Model Ownership Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `App/Models/Domain` contain only shared business entities, move the NavigationGuide presentation item to its screen, and remove obsolete model placeholders.

**Architecture:** `BrowseItem` and `UserSession` remain unchanged as shared Domain entities. `NavigationGuideItem` moves unchanged to the NavigationGuide screen because it is presentation-specific and has no consumers elsewhere. Empty feature-era placeholders are deleted, and README becomes the authoritative summary of role-based model ownership.

**Tech Stack:** Swift, SwiftUI, Observation, Swift Testing, Xcode 26, file-system-synchronized Xcode groups.

## Global Constraints

- Support iOS 26, iPadOS 26, and macOS 26.
- Add no external dependencies.
- Do not change runtime behavior, navigation, dependency injection, services, presentation content, or supported platforms.
- Keep `BrowseItem` and `UserSession` declarations and conformances unchanged.
- Keep the `NavigationGuideItem` type name, stored properties, conformances, and access level unchanged.
- Domain must contain only `BrowseItem.swift` and `UserSession.swift`.
- Delete `AuthenticationModel`, `HomeModel`, and `SettingsModel`; do not replace them with empty types.
- Do not create empty Model folders for other screens.
- Keep historical architecture specs unchanged.
- Do not add source-location, symbol-absence, initializer, or getter tests.
- Use synchronized filesystem groups; do not intentionally modify `AppTemplate.xcodeproj/project.pbxproj`.

## File Structure

Create by moving the existing declaration unchanged:

- `AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift`: screen-owned presentation item.

Modify:

- `README.md`: current role-based model ownership rules.

Delete:

- `AppTemplate/App/Models/Domain/NavigationGuideItem.swift`
- `AppTemplate/App/Models/Domain/AuthenticationModel.swift`
- `AppTemplate/App/Models/Domain/HomeModel.swift`
- `AppTemplate/App/Models/Domain/SettingsModel.swift`

Leave unchanged:

- `AppTemplate/App/Models/Domain/BrowseItem.swift`
- `AppTemplate/App/Models/Domain/UserSession.swift`
- all runtime code and tests;
- all historical files under `docs/superpowers/specs` and
  `docs/superpowers/plans`;
- `AppTemplate.xcodeproj/project.pbxproj`.

---

### Task 1: Enforce Role-Based Domain Ownership

**Files:**

- Create: `AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift`
- Modify: `README.md:7-18`
- Delete: `AppTemplate/App/Models/Domain/NavigationGuideItem.swift`
- Delete: `AppTemplate/App/Models/Domain/AuthenticationModel.swift`
- Delete: `AppTemplate/App/Models/Domain/HomeModel.swift`
- Delete: `AppTemplate/App/Models/Domain/SettingsModel.swift`

**Interfaces:**

- Consumes: the existing `NavigationGuideViewModel.items` property and its three `NavigationGuideItem` construction sites.
- Produces: the unchanged `nonisolated struct NavigationGuideItem: Identifiable, Equatable, Sendable` declaration at the screen-owned path.
- Preserves: `BrowseItem`, `UserSession`, all runtime APIs, and all rendered NavigationGuide content.

- [ ] **Step 1: Verify the migration preconditions**

Run:

```bash
rg -n \
  '\b(AuthenticationModel|HomeModel|SettingsModel)\b' \
  AppTemplate AppTemplateTests \
  --glob '*.swift'

rg -n '\bNavigationGuideItem\b' \
  AppTemplate AppTemplateTests \
  --glob '*.swift'
```

Expected:

- each placeholder appears only in its own Domain declaration;
- `NavigationGuideItem` appears only in its Domain declaration and
  `NavigationGuideViewModel`;
- no service, state, navigation, DI, or other feature consumer appears.

- [ ] **Step 2: Move the presentation model and delete the placeholders**

Move the declaration from
`AppTemplate/App/Models/Domain/NavigationGuideItem.swift` to
`AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift`
without changing its contents:

```swift
nonisolated struct NavigationGuideItem:
    Identifiable,
    Equatable,
    Sendable {
    let id: String
    let title: String
    let systemImage: String
}
```

Delete these files without replacement:

```text
AppTemplate/App/Models/Domain/AuthenticationModel.swift
AppTemplate/App/Models/Domain/HomeModel.swift
AppTemplate/App/Models/Domain/SettingsModel.swift
```

Do not modify `NavigationGuideViewModel`, `BrowseItem`, or `UserSession`.

- [ ] **Step 3: Replace the README ownership bullets**

In `README.md`, replace the existing model and screen ownership bullets with:

```markdown
- `App/Models/Domain` owns shared business entities.
- `App/Models/State` owns shared application state.
- `App/Models/Local` owns local queries and persisted records.
- `App/Models/Remote` owns transport requests and responses.
- `App/Services` owns `I<ServiceName>` contracts and concrete
  `<ServiceName>` implementations.
- `Features/<Feature>/Screens/<Screen>` owns each screen's View and ViewModel.
- `Features/<Feature>/Screens/<Screen>/Model` owns presentation models used
  only by that screen.
```

Keep the surrounding Entry, Composition, Navigation, Router/Route,
UIComponents, Repository, and Resources ownership bullets unchanged.

- [ ] **Step 4: Verify the final source ownership**

Run:

```bash
find AppTemplate/App/Models/Domain \
  -maxdepth 1 \
  -type f \
  -name '*.swift' \
  -print \
  | sort

test -f \
  AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift

test ! -e AppTemplate/App/Models/Domain/NavigationGuideItem.swift
test ! -e AppTemplate/App/Models/Domain/AuthenticationModel.swift
test ! -e AppTemplate/App/Models/Domain/HomeModel.swift
test ! -e AppTemplate/App/Models/Domain/SettingsModel.swift

! rg -n \
  '\b(AuthenticationModel|HomeModel|SettingsModel)\b' \
  AppTemplate AppTemplateTests \
  --glob '*.swift'

rg -n '\bNavigationGuideItem\b' \
  AppTemplate AppTemplateTests \
  --glob '*.swift'

git diff --find-renames=100% --summary
```

Expected:

- Domain prints only `BrowseItem.swift` and `UserSession.swift`;
- every `test` and negated `rg` command exits 0;
- `NavigationGuideItem` appears only in its new declaration and
  `NavigationGuideViewModel`;
- Git reports `NavigationGuideItem.swift` as a 100% rename;
- Git reports the three placeholder deletions.

- [ ] **Step 5: Verify the README rule**

Run:

```bash
sed -n '7,24p' README.md
```

Expected: the output contains the exact Domain, State, Local, Remote, screen,
and screen Model ownership bullets from Step 3, with no statement that Domain
owns presentation models.

- [ ] **Step 6: Verify project-file and diff hygiene**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
git status --short
```

Expected:

- `git diff --check` exits 0;
- `project.pbxproj` has no diff;
- status lists only the README change, the NavigationGuideItem move, and the
  three placeholder deletions.

- [ ] **Step 7: Run the full macOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS'
```

Expected: exit 0.

- [ ] **Step 8: Run the full iOS/iPadOS-compatible test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: exit 0. The shared iOS target covers both iPhone and iPad device
families, and the moved presentation model contains no device-specific code.

- [ ] **Step 9: Recheck the working tree after Xcode verification**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
git status --short
```

Expected: the same intended README, rename, and deletion set remains, with no
Xcode project-file canonicalization.

- [ ] **Step 10: Commit the ownership cleanup**

```bash
git add \
  README.md \
  AppTemplate/App/Models/Domain/NavigationGuideItem.swift \
  AppTemplate/App/Models/Domain/AuthenticationModel.swift \
  AppTemplate/App/Models/Domain/HomeModel.swift \
  AppTemplate/App/Models/Domain/SettingsModel.swift \
  AppTemplate/Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift
git commit -m "refactor: align domain model ownership"
```
