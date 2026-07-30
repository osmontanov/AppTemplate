# Navigation-Only App Shell Design

Date: 2026-07-30

## Goal

Turn AppTemplate into a navigation-first boilerplate. The application keeps
its screens, screen ViewModels, typed routes, root flows, sheets, alerts, and
dialogs, but contains no real session, network, persistence, loading, project,
or other business behavior.

The only services retained by the application dependency graph are two empty
examples:

- `ILocalDatabaseService` with `LocalDatabaseService`;
- `IRemoteService` with `RemoteService`.

They demonstrate protocol-based dependency injection without prescribing a
database or networking implementation.

## Design Principles

1. Navigation is functional; product behavior is illustrative.
2. Views render static content and bind presentation state.
3. ViewModels coordinate only typed navigation and presentation.
4. No screen or ViewModel loads, saves, searches, sorts, validates, retries,
   authenticates, or owns domain data.
5. Sheets, alerts, confirmation dialogs, and root-flow transitions remain
   working examples.
6. Existing feature and screen folder scaffolds remain, even when their model,
   state, dependency, or route types are empty.
7. Passive model examples may remain, but they must not drive runtime business
   behavior.

## Dependency Graph

`AppDependencies` becomes the complete immutable dependency graph:

```swift
nonisolated
struct AppDependencies: Sendable {
    let localDatabase: any ILocalDatabaseService
    let remote: any IRemoteService
}
```

The protocols and implementations intentionally have no requirements:

```swift
nonisolated
protocol ILocalDatabaseService: Sendable {}

actor LocalDatabaseService: ILocalDatabaseService {}

nonisolated
protocol IRemoteService: Sendable {}

actor RemoteService: IRemoteService {}
```

`AppDependencies.live()` creates the two concrete actors. Preview and test
factories accept injected protocol implementations so the custom DI pattern
remains visible and compile-tested.

The composition root constructs the graph. No feature consumes either example
service yet. This is intentional: a future project adds protocol requirements
and explicitly passes only the dependency required by a feature.

Empty feature dependency structs remain as folder scaffolds, but contain no
service, store, or runtime state.

## Removed Runtime Logic

The following active infrastructure is removed:

- `SessionService`, `ISessionService`, `SessionDependencies`, and
  `SessionStore`;
- `BrowseService`, `IBrowseService`, and service-backed
  `BrowseDependencies`;
- `ProjectsStore`, `ProjectsStoreError`, and mutable project persistence;
- `CreateProjectDraftState` and create/save/validation behavior;
- `BrowsePreferencesStore`, Browse failures, loading tasks, cancellation,
  retries, sorting, and service lookup;
- async sign-in, sign-out, restoration, retry, and session failure handling;
- feature code that receives a service, store, or data dependency.

Service/store-specific tests and doubles are deleted with their production
types.

## Root Flows

The application starts directly in `.authentication`. The transient
`.launching` flow and session synchronization are removed because there is no
session restoration.

The retained root flows are:

- `.authentication`;
- `.onboarding`;
- `.main`;
- `.maintenance`.

`AppFlowRouter.setFlow(_:)` remains the only way to replace the application
root:

- `.main` resets scene histories and replays the receiving scene's pending deep
  link;
- any non-main root resets scene histories and discards older pending intent;
- requesting the already visible flow still publishes a fresh reset
  transition.

Authentication is explicitly a navigation demonstration rather than real
identity state:

- Authentication `Continue` calls `router.setFlow(.main)`;
- Settings `Sign Out` calls `router.setFlow(.authentication)`.

Deep links received while the root is not `.main` remain scene-local and
deferred. Authentication `Continue` switches to `.main`, allowing the exact
receiving scene to replay its pending destination.

## ViewModel Contract

Every screen keeps its own ViewModel, including screens whose ViewModel has no
current behavior.

A screen ViewModel may contain only:

- an `any IRouter` when the screen navigates;
- route identifiers required to construct a destination;
- sheet, alert, or dialog route state;
- methods that push, pop, reset, or replace a root flow;
- methods that present or dismiss sheet, alert, or dialog state.

A screen ViewModel must not contain:

