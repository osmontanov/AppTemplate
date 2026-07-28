# Neutral Local and Remote Model Examples Design

## Goal

Replace the reserved `.gitkeep` files in `App/Models/Local` and
`App/Models/Remote` with small, concrete examples that demonstrate how data
models are classified in the boilerplate.

The examples are intentionally unrelated to each other and to existing app
features. They teach folder ownership and serialization boundaries without
introducing fake production flows.

## Folder Structure

```text
App/Models/
├── Local/
│   ├── ExampleQuery.swift
│   └── ExampleRecord.swift
└── Remote/
    ├── ExampleRequest.swift
    └── ExampleResponse.swift
```

The `.gitkeep` file in each folder will be removed after real Swift files
exist. The Xcode project uses synchronized filesystem groups, so these files
must not be added to `project.pbxproj` manually.

## Remote Models

`ExampleRequest.swift` defines:

```swift
nonisolated struct ExampleRequest: Encodable, Equatable, Sendable {
    let query: String
    let page: Int
}
```

This is an outgoing transport model. `Encodable` is sufficient because the
example only demonstrates converting a request value into a remote payload.

`ExampleResponse.swift` defines:

```swift
nonisolated struct ExampleResponse: Decodable, Equatable, Sendable {
    let id: String
    let title: String
}
```

This is an incoming transport model. `Decodable` is sufficient because the
example only demonstrates constructing a response value from a remote
payload.

The request and response do not reference each other and do not imply an
endpoint or a request-response workflow.

## Local Models

`ExampleQuery.swift` defines:

```swift
nonisolated struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let limit: Int
}
```

This model represents local lookup criteria. It is not `Codable` because
query criteria are runtime input rather than persisted data.

`ExampleRecord.swift` defines:

```swift
nonisolated struct ExampleRecord: Codable, Equatable, Sendable {
    let id: String
    let payload: String
}
```

This model represents a locally persistable record. `Codable` demonstrates
that the same value can be written to and restored from local storage.

The query and record do not reference each other and do not imply a database
implementation or a query-result workflow.

## Boundaries

All four examples are immutable value types. They use only Swift standard
library types and have no dependencies on:

- domain models;
- state models;
- services or dependency injection;
- view models or views;
- navigation;
- one another.

No protocols, generic base models, mappers, conversion initializers, or
service methods will be introduced. No existing application behavior will
change.

`nonisolated` makes the declarations available independently of the
project's default actor isolation. `Sendable` makes the values safe to move
across actor boundaries. `Equatable` keeps comparisons and tests simple.

## Testing

Add focused tests under matching model folders:

```text
AppTemplateTests/App/Models/
├── Local/
│   └── ExampleLocalModelTests.swift
└── Remote/
    └── ExampleRemoteModelTests.swift
```

Remote tests will:

- encode `ExampleRequest` and verify the resulting JSON fields;
- decode literal JSON into `ExampleResponse` and verify the result.

Local tests will:

- encode and decode `ExampleRecord`, verifying a complete persistence
  round trip;
- verify that `ExampleQuery` preserves optional and non-optional criteria.

These tests exercise the intended serialization boundaries rather than
connecting the examples to app features.

## Alternatives Considered

Empty structs were rejected because they would reserve filenames without
teaching how the models are intended to be used.

Generic request, response, query, or record abstractions were rejected
because four independent examples do not establish a reusable abstraction.

Connecting the models to Browse or another existing feature was rejected
because the requested examples must remain neutral and non-relatable.

## Validation

The implementation is complete when:

- both reserved `.gitkeep` files are removed;
- the four example models exist in their intended folders with the specified
  conformances;
- none of the example models references another example or existing app
  type;
- the focused Local and Remote model tests pass;
- the full macOS and iOS test suites pass;
- `project.pbxproj` has no intentional changes.
