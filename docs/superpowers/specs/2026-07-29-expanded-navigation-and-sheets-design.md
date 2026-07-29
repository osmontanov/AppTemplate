# Expanded Navigation and Sheets Design

## Status

Approved for implementation on 2026-07-29.

## Purpose

AppTemplate already demonstrates independent tab histories, screen-owned
push routes, authentication root replacement, deep links, and scene-scoped
snapshot restoration. It does not yet demonstrate:

- a newly added independent feature tab;
- a deeper push hierarchy in every existing feature;
- screen-owned one-screen sheets;
- a multi-screen sheet that starts a new independent navigation flow;
- transient modal state working alongside restorable stack state.

This change adds those examples as coherent user scenarios. It does not add a
network API, database, repository layer, or unrelated infrastructure.

## Selected Scope

The selected approach is a balanced vertical slice:

- extend Authentication, Home, Browse, and Settings;
- add a new Projects feature and tab;
- add useful one-screen sheets;
- add one independently navigated create-project sheet flow;
- extend deep links and navigation snapshots for Projects.

A dedicated navigation playground was rejected because it would demonstrate
patterns outside normal feature ownership. A complete Projects data service
and persistence layer was rejected because the current task is navigation and
presentation architecture.

## Architectural Rules

The existing hierarchical flow architecture remains authoritative.

### Independent flows

An independent flow owns one `FlowRouter` and one navigation container.

The application-level independent flows become:

- Authentication;
- Home;
- Browse;
- Projects;
- Settings.

`AppRouter` owns the five scene-scoped routers. Every tab preserves its own
history. Switching tabs does not move or rebuild another tab's path.

### Push ownership

Every full screen owns:

- its outgoing push Route enum;
- its `.navigationDestination` mapping;
- its screen ViewModel;
- its local presentation state.

The same `FlowRouter` instance is passed through the complete hierarchy of a
tab. ViewModels receive `any IFlowRouter`; Views may retain the concrete
`FlowRouter` when they need to pass it to a destination.

No navigation closures, global routers, service locators, environment router
lookups, or feature-specific Router types are introduced.

### Sheet ownership

A one-screen sheet is transient state owned by the initiating screen
ViewModel. Its enum does not conform to `NavigationRoute` and is not persisted.

Each sheet is presented with `.sheet(item:)`. The sheet content calls
`dismiss()` internally. Mutating sheets work through an explicitly shared
feature state object, not completion closures.

A multi-screen sheet starts from a new zero point. It therefore owns:

- a new temporary `FlowRouter`;
- a new `NavigationStack`;
- one shared draft state for all steps.

Closing the multi-screen sheet destroys its Router, path, and draft.

## Feature Navigation

### Authentication

Authentication remains its own root flow.

Push hierarchy:

```text
AuthenticationView
└── AuthenticationHelpView
```

`AuthenticationRoute` gains `.help`. `AuthenticationView` owns the destination
mapping. Authentication Help is a leaf screen with an empty reserved Route
scaffold.

### Home

Existing Home navigation remains:

```text
HomeView
├── HomeDetailsView
│   └── NavigationGuideView
└── NavigationGuideView
```

The guide becomes a meaningful deeper hierarchy:

```text
NavigationGuideView
└── GuideTopicView
```

`NavigationGuideRoute` gains `.topic(id:)`. The route carries only the stable
`NavigationGuideItem.ID`. `NavigationGuideView` owns the destination mapping.

Home gains `HomeSheetRoute.quickStart`. `QuickStartView` is a one-screen,
read-only sheet that explains the main template paths and dismisses itself.
The sheet does not create another navigation container.

### Browse

Browse keeps its service-backed list and detail behavior and adds a deeper
related-content path:

```text
BrowseView
└── BrowseDetailView
    └── RelatedItemsView
        └── RelatedItemDetailView
```

Routes:

- `BrowseRoute.item(id:)`;
- `BrowseDetailRoute.relatedItems(itemID:)`;
- `RelatedItemsRoute.item(id:)`.

Each mapping lives on the screen that originates the transition. Every child
receives the same Browse `FlowRouter` and `BrowseDependencies`.

Browse gains `BrowseSheetRoute.options`. `BrowseOptionsView` is a one-screen
sheet for choosing title sort order. A feature-scoped
`BrowsePreferencesStore` is shared by `BrowseView` and `BrowseOptionsView`.
The sheet updates the preference directly and dismisses itself. Existing
service loading, retry, cancellation, empty, and failure behavior remains
unchanged.

### Settings

Settings keeps its session controls and About destination and adds:

```text
SettingsView
└── AboutView
    └── PlatformDetailsView
```

`AboutRoute` gains `.platform(name:)`. The route carries a small stable string,
not a View, ViewModel, service, or full model.

