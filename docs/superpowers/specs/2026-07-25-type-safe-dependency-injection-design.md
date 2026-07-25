# Type-Safe Dependency Injection Design

Date: 2026-07-25
Status: Approved for implementation planning

## Context

AppTemplate is a SwiftUI boilerplate for applications targeting iOS 26, iPadOS 26, and macOS 26. Navigation is already typed, restorable, deep-linkable, and scene-scoped. The next architectural layer is dependency injection (DI).

The current sample data crosses architectural boundaries:

- `AppRouter` constructs `SampleBrowseCatalog` and resolves Browse records while applying navigation intents.
- Navigation restoration filters routes by synchronously resolving records.
- `BrowseNavigationView` constructs the same sample catalog itself.
- `BrowseItemResolving` is synchronous, which does not generalize to network requests, actor-backed repositories, or asynchronous persistence.
- There is no composition root or explicit place to create future application services.

This design introduces the smallest useful DI foundation and uses it to integrate two representative dependencies: `BrowseRepository` and `SessionService`.

## Goals

- Make every production dependency originate from one application composition root.
- Preserve compile-time dependency requirements and concrete protocol contracts.
- Support app-wide services and independent state for every window scene.
- Work with actors, async network clients, persistence adapters, previews, and parallel tests.
- Remove data availability checks from routing and restoration.
- Keep feature dependencies explicit without passing app-wide UI state through every intermediate view.
- Provide clear `live`, `preview`, and `test` construction paths without mutable global overrides.
- Remain a small project pattern rather than becoming a general-purpose DI framework.

## Non-goals

- Build a runtime service registry or third-party DI framework.
- Introduce string keys, type-indexed dictionaries, reflection, or runtime casting.
- Add property-wrapper-based dependency lookup.
- Implement the future network stack or local database.
- Predefine services such as API clients, databases, clocks, analytics, or loggers before a feature needs them.
- Support changing dependency registrations after application startup.
- Make routers responsible for loading domain data.

## Research and Selected Approach

Apple's Observation and SwiftUI model-data guidance supports creating observable state at an owning boundary, passing feature state explicitly, and using typed SwiftUI environment values for genuinely shared observable state. Swift concurrency guidance supports `Sendable` service boundaries and actor-backed implementations.

Primary references:

