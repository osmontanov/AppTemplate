# Reusable SwiftUI UI Components Design

**Status:** Approved

**Date:** 2026-07-29

## Context

`Utilities/UIComponents` is documented as the home of reusable UI that is
independent from screens. It currently contains four unused extension-point
types:

- `AuthenticationComponents`
- `BrowseComponents`
- `HomeComponents`
- `SettingsComponents`

These types are empty `Sendable` structs. They do not conform to `View`, render
nothing, and have no consumers. Their feature-oriented names also suggest
ownership that conflicts with a shared reusable-components folder.

The project already repeats three screen-level SwiftUI states that make useful
shared examples: loading, empty or unavailable content, and retryable failure.

## Goals

- Ensure every Swift type in `Utilities/UIComponents` is a real SwiftUI
  `View`.
- Replace the four empty extension points with small reusable components.
- Adopt the components in existing screens so the examples are production
  code rather than unused scaffolding.
- Keep each component independent from screens, ViewModels, navigation,
  dependency injection, services, and feature dependency scopes.
- Preserve current presentation and runtime behavior on iOS 26, iPadOS 26,
  and macOS 26.

## Non-Goals

- Do not create a marker protocol such as `UIComponent`.
- Do not introduce a generic state container or a design-system abstraction.
- Do not move screen-specific controls into `Utilities/UIComponents`.
- Do not replace compact inline progress indicators that are not whole-screen
  states.
- Do not add external dependencies, view-inspection libraries, or snapshot
  infrastructure.
- Do not modify navigation, ViewModels, services, DI, models, or supported
  platforms.

## Ownership Rule

`Utilities/UIComponents` contains only reusable SwiftUI `View` types that are
independent from screens.

A component in this folder may accept:

- strings and other plain values;
- bindings when a future component genuinely needs two-way value flow;
- callbacks for user intent.

A component in this folder must not depend on:

- a screen `View` or `ViewModel`;
- a feature `Router` or `Route`;
- `AppDependencies` or a feature dependency scope;
- a service or repository;
- a feature-specific model when plain presentation values are sufficient.

The README ownership summary becomes the current authoritative statement of
this rule. Historical specifications and plans remain unchanged.

## Component Catalog

Each component lives in its own Swift file, imports SwiftUI, conforms directly
to `View`, and includes an isolated `#Preview`.

### `LoadingStateView`

Purpose: render a labeled, whole-screen loading state.

Inputs:

```swift
let title: String
```

Rendering:

```swift
ProgressView(title)
```

This component contains no task management. The consuming screen remains
responsible for starting, cancelling, and retrying asynchronous work.

### `EmptyStateView`

Purpose: render empty, missing, or otherwise unavailable content without a
recovery action.

Inputs:

```swift
let title: String
let systemImage: String
let message: String
```

Rendering uses the system `ContentUnavailableView` initializer with a title,
SF Symbol name, and description. The component owns presentation only.

### `ErrorStateView`

Purpose: render a retryable failure with a consistent system presentation.

Inputs:

```swift
let title: String
let message: String
let retry: () -> Void
```

Rendering uses:

- `ContentUnavailableView`;
- the `exclamationmark.triangle` system image;
- a `Retry` button that invokes `retry`.

The component does not interpret errors, start a `Task`, or own retry state.
The screen supplies an already display-safe message and handles the callback.

## Screen Adoption

### Browse list

`BrowseNavigationView` uses:

- `LoadingStateView` for `.idle` and `.loading`;
- `EmptyStateView` for `.empty`;
- `ErrorStateView` for `.failed`.

The existing titles, descriptions, SF Symbols, and retry behavior remain
unchanged.

### Browse detail

`BrowseDetailView` uses:

- `LoadingStateView` for `.idle` and `.loading`;
- `EmptyStateView` for `.empty`;
- `ErrorStateView` for `.failed`.

The content form and navigation title remain screen-owned and unchanged.

### Home details

`HomeDetailsView` uses `EmptyStateView` with the existing title, system image,
and message exposed by `HomeDetailsViewModel`.

### Deliberately unchanged screens

- `SettingsNavigationView` retains its compact inline `ProgressView` because
  it represents one list row rather than the whole screen.
- `AuthenticationView` retains its inline failure text and action row because
  that composition is screen-specific.
- Other screens have no matching repeated state presentation.

## Files

Create:

- `AppTemplate/Utilities/UIComponents/LoadingStateView.swift`
- `AppTemplate/Utilities/UIComponents/EmptyStateView.swift`
- `AppTemplate/Utilities/UIComponents/ErrorStateView.swift`

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

Do not intentionally modify:

- `AppTemplate.xcodeproj/project.pbxproj`;
- any file under historical `docs/superpowers/specs` or
  `docs/superpowers/plans`;
- any unrelated in-progress user change.

## Data and Action Flow

The existing ViewModel remains the source of screen state:

```text
ViewModel state
    -> screen switch
        -> plain presentation values
            -> reusable View
```

Retry flows in the opposite direction as user intent:

```text
Retry button
    -> retry callback
        -> screen-owned ViewModel.retry()
```

No reusable component reads application state or resolves dependencies.

## Error Handling

`ErrorStateView` accepts only a display-safe `String`. Error conversion and
privacy decisions remain outside the component, in the existing presentation
layer. Invoking Retry delegates synchronously to the screen; the component
does not assume whether the subsequent operation is synchronous or
asynchronous.

## Accessibility and Platform Behavior

The design relies on native `ProgressView`, `ContentUnavailableView`, `Label`,
and `Button` semantics. It uses no platform branches and no device-specific
layout, so the same implementation serves iPhone, iPad, and Mac targets.

## Verification

No new initializer, getter, source-location, or snapshot tests are added. The
components contain no business logic, and such tests would only restate
SwiftUI declarations.

Verification must confirm:

- the four empty extension-point declarations are absent;
- the three new component files each declare a type conforming to `View`;
- no Swift type under `Utilities/UIComponents` is a model, helper, service,
  router, dependency scope, or empty placeholder;
- Browse list, Browse detail, and Home details use the shared components with
  unchanged presentation values and callbacks;
- the existing full macOS test suite passes;
- the existing full iOS Simulator suite passes;
- the shared iOS target remains compatible with both iPhone and iPad device
  families;
- `AppTemplate.xcodeproj/project.pbxproj` receives no intentional diff;
- unrelated in-progress user changes remain untouched.

## Accepted Trade-off

The folder rule is architectural rather than compiler-enforced. A marker
protocol would add ceremony without preventing a future contributor from
placing an unrelated type in the directory. Direct `View` conformance,
one-type-per-file organization, README documentation, and review-time
structural checks keep the rule explicit without adding an abstraction that
has no runtime purpose.
