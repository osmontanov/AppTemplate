# Cross-Platform App Shell Design Addendum

**Status:** Approved by the user on 2026-08-04.

**Amends:** `2026-07-31-template-hardening-design.md`, Task 11 only.

## Goal

Keep one semantic navigation model while presenting it through native iPhone,
iPad, and macOS containers. The change must preserve the existing application
flow policy, scene ownership, typed routes, independent section histories,
deep links, and snapshot format.

The design also provides stable, nonlocalized accessibility identifiers for
cross-platform UI tests without replacing native tab or sidebar controls.

## Why This Addendum Exists

The original Task 11 implementation used one SwiftUI `TabView` with
`.sidebarAdaptable` on all platforms. Runtime verification on macOS 26.5 showed
that the generated sidebar did not retain the `TabContent` accessibility
identifiers. A native macOS `NavigationSplitView` fixed that boundary.

Runtime verification on iPhone then showed a separate SwiftUI 26 issue: the
official `TabContent.accessibilityIdentifier` worked on an initial UI-test
launch but disappeared from the generated tab controls after later independent
`XCUIApplication` launches. Navigation state and tab behavior remained correct.

The accessibility defect must not force a custom navigation system or weaken
the UI tests. The approved solution separates shared navigation semantics from
platform presentation and adds a narrow UIKit metadata adapter on iOS and
iPadOS.

## Alternatives Considered

### One adaptive `TabView` on every platform

This is compact and fully native. Apple documents `.sidebarAdaptable` as a
bottom tab bar on iPhone, an adaptable top tab bar or sidebar on iPad, and a
sidebar on macOS.

It was not selected for the template because the native macOS split-view shell
provides clearer desktop ownership, future column control, and reliable
selectable-row accessibility boundaries. The current runtime behavior also
makes one implementation less testable than two thin platform adapters.

### Shared semantics with native platform adapters

This is the selected design. iPhone and iPad keep the native adaptive
`TabView`; macOS uses a native sidebar-detail `NavigationSplitView`. Only the
container mechanics differ. Section identity, metadata, content, routers,
paths, deep links, and snapshots remain shared.

### Fully custom navigation chrome

This was rejected. A custom bar would need to recreate platform adaptation,
keyboard behavior, VoiceOver tab semantics, sidebar behavior, localization,
Liquid Glass styling, and future operating-system changes. A reusable template
must not own that maintenance cost solely to obtain test selectors.

## Preserved Ownership Model

`AppTemplateApp` continues to own the application-scoped dependency graph,
`AppStateStore`, `AppFlowCoordinator`, and `AppFlowRouter`.

Each `WindowGroup` scene continues to create one `AppSceneView`. The scene owns
one `AppSceneNavigationLifecycle`, which owns one `AppRouter` with:

- the selected top-level section;
- one stable `FlowRouter` for each section;
- scene-local pending navigation intent;
- scene-local navigation snapshot and transition checkpoint.

Application flow is shared between windows. Authentication, onboarding,
maintenance, sign-out, and other application-policy transitions therefore
affect every scene. Section selection, pushed paths, modal presentation, and
restoration remain independent per scene.

No platform shell may create an `AppRouter`, own a navigation path, interpret a
deep link, apply an application transition, or call raw `setFlow`.

## Shared Shell Components

The container hierarchy becomes:

```text
AppShellView
├── iOS/iPadOS: AdaptiveTabAppShellView
└── macOS: MacSidebarAppShellView
        └── both render AppSectionContentView
```

### `AppShellView`

`AppShellView` is a compile-time platform dispatcher. It forwards the existing
scene-owned `AppRouter` and feature dependencies to one platform adapter and
owns no state.

### `AppSectionPresentation`

Presentation metadata for every `AppSection` is defined once:

- localized title;
- SF Symbol name;
- stable presentation identifier;
- stable accessibility identifier.

The route enum remains the semantic identity and snapshot value. Presentation
metadata is kept in a container-layer file rather than coupling SwiftUI details
to snapshot codecs or routing policy.