Settings gains `SettingsSheetRoute.sessionInfo`. `SessionInfoView` receives
the existing `SessionStore`, displays the current session state, and dismisses
itself. It does not own or create a Router.

### Projects

Projects is a new independent tab and a complete navigation example.

Main push hierarchy:

```text
ProjectsView
└── ProjectDetailsView
    └── TaskDetailsView
```

Routes:

- `ProjectsRoute.project(id:)`;
- `ProjectDetailsRoute.task(projectID:taskID:)`;
- `TaskDetailsRoute` remains an empty leaf scaffold.

`ProjectDetailsView` also owns
`ProjectDetailsSheetRoute.projectInfo(projectID:)`. `ProjectInfoView` displays
project metadata as a one-screen sheet and dismisses itself.

Projects root owns `ProjectsSheetRoute.createProject`. That route presents the
independent create-project flow:

```text
CreateProjectFlowView
└── ProjectBasicsView
    └── ProjectOptionsView
        └── ProjectReviewView
```

The flow owns a temporary Router and one `CreateProjectDraftState`.

Step routes:

- `ProjectBasicsRoute.options`;
- `ProjectOptionsRoute.review`;
- `ProjectReviewRoute` remains an empty leaf scaffold.

Project Review inserts the completed project into the shared `ProjectsStore`
and then dismisses the sheet. No save or navigation closure is injected.

## Models and State

### Domain items

The shared item convention remains unchanged. These models live in
`App/Models/Domain`:

- `ProjectItem`;
- `ProjectTaskItem`.

They are identifiable, codable, hashable, and sendable. Routes carry their
stable IDs.

`ProjectItem` contains:

- stable string ID;
- title;
- summary;
- display color identifier;
- an array of `ProjectTaskItem`.

`ProjectTaskItem` contains:

- stable string ID;
- title;
- completion state.

### ProjectsStore

`ProjectsStore` lives in `Features/Projects/State`.

It is a `@MainActor @Observable` feature state object owned by
`ProjectsFlowView`. It:

- starts with deterministic example projects;
- exposes project and task lookup by stable ID;
- inserts a completed draft as a new project;
- is passed explicitly to Projects screens and the create-project sheet.

It is not a Service because the example has no external I/O or persistence.
When a real application adds an API or database, this store can be replaced or
fed by an injected Service without changing route ownership.

### CreateProjectDraftState

`CreateProjectDraftState` lives in `Features/Projects/State` because multiple
screens in one feature flow share it.

It stores:

- project title;
- summary;
- selected display color.

The Basics step validates the trimmed title before pushing Options. Closing
the sheet before Review discards the entire draft and leaves `ProjectsStore`
unchanged.

### BrowsePreferencesStore

`BrowsePreferencesStore` lives in `Features/Browse/State` and is owned by
`BrowseFlowView`. It stores one `BrowseSortOrder` value. Browse list rendering
derives its sorted content from the loaded service items and this preference.

The sort preference is feature-scoped transient state. It is not placed in
the navigation snapshot.

## Folder Structure

Projects follows the same feature scaffold as the existing features:

```text
Features/Projects/
├── Dependencies/
│   └── ProjectsDependencies.swift
├── Flow/
│   ├── ProjectsFlowView.swift
│   └── CreateProjectFlowView.swift
├── State/
│   ├── ProjectsStore.swift
│   └── CreateProjectDraftState.swift
└── Screens/
    ├── Projects/
    ├── ProjectDetails/
    ├── TaskDetails/
    ├── ProjectInfo/
    ├── ProjectBasics/
    ├── ProjectOptions/
    └── ProjectReview/
```

Every new full screen in every feature receives:

```text
<Screen>/
├── Model/<Screen>Model.swift
├── Navigation/<Screen>Route.swift
├── State/<Screen>State.swift
├── View/<Screen>View.swift
└── ViewModel/<Screen>ViewModel.swift
```

The same scaffold is created even when a reserved Model, State, or Route is
initially empty.

New one-screen presentations are modeled as screens:

- `Home/Screens/QuickStart`;
- `Browse/Screens/BrowseOptions`;
- `Settings/Screens/SessionInfo`;
- `Projects/Screens/ProjectInfo`.

Additional pushed screens are:

- `Authentication/Screens/AuthenticationHelp`;
- `Home/Screens/GuideTopic`;
- `Browse/Screens/RelatedItems`;
- `Browse/Screens/RelatedItemDetail`;
- `Settings/Screens/PlatformDetails`.

## App Integration

### AppSection and shell

`AppSection` gains `.projects` with a stable raw value. `AppShellView` adds a
Projects tab with a system image appropriate for a project workspace.

`AppRouter` gains a `projects: FlowRouter`. Reset, authentication, logout,
scene isolation, and default-root behavior include Projects.

### Deep links

The parser adds:

```text
apptemplate://projects
apptemplate://projects/project/<project-id>
apptemplate://projects/project/<project-id>/task/<task-id>
```