- a service, store, repository, dependency graph, or environment lookup;
- async loading or mutation tasks;
- loading, failure, retry, cancellation, or version-tracking state;
- sorting, filtering, lookup, validation, save, session, or persistence logic;
- mutable domain collections or draft data.

## Feature Behavior

### Authentication

The initial screen renders static explanatory content. `Continue` opens
`.main`; Help remains a typed push destination; cancellation remains a fresh
Authentication root transition.

### Home

Existing navigation examples remain:

- Details and Navigation Guide typed pushes;
- Quick Start sheet;
- navigation-reset alert;
- Onboarding and Maintenance root transitions.

Presentation and navigation are the only Home ViewModel responsibilities.

### Browse

Browse screens render static example rows and text. The rows use stable sample
identifiers only to demonstrate typed paths and deep links. Options remains a
sheet, and detail/related-item screens remain typed destinations.

There is no service, loading lifecycle, retry, sorting preference, or record
lookup. A detail screen may display the identifier it received, but does not
resolve it through data storage.

### Projects

Projects screens render static navigation examples using stable sample
identifiers. Project, task, and project-info destinations remain.

Create Project remains an independent sheet flow with its own local
`FlowRouter`, but has no draft, validation, store, or save behavior. Its screens
demonstrate the Basics → Options → Review route sequence, and the final action
dismisses the containing sheet.

### Settings

About, Platform Details, and Session Info remain. Session Info becomes static
template content. The existing sheet stays operational. `Sign Out` changes the
root to Authentication without calling a session service.

### Onboarding and Maintenance

Both remain navigation-only root-flow examples and return to `.main`.

## Models and Screen Scaffolds

The folder convention for every screen remains:

- `Model`;
- `Navigation`;
- `State`;
- `View`;
- `ViewModel`.

Empty or passive Model and State declarations remain to show the intended
project structure. Generic `LoadableState`, Local/Remote example models, and
passive Domain Item types may remain as architecture examples, but active
screens do not use them for business behavior.

Routes use stable identifiers and remain screen-owned. No destination is
moved into a shared central route enum.

## UI and Presentation

The refactor does not remove:

- sheets;
- alerts;
- confirmation dialogs;
- toolbars;
- typed `navigationDestination` mappings;
- root-flow buttons;
- reusable UI components.

Static content uses native SwiftUI controls and existing independent UI
components. No custom design work is introduced.

## Testing

Tests are rewritten around the remaining responsibilities:

- construction of every flow and screen;
- local push/pop and typed destination behavior;
- sheet, alert, and dialog presentation/dismissal;
- root-flow replacement and repeated same-flow reset;
- independent scene paths and shared root flow;
- snapshot compatibility;
- pending deep-link deferral and exact replay;
- the two empty services satisfying their protocols;
- `AppDependencies` retaining injected Local and Remote services.

Tests for removed session concurrency, service loading, store mutation,
validation, retry, cancellation, sorting, lookup, or saving are deleted.

Structural guards must prove:

- only LocalDatabase and Remote service protocols/implementations remain;
- no feature references a `Service`, `Store`, repository, or
  `AppDependencies`;
- no feature ViewModel contains `async`, `Task`, `load`, `retry`, `save`,
  `signIn`, or `signOut` business operations;
- no `SessionStore`, `ProjectsStore`, `BrowseService`, or `SessionService`
  reference remains;
- `project.pbxproj` is unchanged;
- `nonisolated` remains on its own line.

The full macOS, iPhone, and iPad test suites must pass after the reduction.

## Acceptance Criteria

The work is complete when:

1. The app launches into Authentication and can reach every root flow.
2. All existing screen, sheet, alert, dialog, and typed-navigation examples
   remain constructible and usable.
3. Signed-out-style deep-link deferral and replay work without session
   infrastructure.
4. LocalDatabase and Remote are the only services in `AppDependencies`, and
   both are empty protocol/concrete examples.
5. No active business/data/session logic remains in Features.
6. Removed production types have no residual tests or references.
7. The architecture documentation describes the navigation-only scope.
8. Three-platform verification passes without modifying the Xcode project
   file.

## Out of Scope

- selecting a real networking library;
- choosing a local database;
- implementing authentication;
- loading or persisting Browse or Project data;
- adding new UI styling or product behavior;
- changing the established navigation ownership model.
