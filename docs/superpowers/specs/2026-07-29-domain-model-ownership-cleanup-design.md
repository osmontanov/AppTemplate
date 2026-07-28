# Domain Model Ownership Cleanup Design

## Goal

Align `App/Models/Domain` with the current role-based model rules:

- Domain contains only shared business entities;
- State contains shared application state;
- Local contains local query and persistence models;
- Remote contains transport request and response models;
- a screen owns presentation models used only by that screen.

This is an ownership cleanup. It must not change runtime behavior, navigation,
dependency injection, services, presentation content, or supported platforms.

## Current Problem

`App/Models/Domain` currently mixes three different categories:

- shared business entities: `BrowseItem` and `UserSession`;
- a screen-specific presentation item: `NavigationGuideItem`;
- unused scaffold placeholders: `AuthenticationModel`, `HomeModel`, and
  `SettingsModel`.

The placeholders were introduced by an earlier feature-scaffold design and
later moved into the centralized Domain folder. The later Local, Remote, and
State classification work did not revisit them. The README still reflects the
old broad rule that Domain owns both shared application and presentation
models.

## Target Structure

```text
AppTemplate/
├── App/
│   └── Models/
│       ├── Domain/
│       │   ├── BrowseItem.swift
│       │   └── UserSession.swift
│       ├── Local/
│       ├── Remote/
│       └── State/
└── Features/
    └── Home/
        └── Screens/
            └── NavigationGuide/
                ├── Model/
                │   └── NavigationGuideItem.swift
                ├── View/
                └── ViewModel/
```

No empty `Model` folders or placeholder types are added to other screens.
A screen-level Model folder is created only when a real screen-owned value
exists.

## Domain Ownership

`BrowseItem` remains in `App/Models/Domain` because it is a shared business
entity consumed by the Browse service, Browse screens, state models, typed
routes, application composition, previews, and tests.

`UserSession` remains in `App/Models/Domain` because it is a shared business
entity consumed by the Session service, `SessionStore`, authentication and
settings screens, application state, composition, and tests.

Both declarations and their conformances remain unchanged. This cleanup does
not reconsider their `Codable`, `Identifiable`, `Hashable`, or `Equatable`
contracts.

## Screen-Owned Presentation Model

Move `NavigationGuideItem.swift` to:

```text
Features/Home/Screens/NavigationGuide/Model/NavigationGuideItem.swift
```

The type name, stored properties, conformances, and access level remain
unchanged. The move changes ownership only.

`NavigationGuideItem` belongs to the screen because:

- only `NavigationGuideViewModel` creates or consumes it;
- its `systemImage` property is presentation-specific;
- no service, shared state, navigation route, or other feature depends on it.

The ViewModel continues to construct the same three items, so the screen's
data flow and rendered content do not change.

## Placeholder Removal

Delete:

- `App/Models/Domain/AuthenticationModel.swift`;
- `App/Models/Domain/HomeModel.swift`;
- `App/Models/Domain/SettingsModel.swift`.

These types contain no state or behavior and have no consumers. They are not
replaced with screen-specific empty structs. Reserved extension points should
be folders or documentation until a real value with a clear responsibility
exists.

## Documentation

Update the README model ownership section to state:

- `App/Models/Domain` owns shared business entities;
- `App/Models/State` owns shared application state;
- `App/Models/Local` owns local queries and persisted records;
- `App/Models/Remote` owns transport requests and responses;
- `Features/<Feature>/Screens/<Screen>/Model` owns presentation models used
  only by that screen.

The new rule supersedes the broad Domain ownership wording in earlier
architecture documents. Historical specs remain unchanged as records of the
decisions that produced the current structure.

## Xcode Integration

The project uses file-system-synchronized groups. Moving and deleting these
Swift files must not add manual file references or intentionally change
`AppTemplate.xcodeproj/project.pbxproj`.

Git should recognize `NavigationGuideItem.swift` as a move because its contents
remain unchanged.

## Testing

No new unit test is added:

- the three deleted placeholders have no behavior;
- the moved item has no behavioral change;
- a source-location or symbol-absence test would be a brittle change detector.

Validation consists of:

- confirming the three placeholder symbols have no remaining declarations or
  references;
- confirming `NavigationGuideItem` exists only in its screen-owned location;
- confirming Domain contains only `BrowseItem` and `UserSession`;
- confirming `project.pbxproj` has no intentional diff;
- running the full macOS test suite;
- running the full iOS 26.5 Simulator test suite, which compiles the shared
  iPhone and iPad target.

## Alternatives Considered

Keeping the empty placeholders in Domain was rejected because their names do
not describe business concepts and their declarations provide no extension
behavior.

Moving all Domain models into features was rejected because `BrowseItem` and
`UserSession` cross feature, service, state, navigation, and composition
boundaries.

Keeping `NavigationGuideItem` in Domain was rejected because it is not shared
and exposes presentation-specific data.

Creating an empty Model type for every screen was rejected because it would
recreate the same unused placeholders under a different path.

## Validation

The implementation is complete when:

- Domain contains only `BrowseItem.swift` and `UserSession.swift`;
- `NavigationGuideItem.swift` is owned by the NavigationGuide screen and its
  declaration is unchanged;
- `AuthenticationModel`, `HomeModel`, and `SettingsModel` no longer exist;
- README documents the current role-based ownership rules;
- no runtime code or Xcode project configuration changes;
- full macOS and iOS test suites pass.