The initial identifiers are:

| Section | Presentation identifier | Accessibility identifier |
| --- | --- | --- |
| Home | `app.section.home` | `tab.home` |
| Browse | `app.section.browse` | `tab.browse` |
| Projects | `app.section.projects` | `tab.projects` |
| Settings | `app.section.settings` | `tab.settings` |

### `AppSectionContentView`

One view contains the only section-to-content switch. It receives an explicit
section and maps it to the existing `HomeFlowView`, `BrowseFlowView`,
`ProjectsFlowView`, or `SettingsFlowView`, passing the corresponding stable
`FlowRouter` and the existing feature dependencies. Each iOS/iPadOS tab passes
its own section; the macOS detail column passes the current selection.

This removes duplicated section labels, identifiers, and flow-root switches
from the platform branches while preserving every feature's own navigation
destination mapping.

## iPhone and iPad Presentation

`AdaptiveTabAppShellView` uses one modern `TabView` whose selection binds
directly to `router.selectedSection` and whose style is `.sidebarAdaptable`.

The system decides the representation:

- iPhone uses a native bottom tab bar;
- iPad uses a native top tab bar that can adapt into a sidebar;
- resizing or changing presentation never replaces the scene router or any
  section path.

The shell does not branch on `UIDevice`, device model, or horizontal size class.
It does not create an iPad-specific `NavigationSplitView`, because the four
sections are peer top-level modes rather than a leading-list/detail hierarchy.

Every SwiftUI `Tab` receives the stable presentation identifier through
`customizationID` and the official `TabContent.accessibilityIdentifier` before
the UIKit adapter runs.

## macOS Presentation

`MacSidebarAppShellView` uses `NavigationSplitView` with a flat
`.sidebar`-styled `List` bound directly to `router.selectedSection`.

Each selectable row uses the shared title, symbol, tag, and accessibility
identifier. The detail column renders `AppSectionContentView`.

The existing `WindowGroup` remains the main scene so the template supports
multiple independent main windows. The native `Settings` scene remains
separate from main-window navigation. The in-app Settings section continues to
demonstrate session/about navigation and exposes `SettingsLink` on macOS to
open the actual preferences window.

This addendum does not rename the Settings feature or change its routes. A
future product can split account, support, and preferences when real product
requirements exist.

## UIKit Accessibility Adapter

`TabAccessibilityIdentifierInstaller` is a small
`UIViewControllerRepresentable` compiled only under `os(iOS)`, which covers
both iPhone and iPad.

Its sole responsibility is to reinforce automation metadata on the native
UIKit tab objects produced by SwiftUI:

1. Obtain the ancestor `UITabBarController` through the public
   `UIViewController.tabBarController` relationship.
2. Resolve each `UITab` from its stable presentation identifier using public
   tab-controller APIs.
3. Set the matching automation identifier on `UITab` and its associated
   `UITabBarItem` where present.
4. Repeat idempotently after relevant view-controller appearance or update
   callbacks so SwiftUI reconstruction cannot permanently remove the metadata.

The implementation must use public UIKit APIs only. It must not:

- enumerate tabs by position;
- match localized titles or symbols;
- traverse private SwiftUI view classes;
- use KVC or private selectors;
- replace the tab array;
- change selection, visibility, placement, images, titles, or appearance;
- become a dependency of navigation behavior.

The SwiftUI-to-UIKit presentation-identifier mapping is an implementation gate,
not an assumption. The first focused test must prove that the public lookup
resolves all four tabs. If it does not, implementation stops at RED and the
adapter design is revised. It must not fall back to indices, localized labels,
or hidden proxy controls.

Failure to install metadata never changes application behavior or crashes a
release build. Debug builds may emit a category-only diagnostic without user
or route data. UI tests remain the authoritative signal that the metadata
boundary works.

## Navigation Data Flow

All entry points converge on the same scene router:

- a tab or sidebar selection writes `router.selectedSection`;
- a deep link selects the required section and mutates only that section's
  `FlowRouter` path;
- snapshot restoration restores selection and every independent section path;
- an application-flow transition resets histories according to the existing
  transition policy;
- a platform representation change reads the same state and performs no
  navigation mutation.

No closures, service locator, global scene router, new ViewModel, or new
navigation protocol is introduced.

## Deterministic UI-Test Launch

The existing four-argument UI-test launch contract remains exact and unchanged.
The launch composition additionally selects an ephemeral scene-navigation
persistence policy:

- do not apply previously stored `SceneStorage` navigation data;
- do not write UI-test navigation snapshots;
- create a fresh scene router with Home selected for the main root;
- leave live application restoration behavior unchanged.

This policy is passed explicitly through root composition. It is not inferred
inside feature views and is not stored in the application dependency graph as a
service.

On macOS, the test launch helper waits for the expected main root rather than
accepting any existing window. After launch and activation, it sends Command-N
only if the main root is absent. A restored Settings window therefore cannot
satisfy main-window readiness.

## Testing Strategy

### Focused RED/GREEN behavior

Preserve the existing iPhone ordered-relaunch failure as RED evidence. Add the
minimum adapter and rerun the same ordered scenario until `tab.browse` remains
available after every independent application launch.

The bridge verification must demonstrate:

- all four stable presentation identifiers resolve to native tabs;
- every resolved tab exposes its exact nonlocalized automation identifier;
- reinstalling metadata is idempotent;
- tab selection still changes only `router.selectedSection`;
- no localized-label or index fallback is used.

### Cross-platform UI coverage

Run the approved smoke scenarios on:

- iPhone 17 with iOS 26.5;
- iPad (A16) with iPadOS 26.5;
- macOS 26, arm64.

The suite covers onboarding, Browse selection, Navigation Guide push, Browse
Options presentation and dismissal, and the native macOS Settings window.
Every test starts from a fresh UI-test composition and queries exact stable
identifiers.

### Regression verification

Run the full unit and UI-test matrix with compiler warnings treated as errors.
Existing router, deep-link, snapshot migration, future-schema preservation,
flow-policy, dependency-injection, preview, localization, and configuration
tests must remain green. Validate the shared scheme and project structure, run
`git diff --check`, and audit the final identifier set.

## File Layout

```text
AppTemplate/App/Navigation/Containers/
├── AppShellView.swift
├── AppSectionContentView.swift
├── AppSectionPresentation.swift
└── Platforms/
    ├── iOS/
    │   ├── AdaptiveTabAppShellView.swift
    │   └── TabAccessibilityIdentifierInstaller.swift
    └── macOS/
        └── MacSidebarAppShellView.swift
```

Platform files include compile guards because the synchronized application
target builds the same source hierarchy for iOS, iPadOS, and macOS.

## Explicit Non-Goals

- No router, route, snapshot-schema, deep-link, or application-flow rewrite.
- No custom tab bar or sidebar.
- No UIKit-owned navigation controller hierarchy.
- No AppKit bridge.
- No tab customization UI or persisted tab reordering.
- No Settings feature rename or product behavior.
- No new service, repository, model, or ViewModel.
- No change to deployment targets or UI-test launch arguments.

## References

- [Apple Human Interface Guidelines: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Apple Human Interface Guidelines: Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [SwiftUI `SidebarAdaptableTabViewStyle`](https://developer.apple.com/documentation/swiftui/sidebaradaptabletabviewstyle)
- [SwiftUI `NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [SwiftUI `TabContent.accessibilityIdentifier`](https://developer.apple.com/documentation/swiftui/tabcontent/accessibilityidentifier(_:isenabled:))
- [UIKit `UITab`](https://developer.apple.com/documentation/uikit/uitab)
- [UIKit `UIAccessibilityIdentification`](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification)
- [SwiftUI `SceneStorage`](https://developer.apple.com/documentation/swiftui/scenestorage)
