# Multiplatform Navigation Design

Date: 2026-07-24
Status: Approved for implementation planning

## Context

AppTemplate is a minimal SwiftUI boilerplate intended to become the foundation for multiple applications. Its first architectural subsystem is navigation. The application targets iPhone, iPad, and Mac on the current major Apple platform releases.

The existing Xcode project contains only an app entry point and a placeholder content view. It currently has iOS, macOS, and visionOS 26.5 deployment targets. The navigation implementation will instead support:

- iOS 26.0 and later
- iPadOS 26.0 and later
- macOS 26.0 and later

VisionOS is outside the agreed scope and will be removed from the supported platform settings.

## Goals

- Provide a native, adaptive navigation foundation suitable for many kinds of apps.
- Follow platform conventions without maintaining separate iPhone, iPad, and Mac navigation implementations.
- Make programmatic navigation, deep links, restoration, and authentication gates explicit and testable.
- Preserve independent navigation history for every top-level section.
- Keep feature navigation isolated so features can be added, removed, and tested independently.
- Avoid mandatory third-party navigation or application-architecture dependencies.
- Demonstrate the architecture with small, replaceable Home, Browse, and Settings features.

## Non-goals

- Implement production authentication, networking, or database behavior.
- Establish the visual design system for the eventual applications.
- Support operating systems earlier than version 26.
- Support visionOS, watchOS, or tvOS.
- Build a generic navigation framework intended for distribution as a package.
- Add The Composable Architecture, Swift Navigation, FlowStacks, or another routing dependency by default.

## Research and Decision

Apple's current guidance favors native, data-driven SwiftUI navigation:

- `TabView` with the `sidebarAdaptable` style provides a bottom tab bar on iPhone, an adaptable tab bar/sidebar on iPad, and a sidebar on Mac.
- `NavigationStack` provides value-driven push navigation and programmatic paths.
- `NavigationSplitView` provides two- or three-column navigation and automatically collapses in compact presentations.
- Codable route identifiers and scene storage support deep linking and state restoration.

Primary references:

