# State Model Folder Design

## Goal

Add a dedicated `App/Models/State` folder for shared application state
models. This keeps state representations separate from domain entities,
network DTOs, local database records, services, and navigation internals.

## Folder Structure

```text
App/Models/
├── Domain/
├── Local/
├── Remote/
└── State/
    ├── LoadableState.swift
    ├── BrowseState.swift
    └── SessionState.swift
```

No feature-specific subfolders will be added under `State` yet. The current
number of state files does not justify another level of nesting.

## Ownership

`LoadableState.swift` owns:

```swift
nonisolated enum LoadableState<
    Content: Equatable & Sendable,
    Failure: Equatable & Sendable
>: Equatable, Sendable {
    case idle
    case loading
    case content(Content)
    case empty
    case failed(Failure)
}
```

The name is intentionally specific. A generic type named `State` would be
easy to confuse with SwiftUI's `@State` property wrapper. `LoadableState`
describes the exact lifecycle represented by the enum.

`BrowseState.swift` owns:

- `BrowseFailure`
- `BrowseListState`, as an alias for
  `LoadableState<[BrowseItem], BrowseFailure>`
- `BrowseDetailState`, as an alias for
  `LoadableState<BrowseItem, BrowseFailure>`

`SessionState.swift` owns:

- `SessionPhase`
- `SessionFailure`

`SessionStore` remains in `App/Services/Session`. It owns mutable,
main-actor-isolated session behavior, while `SessionState.swift` contains
only the immutable, sendable values that describe that behavior.

`NavigationRestorationFailure` remains in `App/Navigation/Snapshots`.
It is a navigation restoration implementation detail rather than shared
application state.

`SessionPhase` does not use `LoadableState`. Authentication has meaningful
business states such as `authenticated` and `unauthenticated` that cannot be
represented accurately as generic loading states.

## State Transitions

Browse list and detail view models continue to publish `.idle`, `.loading`,
`.content`, and `.failed`. They additionally use `.empty` when no content is
available:

- the list publishes `.empty` when the service returns an empty collection;
- the detail screen publishes `.empty` when the requested item does not
  exist.

Each screen remains responsible for rendering `.empty` with screen-specific
copy. The generic model contains no UI strings and no feature behavior.

## Migration

1. Move the Browse state declarations from
   `App/Models/Domain/BrowseStoreState.swift` to
   `App/Models/State/BrowseState.swift`.
2. Add the reusable generic state to
   `App/Models/State/LoadableState.swift`.
3. Replace the concrete Browse list and detail enums with type aliases for
   `LoadableState`.
4. Update Browse view models and views to use `.empty` instead of the
   detail-only `.notFound` case and to represent an empty list explicitly.
5. Extract `SessionPhase` and `SessionFailure` from
   `App/Services/Session/SessionStore.swift` into
   `App/Models/State/SessionState.swift`.
6. Delete the obsolete `BrowseStoreState.swift` path after the move.

Existing Browse state type names, failure typing, conformances, and access
levels remain unchanged. The only intentional state change is replacing
`BrowseDetailState.notFound` with the reusable `.empty` case and explicitly
representing an empty Browse list. Because the Xcode project uses
synchronized filesystem groups, the new Swift files do not require manual
project-file membership edits.

## Concurrency

State models remain `nonisolated`, `Equatable`, and `Sendable`.
`LoadableState` requires both generic arguments to conform to `Equatable`
and `Sendable`, preserving those guarantees for every specialization. State
models are plain values that can cross service-actor and main-actor
boundaries. Mutable UI-observed owners such as `SessionStore` and Browse
view models remain `@MainActor`.

## Alternatives Considered

Keeping `LoadableState` only as an unused template was rejected because the
boilerplate should demonstrate its recommended abstractions in real feature
code.

Keeping separate concrete Browse enums was rejected because their common
loading lifecycle would remain duplicated. Feature-specific state enums
remain appropriate when a future screen has states that do not fit the
generic lifecycle.

## Validation

The implementation is complete when:

- all shared Browse and Session state declarations exist only under
  `App/Models/State`;
- Browse list and detail states are aliases of `LoadableState`;
- list-empty and detail-not-found results publish `.empty`;
- the old declarations and path no longer exist;
- `SessionPhase` remains a dedicated business-state enum;
- the full macOS and iOS test suites pass.
