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
    ├── BrowseState.swift
    └── SessionState.swift
```

No feature-specific subfolders will be added under `State` yet. The current
number of state files does not justify another level of nesting.

## Ownership

`BrowseState.swift` owns:

- `BrowseFailure`
- `BrowseListState`
- `BrowseDetailState`

`SessionState.swift` owns:

- `SessionPhase`
- `SessionFailure`

`SessionStore` remains in `App/Services/Session`. It owns mutable,
main-actor-isolated session behavior, while `SessionState.swift` contains
only the immutable, sendable values that describe that behavior.

`NavigationRestorationFailure` remains in `App/Navigation/Snapshots`.
It is a navigation restoration implementation detail rather than shared
application state.

## Migration

1. Move the Browse state declarations from
   `App/Models/Domain/BrowseStoreState.swift` to
   `App/Models/State/BrowseState.swift`.
2. Extract `SessionPhase` and `SessionFailure` from
   `App/Services/Session/SessionStore.swift` into
   `App/Models/State/SessionState.swift`.
3. Delete the obsolete `BrowseStoreState.swift` path after the move.

Type names, cases, conformances, access levels, and runtime behavior remain
unchanged. Because the Xcode project uses synchronized filesystem groups,
the new Swift files do not require manual project-file membership edits.

## Concurrency

State models remain `nonisolated`, `Equatable`, and `Sendable`. They are
plain values that can cross service-actor and main-actor boundaries.
Mutable UI-observed owners such as `SessionStore` and Browse view models
remain `@MainActor`.

## Validation

The implementation is complete when:

- all shared Browse and Session state declarations exist only under
  `App/Models/State`;
- the old declarations and path no longer exist;
- no production references require API changes;
- the full macOS and iOS test suites pass.