- [Enhancing your app's content with tab navigation](https://developer.apple.com/documentation/swiftui/enhancing-your-app-content-with-tab-navigation)
- [Tab bars — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [The SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/)
- [Elevate the design of your iPad app](https://developer.apple.com/videos/play/wwdc2025/208/)

Three approaches were considered:

1. Native SwiftUI with typed navigation state. This is the selected approach because it follows the platform, has no dependency risk, and is sufficient for version-26-only applications.
2. Native SwiftUI plus [Point-Free Swift Navigation](https://github.com/pointfreeco/swift-navigation). This is a reasonable optional enhancement if a future application needs case-path bindings for complex enum-driven presentations.
3. A larger navigation or application framework such as [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) or [FlowStacks](https://github.com/johnpatrickmorgan/FlowStacks). These provide useful capabilities but impose conventions or compatibility machinery that is inappropriate for the default boilerplate.

## Navigation Structure

### Application shell

The main application experience uses `TabView` with `.sidebarAdaptable`:

- iPhone presents a bottom tab bar.
- iPad presents a tab bar that can adapt into a sidebar as space and user preference change.
- Mac presents a sidebar.

The initial replaceable sections are Home, Browse, and Settings. They exist to demonstrate the architecture rather than define a product domain.

Each top-level section owns an independent navigation model and stack. Switching sections must not reset another section's history. A feature whose information architecture is genuinely hierarchical can use a `NavigationSplitView` as the root of its section instead of forcing the entire application into a fixed split view.

### Scene ownership

Every window scene creates its own `AppRouter`. The router is never a process-wide singleton. This allows Mac and iPad windows to navigate and restore independently.

`AppRouter` owns only application-level navigation:

- Current `AppFlow`
- Selected top-level section
- Pending navigation intent, when one must wait for the current flow
- Child navigation models for Home, Browse, and Settings

Each feature view receives only its feature navigation model. It does not receive unrestricted access to the entire application router.

All mutable navigation models use Swift Observation and are isolated to `@MainActor`.

### Root flow

`AppFlow` models replacement of the application's root interface:

- `launching`
- `authentication`
- `main`

The navigation subsystem demonstrates these states without implementing a real authentication service. A future session service will determine the flow. Root-flow changes are state transitions rather than manual replacement of view-controller or window hierarchies.

### Typed routes

Every feature owns a `Hashable` and `Codable` route enum, such as `HomeRoute` or `BrowseRoute`. Its navigation path is a typed route array rather than a type-erased `NavigationPath`.

Routes store stable identifiers and small navigation parameters. They do not store complete database or network model objects. This provides:

- Compile-time checking of destination coverage
- Straightforward route equality in tests
- Predictable Codable restoration
- Protection from persisting stale model snapshots

SwiftUI destination construction remains in the feature's view layer. Routers store navigation state and operations; they do not become large view factories.

Destination modifiers are attached outside lazy containers such as `List`, `Table`, and lazy grids so the containing navigation stack can always discover them.

## Navigation Data Flow

Navigation uses one directional flow:

1. A user action, restored state, or incoming URL produces a typed navigation intent.
2. The relevant router validates and applies that intent.
3. Router state changes update the bound SwiftUI navigation container.
4. System back gestures and dismissals update the same bound state.

Features expose explicit operations such as push, pop, pop-to-root, replace-path, and dismiss. Application code does not mutate arbitrary `NavigationPath` values or parse URLs inside views.

## Presentations

Presentations belong to the feature that initiates them:

- Optional typed sheet routes drive sheets and popovers.
- Optional typed full-screen routes drive full-screen covers on iPhone or iPad only when that presentation is semantically appropriate.
- Optional typed alert routes drive alerts and confirmation dialogs.
- A presented flow that needs push navigation owns its own `NavigationStack`.

Mac presentation follows desktop conventions. The implementation will prefer sheets, inspectors, or separate windows where appropriate rather than copying iPhone full-screen behavior.

Presentation state is item-driven. Boolean flags are reserved for destinations that genuinely carry no identity or associated state.

## Deep Linking

`DeepLinkParser` is a pure component that converts supported URLs into a typed `NavigationIntent`. Parsing a URL never directly mutates UI state.

The root router applies an intent by:

1. Selecting or establishing the required root flow.
2. Selecting the destination top-level section.
3. Updating the target feature's selection and typed path.
4. Presenting a modal destination only after its underlying navigation state is valid.

If an intent requires authentication while the app is launching or unauthenticated, the router stores one pending intent. It replays that intent after authentication succeeds and discards it if authentication is cancelled.

Unknown URLs and unavailable records open the nearest valid default destination and produce a structured log entry.

The initial sample deep-link grammar will be intentionally small and documented alongside the implementation. It will demonstrate top-level selection and a nested Browse destination without inventing a full product URL scheme.

## State Restoration

Restorable navigation state includes:

- Selected top-level section
- Each feature's stable selection identifiers
- Each feature's typed push path

Restoration is scene-scoped using `SceneStorage`. A Codable snapshot is produced from the observable navigation models and restored when the scene is recreated.

Transient state is not restored:

- Alerts and confirmation dialogs
- Loading presentations
- Authentication forms
- Most sheets and full-screen covers
- A pending authentication-gated deep link

During restoration, route identifiers are resolved through feature data interfaces. Missing records are removed from the path. Corrupt or incompatible encoded state falls back to a clean default state without crashing.

The snapshot format includes a schema version so future applications can migrate or reset navigation state deliberately.

## Module Boundaries

The implementation will use these conceptual boundaries:

- `App/Navigation`: adaptive application shell, root flow, app router, deep-link coordination, and scene restoration.
- `Core/Navigation`: only navigation primitives that are reused by more than one feature.
- `Features/Home`: removable example feature and its routes.
- `Features/Browse`: removable example feature that demonstrates nested navigation and stable identifiers.
- `Features/Settings`: removable example feature and its routes.

Shared abstractions are introduced only when at least two features need the same behavior. The project will not create a universal coordinator protocol or destination registry preemptively.

## Error Handling and Diagnostics

- Unknown or malformed URLs use a safe default destination.
- Corrupt restoration data resets to default navigation state.
- Routes for deleted or unavailable records are pruned during restoration and deep-link resolution.
- Failed or cancelled authentication clears the pending intent.
- Route switches are exhaustive so adding a route produces compiler errors at unsupported destination mappings.
- Navigation diagnostics use `Logger` categories rather than `print`.
- Expected routing failures do not use `fatalError` or force unwraps.

## Testing Strategy

The project currently has no test target. Navigation implementation will add an appropriate unit-test target and cover:

- Codable round trips for every route and the restoration snapshot
- Restoration schema-version handling
- Every supported deep-link format
- Malformed and unknown deep links
- Push, pop, pop-to-root, and path replacement
- Top-level section switching with independent history preservation
- Root-flow transitions
- Authentication-gated intent replay and cancellation
- Restoration with corrupt data and deleted records
- Independent state for multiple scenes

UI smoke tests or focused launch checks will verify:

- Compact iPhone navigation
- iPad navigation while resizing between compact and regular widths
- Mac sidebar and window behavior
- Native back and dismissal synchronization

Navigation tests use in-memory identifier resolvers. They must not require real network or database implementations.

## Acceptance Criteria

- The project builds for iOS/iPadOS 26 and macOS 26 with 26.0 deployment targets.
- VisionOS is no longer listed as a supported platform.
- The application shell automatically presents platform-appropriate tab/sidebar navigation.
- Home, Browse, and Settings preserve independent typed paths.
- At least one nested route can be reached through both user interaction and a parsed deep link.
- Navigation state can round-trip through a versioned Codable snapshot.
- Invalid deep links and corrupt restoration data never crash the app.
- Every scene has independent navigation state.
- Navigation logic is covered by deterministic unit tests without network or database dependencies.
- No third-party navigation framework is required.