- [SwiftUI model data](https://developer.apple.com/documentation/swiftui/model-data)
- [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [SwiftUI Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Data-race safety in the Swift 6 migration guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)

Three approaches were considered:

1. **Type-safe composition root with explicit feature injection and narrowly scoped SwiftUI Environment.** This is selected. It keeps domain services visible at feature boundaries while avoiding mechanical pass-through of shared session UI state.
2. **Initializer injection everywhere.** This offers maximum visibility but forces intermediate views to accept and forward dependencies they do not use.
3. **Typed SwiftUI Environment for all dependencies.** This reduces wiring but hides feature requirements and turns missing construction into runtime failures.

The selected approach is deliberately not a service locator. `AppDependencies` is an immutable value assembled at startup; consumers do not call `resolve()`.

## Architectural Overview

The dependency graph has three ownership levels:

```text
AppTemplateApp
└── App composition root
    ├── AppDependencies                         app-wide, immutable
    │   ├── BrowseRepository                    app-wide service
    │   └── SessionService                      app-wide service
    ├── SessionStore                            app-wide observable state
    └── WindowGroup
        └── AppSceneView                        one instance per window
            ├── AppSceneNavigationLifecycle
            │   └── AppRouter                   scene-scoped state
            └── Feature views
                ├── BrowseListStore             feature-scoped state
                └── BrowseDetailStore           destination-scoped state
```

`AppTemplateApp` creates the live dependency graph once. Every window receives the shared app dependencies and session store, but constructs its own navigation lifecycle and router. Consequently:

- authentication state is consistent across windows;
- navigation history and pending navigation intent remain independent per window;
- repositories may safely share caches and persistence resources;
- feature presentation state is not leaked between windows.

## Dependency Container and Construction

`AppDependencies` is a value with required, typed fields:

- `browseRepository: any BrowseRepository`
- `sessionService: any SessionService`

It has no optional production dependencies, mutable registrations, subscript lookup, or `resolve` API.

Construction paths are explicit:

- `AppDependencies.live()` creates production implementations.
- `AppDependencies.preview(...)` creates deterministic preview implementations.
- `AppDependencies.test(...)` requires test implementations from the caller.

The current graph can be created synchronously. If a later database requires asynchronous or throwing initialization, construction will move behind an explicit bootstrap state with `loading`, `ready`, and `failed` cases plus retry. It must not silently substitute sample data or terminate with `fatalError`.

Because networking and persistence are outside this increment, `live()` explicitly selects actor-backed in-memory Browse and session services for the runnable template. This is the declared live graph, not a fallback taken after a failure. A product replaces those two construction expressions when its real infrastructure arrives.

Sample Browse records remain useful as fixtures inside that in-memory repository and the preview/test graphs. Views and routers never construct fixtures.

## Service Contracts and Concurrency

Service protocols are explicitly non-main-actor and `Sendable` so actors and safe network or persistence clients can conform:

```swift
nonisolated protocol BrowseRepository: Sendable {
    func items() async throws -> [BrowseItem]
    func item(id: BrowseItem.ID) async throws -> BrowseItem?
}

nonisolated protocol SessionService: Sendable {
    func currentSession() async throws -> UserSession?
    func signIn() async throws -> UserSession
    func signOut() async throws
}
```

The precise sign-in arguments are intentionally absent from the boilerplate sample. A product can replace the sample operation with credentials, passkeys, OAuth, or another domain-specific request without changing the DI architecture.

The supplied mutable in-memory services are actors. Immutable fixture implementations may be `Sendable` structs.

SwiftUI-facing stores are `@MainActor @Observable`:

- `SessionStore` calls `SessionService` and owns application session presentation state.
- `BrowseListStore` calls `BrowseRepository.items()`.
- `BrowseDetailStore` owns one stable item ID and calls `BrowseRepository.item(id:)`.

This boundary keeps UI mutations on the main actor while allowing service work outside it. Stores expose semantic actions and state; views do not launch repository calls directly.

## SwiftUI Injection Boundaries

`SessionStore` is inserted once with typed SwiftUI Environment because it represents cross-cutting observable UI state used by authentication, settings, and scene roots. The environment contains the store, not the raw `SessionService`.

Browse dependencies stay explicit:

- `AppSceneView` receives `AppDependencies`.
- `AppShellView` passes `browseRepository` into the Browse feature root.
- The Browse root constructs its list store.
- A Browse destination constructs a detail store from its route ID and the same repository.

Intermediate views that do not participate in Browse do not receive Browse dependencies. Feature views cannot reach into a global container.

Stores are owned with SwiftUI state at the lowest stable feature boundary. Re-evaluation of a view must not recreate an in-flight store or task.

## Navigation and Data Flow

Navigation routes continue to contain only stable identifiers. Data resolution moves entirely into feature stores.

Opening a Browse item follows this sequence:

1. A link, deep link, restored snapshot, or user action produces `.browseItem(id:)`.
2. `AppRouter` selects Browse and writes `.item(id:)` to the typed path immediately.
3. The destination creates `BrowseDetailStore` with that ID and the injected repository.
4. The store transitions from `idle` to `loading`.
5. The repository returns an item, returns `nil`, or throws.
6. The store publishes `content`, `notFound`, or `failed`.
7. The destination renders that state and exposes retry for recoverable failures.

`AppRouter` no longer accepts or creates `BrowseItemResolving`. A syntactically valid route is applied regardless of current network or database availability.

Restoration validates only snapshot encoding, schema version, and route structure. It does not perform I/O and does not remove well-formed routes merely because a record is currently unavailable. This decision supersedes the previous navigation design's record-resolution and pruning requirement. An unavailable restored item remains at its stable route and renders `notFound`.

Malformed URLs still use the existing contextual navigation fallback. A well-formed Browse URL with an unknown ID is not malformed and therefore opens the detail destination.

## Session and Root-Flow Coordination

`SessionStore` is the source of truth for session loading, authenticated, unauthenticated, and failure states. `SessionService` contains the non-UI session operations.

Each scene observes the shared session state and maps it to its scene-local `AppRouter.flow`:

- session loading maps to `.launching`;
- no authenticated session maps to `.authentication`;
- an authenticated session maps to `.main`;
- successful authentication replays that scene's pending navigation intent;
- cancellation clears only that scene's pending intent;
- sign-out moves every active scene to authentication while preserving the fact that their routers are independent.

The sample authentication screen calls `SessionStore` rather than directly declaring authentication successful on the router. This avoids two competing sources of authentication truth.

Session startup is idempotent so multiple windows cannot trigger duplicate restoration work.

## Store State and Error Handling

Browse list and detail stores model explicit state rather than separate, potentially contradictory booleans.

Detail state includes:

- `idle`
- `loading`
- `content(BrowseItem)`
- `notFound`
- `failed` with display-safe error information

List state follows the same pattern without `notFound`.

Required behavior:

- `CancellationError` is not presented as a failure.
- Leaving a destination cancels work owned only by that destination.
- Reloading or changing an ID prevents a stale response from replacing newer state.
- Recoverable repository failures expose retry.
- Production never falls back silently to preview fixtures.
- Raw credentials, tokens, and sensitive server responses are not stored in display errors or logs.

Session errors remain in `SessionStore`; repository errors remain in Browse stores; URL parsing and snapshot decoding errors remain in navigation. Error ownership therefore matches the component capable of recovery.

## Testing Strategy

Tests inject dependencies directly and never alter process-global state.

Test implementations include:

- an actor-backed `InMemoryBrowseRepository`;
- a controllable `StubSessionService`;
- explicit fixtures for successful, missing, failing, delayed, and cancelled results.

Coverage includes:

- `AppDependencies.live`, `preview`, and `test` construct the intended implementations without hidden fallback;
- Browse list loading succeeds and fails predictably;
- Browse detail produces `content`, `notFound`, and `failed`;
- stale or cancelled detail requests do not overwrite current state;
- `SessionStore` restores, signs in, signs out, and exposes failure states;
- two scenes share session state but keep independent routers;
- deep links immediately create routes without repository access;
- restoration preserves structurally valid unknown Browse IDs;
- corrupt data and unsupported schema versions still reset safely;
- preview and test factories never contact production services.

Because no mutable override registry exists, test suites remain parallel-safe and do not need a global `resetDependencies()` teardown.

## Planned Code Boundaries

The implementation will use focused files:

- `App/Dependencies/AppDependencies.swift`
- `App/Session/SessionStore.swift`
- `Core/Session/SessionService.swift`
- `Features/Browse/Domain/BrowseRepository.swift`
- `Features/Browse/Data/InMemoryBrowseRepository.swift`
- `Features/Browse/Presentation/BrowseListStore.swift`
- `Features/Browse/Presentation/BrowseDetailStore.swift`

Existing navigation and Browse files will be changed only where needed to remove resolver coupling and wire explicit dependencies. Shared abstractions will not be extracted until at least two concrete consumers require them.

## Acceptance Criteria

- The app builds and tests on the existing iOS/iPadOS 26 and macOS 26 targets.
- A single app composition root creates all live services.
- Every window receives shared services and session state but owns an independent router.
- Required feature dependencies are visible in initializers.
- No runtime registration, `resolve`, global override, force cast, or string key exists.
- `SampleBrowseCatalog` is no longer constructed by a router or view.
- Browse list and detail data are loaded asynchronously through `BrowseRepository`.
- Well-formed deep links and snapshots route immediately by ID without data lookup.
- Missing Browse records render `notFound` rather than rewriting the navigation path.
- `SessionStore` drives root authentication flow through `SessionService`.
- Preview and test dependency graphs are explicit and cannot reach live services accidentally.
- Store, session, deep-link, restoration, and multi-scene lifetime behavior have deterministic tests.