Canonical intent application:

1. selects the Projects tab;
2. resets only the Projects path;
3. pushes `ProjectsRoute.project(id:)` when needed;
4. pushes `ProjectDetailsRoute.task(projectID:taskID:)` when needed.

Structurally valid unknown IDs are still routed. The destination screen shows
an unavailable state when lookup fails. A deep link never reads or mutates a
View directly.

## Snapshot Schema 3

`NavigationSnapshot.currentSchemaVersion` becomes `3` and adds the Projects
path.

Schema 3 stores independent path representations for:

- Home;
- Browse;
- Projects;
- Settings.

Authentication and all sheet state remain excluded.

Schema 2 is migrated instead of discarded:

- Home, Browse, and Settings paths are decoded with their existing schema-2
  representations;
- Projects starts with an empty path;
- the selected section is preserved;
- restoration returns a migration result that causes `SceneStorage` to persist
  a new schema-3 snapshot.

Schema 1 remains unsupported. Future schemas remain unsupported. Corruption in
one schema-3 flow resets only that flow where possible.

## Presentation Behavior

One-screen sheet enums conform to `Identifiable`, `Hashable`, and `Sendable`
where appropriate. They do not conform to `NavigationRoute` or `Codable`.

Each initiating View binds its ViewModel and presents with `.sheet(item:)`.
Interactive sheet dismissal clears the optional route through the binding.

Sheet content:

- owns its own ViewModel when it is a full user-facing screen;
- reads or mutates only explicitly injected feature state;
- calls `dismiss()` itself;
- does not receive `onCancel`, `onSave`, or navigation closures.

Only `CreateProjectFlowView` contains a navigation container inside a sheet.

## Validation and Failure Handling

- Empty or whitespace-only project titles do not advance from Basics.
- The validation message is local, display-safe, and cleared when valid input
  is submitted.
- Canceling the create-project sheet never inserts partial data.
- Unknown project and task IDs render `EmptyStateView`.
- Unknown related Browse IDs use the existing safe empty-detail behavior.
- Existing Browse service failures retain their retry and cancellation rules.
- Empty Router pops remain safe no-ops.
- Route switches remain exhaustive.
- No new force unwrap, forced cast, `fatalError`, or arbitrary `AnyView` is
  introduced.

## Testing Strategy

Implementation follows test-driven development.

### Unit tests

Tests cover:

- every new ViewModel navigation method pushing its screen-owned route;
- every initiating ViewModel opening and clearing its sheet enum;
- Authentication Help routing;
- Guide Topic routing;
- Browse related-content routing;
- Browse sort order and preference sharing;
- About platform routing;
- ProjectsStore project/task lookup and insertion;
- project title validation;
- draft preservation between create steps;
- cancel behavior leaving ProjectsStore unchanged;
- Review saving exactly one project;
- reuse of the same Projects Router through the push hierarchy.

### App navigation tests

Tests cover:

- `AppRouter` owning and retaining the injected Projects Router;
- independent Projects history;
- authentication and logout resetting Projects;
- project and task deep-link canonical paths;
- schema-3 mixed-route round trips;
- schema-2 to schema-3 migration;
- partial recovery of a corrupt Projects path;
- scene isolation with different Projects histories.

### Construction and UI checks

Construction tests instantiate every new Flow and screen with explicit
dependencies.

Simulator smoke checks cover:

- Authentication to Authentication Help and native back;
- Home to Guide Topic and Quick Start sheet dismissal;
- Browse to Related Items to Related Item Detail;
- Browse Options sheet changing sort order;
- Settings to Platform Details and Session Info sheet;
- Projects to Project Details to Task Details;
- Create Project Basics to Options to Review, save, dismiss, and open the new
  project;
- switching tabs while preserving each path;
- native back updating the bound Router path.

Full test suites run on:

- macOS 26;
- an iPhone simulator on iOS 26;
- an iPad simulator on iPadOS 26.

## Acceptance Criteria

- Authentication, Home, Browse, Projects, and Settings are independent flows.
- Each independent flow owns exactly one main Router and navigation container.
- The create-project sheet owns exactly one temporary Router and navigation
  container.
- Simple sheets contain no nested navigation container.
- Every outgoing push Route and destination mapping belongs to its screen.
- Every sheet route belongs to its initiating screen ViewModel.
- ViewModels receive `any IFlowRouter`, never navigation closures.
- Projects provides list, detail, task detail, info sheet, and create flow.
- Existing features contain the approved deeper push and sheet examples.
- Projects deep links build canonical mixed screen-owned paths.
- Schema-2 snapshots migrate to schema 3 without losing existing tab history.
- Sheets and drafts are never restored.
- All new full screens follow the required folder scaffold.
- Unit tests, app navigation tests, and cross-platform builds pass.
