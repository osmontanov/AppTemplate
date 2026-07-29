# Reusable SwiftUI UI Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace empty UIComponents placeholders with three real reusable SwiftUI state views and adopt them in existing screens without changing behavior.

**Architecture:** `Utilities/UIComponents` will contain one independent SwiftUI `View` per file: loading, empty, and retryable error presentation. Screens continue to own state, ViewModels, async lifecycle, navigation, and actions; they pass only plain presentation values and a retry callback into the shared views.

**Tech Stack:** Swift, SwiftUI, Observation, Swift Testing, Xcode 26, file-system-synchronized Xcode groups.

## Global Constraints

- Support iOS 26, iPadOS 26, and macOS 26.
- Add no external dependencies.
- Every Swift type under `AppTemplate/Utilities/UIComponents` must conform directly to `View`.
- UIComponents must not depend on a screen, ViewModel, Router, Route, `AppDependencies`, a feature dependency scope, a service, or a repository.
- Do not create a marker protocol such as `UIComponent`.
- Do not create a generic state container or design-system abstraction.
- Preserve all current titles, messages, SF Symbols, retry behavior, navigation, async lifecycle, and rendered content.
- Leave `SettingsNavigationView`, `AuthenticationView`, and all other non-adopting screens unchanged.
- Do not modify ViewModels, services, DI, models, navigation, or supported platforms.
- Do not add initializer, getter, source-location, symbol-absence, or snapshot tests.
- Keep historical architecture specs and plans unchanged.
- Use synchronized filesystem groups; do not intentionally modify `AppTemplate.xcodeproj/project.pbxproj`.
- Preserve unrelated in-progress user changes, including the staged `AppDependencies` move and the existing main-worktree `project.pbxproj` diff. Execute source work in an isolated worktree created from committed `HEAD`.

## File Structure

Create:

- `AppTemplate/Utilities/UIComponents/LoadingStateView.swift`: labeled whole-screen loading presentation.
- `AppTemplate/Utilities/UIComponents/EmptyStateView.swift`: empty or unavailable presentation without an action.
- `AppTemplate/Utilities/UIComponents/ErrorStateView.swift`: retryable failure presentation.

Delete:

- `AppTemplate/Utilities/UIComponents/AuthenticationComponents.swift`
- `AppTemplate/Utilities/UIComponents/BrowseComponents.swift`
- `AppTemplate/Utilities/UIComponents/HomeComponents.swift`
- `AppTemplate/Utilities/UIComponents/SettingsComponents.swift`

Modify:

- `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift`
- `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift`
- `AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift`
- `README.md`

Leave unchanged:

- `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`
- `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- all ViewModels, navigation, DI, services, models, and tests;
- all historical files under `docs/superpowers/specs` and
  `docs/superpowers/plans`;
- `AppTemplate.xcodeproj/project.pbxproj`.

---

### Task 1: Replace Empty Extension Points with Reusable Views

**Files:**

- Create: `AppTemplate/Utilities/UIComponents/LoadingStateView.swift`
- Create: `AppTemplate/Utilities/UIComponents/EmptyStateView.swift`
- Create: `AppTemplate/Utilities/UIComponents/ErrorStateView.swift`
- Delete: `AppTemplate/Utilities/UIComponents/AuthenticationComponents.swift`
- Delete: `AppTemplate/Utilities/UIComponents/BrowseComponents.swift`
- Delete: `AppTemplate/Utilities/UIComponents/HomeComponents.swift`
- Delete: `AppTemplate/Utilities/UIComponents/SettingsComponents.swift`

**Interfaces:**

- Produces: `LoadingStateView.init(title: String)`.
- Produces: `EmptyStateView.init(title: String, systemImage: String, message: String)`.
- Produces: `ErrorStateView.init(title: String, message: String, retry: @escaping () -> Void)`.
- Preserves: system-native SwiftUI accessibility and cross-platform behavior.

- [ ] **Step 1: Verify the current folder violates the View-only rule**

Run:

```bash
set -e
failed=0
for file in AppTemplate/Utilities/UIComponents/*.swift; do
  if ! rg -q '^import SwiftUI$' "$file" ||
     ! rg -q '^struct [A-Za-z][A-Za-z0-9]*: View \\{' "$file"; then
    printf 'not a SwiftUI View: %s\n' "$file"
    failed=1
  fi
done
test "$failed" -eq 0
```

Expected: exit non-zero and report all four existing placeholder files.

- [ ] **Step 2: Delete the four empty placeholders**

Delete without replacement types:

```text
AppTemplate/Utilities/UIComponents/AuthenticationComponents.swift
AppTemplate/Utilities/UIComponents/BrowseComponents.swift
AppTemplate/Utilities/UIComponents/HomeComponents.swift
AppTemplate/Utilities/UIComponents/SettingsComponents.swift
```

Do not preserve the old type names or create `EmptyView` equivalents.

- [ ] **Step 3: Add `LoadingStateView`**

Create `AppTemplate/Utilities/UIComponents/LoadingStateView.swift`:

```swift
import SwiftUI

struct LoadingStateView: View {
    let title: String

    var body: some View {
        ProgressView(title)
    }
}

#Preview("Loading") {
    LoadingStateView(title: "Loading…")
}
```

- [ ] **Step 4: Add `EmptyStateView`**

Create `AppTemplate/Utilities/UIComponents/EmptyStateView.swift`:

```swift
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
    }
}

#Preview("Empty") {
    EmptyStateView(
        title: "No Items",
        systemImage: "tray",
        message: "There are no items yet."
    )
}
```

- [ ] **Step 5: Add `ErrorStateView`**

Create `AppTemplate/Utilities/UIComponents/ErrorStateView.swift`:

```swift
import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                title,
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
        }
    }
}

#Preview("Error") {
    ErrorStateView(
        title: "Unavailable",
        message: "Please try again.",
        retry: {}
    )
}
```

- [ ] **Step 6: Verify the folder now contains only concrete Views**

Run:

```bash
set -e
test "$(find AppTemplate/Utilities/UIComponents \
  -maxdepth 1 \
  -type f \
  -name '*.swift' \
  | wc -l \
  | tr -d ' ')" -eq 3

for file in AppTemplate/Utilities/UIComponents/*.swift; do
  rg -q '^import SwiftUI$' "$file"
  rg -q '^struct [A-Za-z][A-Za-z0-9]*: View \\{' "$file"
  rg -q '^#Preview' "$file"
done

! rg -n \
  'AuthenticationComponents|BrowseComponents|HomeComponents|SettingsComponents|ViewModel|Router|Route|AppDependencies|Dependencies|Service|Repository' \
  AppTemplate/Utilities/UIComponents \
  --glob '*.swift'
```

Expected: every command exits 0. The folder contains exactly the three new
View files, and no prohibited dependency or placeholder name appears.

- [ ] **Step 7: Build the component catalog for macOS**

Run:

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-reusable-ui-components-task1-macos
```

Expected: exit 0.

- [ ] **Step 8: Build the component catalog for iOS and iPadOS-compatible code**

Run:

```bash
xcodebuild build -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-reusable-ui-components-task1-ios
```

Expected: exit 0. The shared target continues to include both iPhone and iPad
device families.

- [ ] **Step 9: Verify diff and project-file hygiene**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
git status --short
```

Expected:

- `git diff --check` exits 0;
- `project.pbxproj` has no diff;
- status contains only the four placeholder deletions and three new View
  files.

- [ ] **Step 10: Commit the component catalog**

```bash
git add \
  AppTemplate/Utilities/UIComponents/AuthenticationComponents.swift \
  AppTemplate/Utilities/UIComponents/BrowseComponents.swift \
  AppTemplate/Utilities/UIComponents/HomeComponents.swift \
  AppTemplate/Utilities/UIComponents/SettingsComponents.swift \
  AppTemplate/Utilities/UIComponents/LoadingStateView.swift \
  AppTemplate/Utilities/UIComponents/EmptyStateView.swift \
  AppTemplate/Utilities/UIComponents/ErrorStateView.swift
git commit -m "feat: add reusable UI state views"
```

---

### Task 2: Adopt the Reusable Views in Existing Screens

**Files:**

- Modify: `AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift:23-57`
- Modify: `AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift:19-48`
- Modify: `AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift:12-18`
- Modify: `README.md:21`

**Interfaces:**

- Consumes: `LoadingStateView.init(title:)` from Task 1.
- Consumes: `EmptyStateView.init(title:systemImage:message:)` from Task 1.
- Consumes: `ErrorStateView.init(title:message:retry:)` from Task 1.
- Preserves: the existing `LoadableState` switches and ViewModel-owned retry methods.
- Produces: real production consumers for every shared component.

- [ ] **Step 1: Verify the existing screens still contain the duplicated state UI**

Run:

```bash
rg -n \
  'ProgressView\\("Loading Browse…"|ProgressView\\("Loading Item…"|ContentUnavailableView' \
  AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift \
  AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift
```

Expected: exit 0 and report both loading views plus the existing unavailable
state declarations.

- [ ] **Step 2: Adopt all three shared components in `BrowseNavigationView`**

Replace the current `switch viewModel.state` body with:

```swift
switch viewModel.state {
case .idle, .loading:
    LoadingStateView(title: "Loading Browse…")
case .empty:
    EmptyStateView(
        title: "No Browse Items",
        systemImage: "tray",
        message: "There are no Browse items yet."
    )
case let .content(items):
    List(items) { item in
        NavigationLink(value: BrowseRoute.item(id: item.id)) {
            VStack(alignment: .leading) {
                Text(item.title)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
case let .failed(failure):
    ErrorStateView(
        title: "Browse Unavailable",
        message: failure.message,
        retry: {
            viewModel.retry()
        }
    )
}
```

Do not change the surrounding `NavigationStack`, task lifecycle,
navigation destination, or dependency flow.

- [ ] **Step 3: Adopt all three shared components in `BrowseDetailView`**

Replace the current `switch viewModel.state` body with:

```swift
switch viewModel.state {
case .idle, .loading:
    LoadingStateView(title: "Loading Item…")
case let .content(item):
    Form {
        LabeledContent("Identifier", value: item.id)
        Text(item.summary)
    }
    .navigationTitle(item.title)
case .empty:
    EmptyStateView(
        title: "Item Unavailable",
        systemImage: "questionmark.folder",
        message: "This item no longer exists."
    )
case let .failed(failure):
    ErrorStateView(
        title: "Item Unavailable",
        message: failure.message,
        retry: {
            viewModel.retry()
        }
    )
}
```

Do not change `.task(id:)`, cancellation, the content form, or the navigation
title.

- [ ] **Step 4: Adopt `EmptyStateView` in `HomeDetailsView`**

Replace the existing `ContentUnavailableView` with:

```swift
EmptyStateView(
    title: viewModel.title,
    systemImage: viewModel.systemImage,
    message: viewModel.message
)
.navigationTitle("Details")
```

Do not change `HomeDetailsViewModel` or its initializer.

- [ ] **Step 5: Strengthen the current README ownership rule**

Replace:

```markdown
- `Utilities/UIComponents` contains reusable UI independent from screens.
```

With:

```markdown
- `Utilities/UIComponents` contains only reusable SwiftUI `View` types
  independent from screens.
```

Keep every surrounding ownership bullet unchanged.

- [ ] **Step 6: Verify adoption, presentation preservation, and exclusions**

Run:

```bash
set -e

rg -n 'LoadingStateView|EmptyStateView|ErrorStateView' \
  AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift \
  AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift

rg -n \
  'Loading Browse…|No Browse Items|There are no Browse items yet.|Browse Unavailable|Loading Item…|Item Unavailable|This item no longer exists.|questionmark.folder|tray' \
  AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift \
  AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift

! rg -n \
  'ProgressView\\("Loading Browse…"|ProgressView\\("Loading Item…"|ContentUnavailableView' \
  AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift \
  AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift

rg -n 'ProgressView\\(\\)' \
  AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift

rg -n 'Connect the project’s session service here.' \
  AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift

sed -n '16,24p' README.md
```

Expected:

- all three shared View names appear in the intended consumers;
- every existing user-facing string and SF Symbol remains present;
- the replaced native state declarations are absent from the adopting screens;
- Settings retains its compact inline progress indicator;
- Authentication remains unchanged;
- README contains the exact View-only ownership rule.

- [ ] **Step 7: Verify task diff and project-file hygiene**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
git status --short
```

Expected:

- `git diff --check` exits 0;
- `project.pbxproj` has no diff;
- status contains only the three adopting screen files and README.

- [ ] **Step 8: Run the full macOS test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-reusable-ui-components-final-macos
```

Expected: exit 0.

- [ ] **Step 9: Run the full iOS and iPadOS-compatible test suite**

Run:

```bash
xcodebuild test -quiet \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/AppTemplate-reusable-ui-components-final-ios
```

Expected: exit 0. The shared iOS target covers both iPhone and iPad device
families.

- [ ] **Step 10: Recheck the working tree after Xcode verification**

Run:

```bash
git diff --check
git diff --exit-code -- AppTemplate.xcodeproj/project.pbxproj
git status --short
```

Expected: the same intended three screen changes and README change remain,
with no Xcode project-file canonicalization.

- [ ] **Step 11: Commit shared-component adoption**

```bash
git add \
  README.md \
  AppTemplate/Features/Browse/Screens/Browse/View/BrowseNavigationView.swift \
  AppTemplate/Features/Browse/Screens/BrowseDetail/View/BrowseDetailView.swift \
  AppTemplate/Features/Home/Screens/HomeDetails/View/HomeDetailsView.swift
git commit -m "refactor: adopt reusable UI state views"
```
