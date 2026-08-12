# Detailed Local Notification Service Design

## Status

The user approved this design section by section on 2026-08-12. This document
is the normative input to the Local Notification Service implementation plan.
The implementation must not begin until the user has reviewed this written
specification.

This cycle adds local-notification infrastructure only. It does not add APNs
registration, device-token handling, a push provider, a notification settings
screen, or a product feature that automatically asks for authorization.

## Goal

Add a detailed, typed, testable Local Notification Service for iOS, iPadOS,
and macOS that:

- exposes one platform-neutral `Sendable` contract with no public
  `UNUserNotificationCenter`, `UNNotificationRequest`, or other `UN*` types;
- reads authorization and presentation settings without causing a prompt;
- requests authorization only after an explicit consumer action;
- registers actionable categories, including text-input actions;
- schedules immediate, time-interval, and calendar notifications;
- supports local image, audio, and video attachments without moving or
  modifying the caller's source file;
- lists and removes only the local notifications owned by this service;
- updates the app-wide badge count;
- publishes foreground-delivery, open, dismiss, custom-action, and text-action
  events;
- navigates notification deep links through the existing per-scene navigation
  lifecycle while keeping the system service UI-independent;
- routes a notification to the most recently active iOS/iPadOS scene or most
  recently key macOS window, queueing routes while no scene is eligible;
- provides a fresh in-memory implementation for previews, UI tests, and unit
  tests; and
- introduces no location trigger, `.timeSensitive`, `.critical`, Push
  Notifications capability, critical-alert entitlement, or automatic
  authorization prompt.

Success from `schedule(_:)` means that Notification Center accepted the
request. It does not guarantee that the operating system will display it. User
settings, Focus, notification summaries, power state, and other system policy
remain authoritative.

## Current Baseline

The application supports iOS, iPadOS, and macOS 26.0 and uses Swift 6 with
MainActor default isolation. It has no third-party package dependency and uses
filesystem-synchronized Xcode groups.

The current composition and navigation boundaries relevant to this work are:

- `AppDependencies` is an immutable `Sendable` graph with `live`, `uiTesting`,
  `preview`, and `test` factories.
- `AppTemplateApp` creates the dependency graph synchronously in its
  initializer and then creates the application-flow coordinator.
- Every `AppSceneView` owns a distinct `AppSceneNavigationLifecycle` and
  `AppRouter`.
- `AppSceneNavigationLifecycle.receive(_:)` already queues URLs until
  restoration, parses them through `DeepLinkParser`, preserves authentication
  and maintenance deferral, and ultimately mutates only that scene's
  `AppRouter`.
- `AppSceneView` persists navigation changes through its existing snapshot
  observation.
- The project has no notification delegate, notification permission request,
  notification capability, critical-alert entitlement, or location permission
  declaration.
- `App/Services/Remote` is an HTTP abstraction. It is unrelated to APNs and is
  unchanged by this work.

The service must reuse these boundaries rather than introduce a second router,
global navigation path, shared window router, or duplicate notification
schedule database.

## Selected Direction and Rejected Alternatives

The selected direction is a typed service actor backed by a narrow internal
Notification Center client, plus a separate MainActor navigation coordinator.
Notification Center remains the sole source of truth for pending and delivered
notifications.

This direction is preferred because it separates four concerns that change for
different reasons:

1. Public models and service semantics do not depend on UserNotifications.
2. The mapper and system client own Apple-framework conversion and callbacks.
3. The delegate bridge owns process-lifetime delivery and response handling.
4. The navigation coordinator owns scene selection and existing-router input.

The following alternatives are rejected:

1. Exposing `UNNotificationRequest` directly would leak framework classes,
   untyped `userInfo`, platform details, and delegate behavior into Features.
2. A single service that also owns `AppRouter` or `NSWindow` would couple
   infrastructure to UI and make multi-window behavior global and ambiguous.
3. Persisting a duplicate SwiftData schedule table would create two competing
   truths and require reconciliation with system removals and delivery.
4. One global router would navigate every window or an arbitrary window rather
   than the selected scene.
5. Adding location, time-sensitive, or critical delivery would require product
   policy and, in some cases, capabilities or entitlements outside this cycle.
6. Downloading attachment URLs would turn scheduling into a networking and
   cache-lifecycle subsystem. Only already-local files are accepted.

## Responsibility Split

| Component | Owns | Must not own |
| --- | --- | --- |
| `ILocalNotificationService` | Platform-neutral async consumer contract | `UN*` types, navigation, product permission timing |
| `LocalNotificationService` | Validation orchestration, namespaced ownership, scheduling semantics | Views, routers, windows, APNs, duplicate persistence |
| `LocalNotificationCenterClient` | Narrow bridge over `UNUserNotificationCenter` | Product models, business actions, navigation |
| `LocalNotificationMapper` | Bidirectional model and `UN*` conversion | System calls, scene state, logging policy |
| `LocalNotificationEnvelopeCodec` | Versioned service-owned `userInfo` envelope | Visible content duplication, source attachment paths |
| `LocalNotificationAttachmentStager` | Safe local-file validation and disposable copies | Downloads, permanent cache, caller-file ownership |
| `LocalNotificationDeepLinkPolicy` | Platform-neutral URL validity closure | `NavigationIntent`, scene selection, router mutation |
| `NotificationCenterDelegateBridge` | The app's single center delegate and callback completion | Feature business behavior, scene choice |
| `LocalNotificationEventHub` | FIFO event publication and subscriber lifecycle | URL parsing, router mutation |
| `LocalNotificationNavigationCoordinator` | Eligible-scene registry, route FIFO, lifecycle delivery | Notification scheduling, system-center calls |
| `LocalNotificationWindowActivityProbe` | Key/resign-key state for its own macOS window | Global `NSWindow` lookup or window mutation |
| `InMemoryLocalNotificationService` | Deterministic isolated service behavior | Real permission prompts, real delivery, global state |
| `LocalNotificationDependencies` | Strong runtime ownership and configured-catalog bootstrap | Defining Feature content or choosing permission timing |
| `AppDependencies` | Live/in-memory/test injection | Notification payload construction |

`NotificationCenterDelegateBridge` is deliberately broader than a local-only
delegate name because `UNUserNotificationCenter.delegate` is app-global and
weak. The live dependency graph holds the bridge strongly and assigns it once,
synchronously, before any notification task begins. A future APNs subsystem
must register an unmanaged-notification handler with this bridge; it must not
replace the center's delegate.

## Public Service Contract

All public value types, protocols, errors, and protocol extensions are
explicitly `nonisolated` because the project uses MainActor default isolation.

```swift
nonisolated
protocol ILocalNotificationService: Sendable {
    func settings() async -> LocalNotificationSettings

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool

    func setCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws

    func schedule(
        _ request: LocalNotificationRequest
    ) async throws

    func pending() async -> [LocalNotificationPendingSnapshot]
    func delivered() async -> [LocalNotificationDeliveredSnapshot]

    func removePending(
        _ identifiers: Set<LocalNotificationID>
    ) async

    func removeAllPending() async

    func removeDelivered(
        _ identifiers: Set<LocalNotificationID>
    ) async

    func removeAllDelivered() async

    func setBadgeCount(_ count: Int) async throws
    func clearBadge() async throws

    func events() async -> AsyncStream<LocalNotificationEvent>
}
```

The exact high-level semantics are:

- `settings()` is read-only and never prompts.
- `requestAuthorization(_:)` is the only permission-requesting operation.
- `setCategories(_:)` replaces the service-owned category subset as one
  validated catalog update while preserving categories not owned by this
  notification runtime.
- `schedule(_:)` validates and builds the entire request before submitting one
  system add operation.
- scheduling the same logical request ID replaces the pending request with that
  ID; it does not remove an already delivered notification with that ID.
- list methods are nonthrowing and represent an owned but unreadable request as
  an unreadable snapshot rather than failing the whole list.
- point removals and remove-all operations are idempotent.
- remove-all operations affect only identifiers owned by this service.
- badge operations affect the application badge globally; badge state cannot
  be namespaced between local and future remote notification producers.
- every awaited `events()` call atomically registers and returns a new
  multicast subscription before a later event can be published to it.

No public API exposes arbitrary `[AnyHashable: Any]`, `NSDictionary`,
`UNAuthorizationOptions`, `UNNotificationPresentationOptions`, or another
framework representation.

## Logical Identifiers and Physical Namespace

The public identifier types are:

```swift
nonisolated struct LocalNotificationID: Hashable, Codable, Sendable
nonisolated struct LocalNotificationCategoryID: Hashable, Codable, Sendable
nonisolated struct LocalNotificationActionID: Hashable, Codable, Sendable
nonisolated struct LocalNotificationAttachmentID: Hashable, Codable, Sendable
```

Each type has a throwing validating initializer and no unchecked public
initializer. A logical identifier must:

- contain between 1 and 128 UTF-8 bytes;
- contain at least one non-whitespace character; and
- contain no NUL or ASCII control character.

Validation does not trim, normalize Unicode, case-fold, localize, or otherwise
change an accepted value. Two differently normalized Unicode strings remain
different identifiers. A validation error identifies only the identifier kind;
it never includes the rejected value. Custom `Decodable` implementations apply
the same validation, so decoding cannot bypass the initializer.

The live namespace is exactly `AppTemplate.LocalNotification`. Physical
identifiers are deterministic and use unpadded base64url of the logical UTF-8
bytes:

```text
request:  AppTemplate.LocalNotification.request.<encoded logical request ID>
category: AppTemplate.LocalNotification.category.<encoded logical category ID>
action:   AppTemplate.LocalNotification.action.<encoded category ID>.<encoded action ID>
attachment: AppTemplate.LocalNotification.attachment.<encoded request ID>.<encoded attachment ID>
envelope: AppTemplate.LocalNotification.envelope
```

The service never exposes physical identifiers to Features. The prefix prevents
a local request from colliding with remote notifications or another future
notification producer. It also lets list and remove-all operations filter
owned requests without calling the system-wide remove-all methods.

An identifier with the service prefix but an invalid base64url suffix is not
claimed as an owned request. A correctly encoded owned physical identifier with
a missing or invalid envelope becomes an unreadable owned snapshot.

## Settings and Authorization

`LocalNotificationSettings` contains:

- `authorizationStatus`;
- alert, sound, badge, Notification Center, and Lock Screen setting states;
- the current alert style; and
- the current preview setting where the platform reports it.

The platform-neutral enums preserve `.notSupported` and `.unknown` states so a
new or unavailable system case is not incorrectly treated as enabled. The
authorization model represents `.notDetermined`, `.denied`, `.authorized`,
`.provisional`, `.ephemeral`, and `.unknown`. Platform-unavailable cases map to
`.notSupported` rather than being conditionally removed from the public model.

`LocalNotificationAuthorizationOptions` is an `OptionSet` containing only:

- `.alert`;
- `.sound`;
- `.badge`; and
- `.provisional`.

An empty option set or unknown raw bit throws
`.invalidAuthorizationOptions` before calling the system. The service does not
offer CarPlay, announcements, critical alerts, time-sensitive authorization,
or app-notification-settings callbacks in this cycle.

The app performs no authorization request during dependency construction,
launch, category registration, scene registration, or preview creation. A
Feature may call `requestAuthorization(_:)` only in response to an explicit
user action. The returned `Bool` mirrors the system result; callers fetch
`settings()` again when they need the resulting detailed state.

Notification authorization is app-global and applies to both local and remote
notification presentation. Naming this API “local” does not create a separate
system permission domain.

## Request and Content Models

The scheduling model is:

```swift
nonisolated
struct LocalNotificationRequest: Sendable {
    let id: LocalNotificationID
    let content: LocalNotificationContent
    let trigger: LocalNotificationTrigger
}
```

`LocalNotificationContent` contains:

- `title`, `subtitle`, and `body`;
- an optional nonnegative badge count;
- `.none`, `.default`, or `.named(resourceName)` sound;
- an optional category ID;
- optional thread and target-content identifiers;
- an optional summary argument and positive summary count;
- an optional relevance score in `0...1`;
- `.passive` or `.active` interruption level;
- zero or more local attachments;
- typed metadata;
- an optional application deep-link URL; and
- explicit foreground-presentation options.

At least one of title, subtitle, or body must contain a non-whitespace
character, or the request must contain a badge, non-`.none` sound, or
attachment. The service rejects content with no observable notification
effect. Text is preserved exactly and may contain newlines, but NUL is
rejected. Empty or whitespace-only title, subtitle, or body fields are
permitted when another observable field is present.

The optional thread and target-content identifiers follow the same
nonempty/no-control-character rule as logical IDs but permit up to 256 UTF-8
bytes. They are not used as service identity and are never logged.

A named sound is a nonempty leaf resource name, not a URL or path. `/`, `\`,
NUL, and ASCII control characters are rejected. The service does not claim that
the named resource exists or that the system will play it; Notification Center
and user settings remain authoritative.

The summary argument must contain a non-whitespace character and its count must
be greater than zero when a summary is present. Badge count must be zero or
greater. Relevance score must be finite and within `0...1`. Non-finite numbers
are invalid.

`LocalNotificationInterruptionLevel` has exactly `.passive` and `.active`.
There is no raw-value constructor that can manufacture `.timeSensitive` or
`.critical`. The mapper contains no code path for either excluded level.

`LocalNotificationForegroundPresentation` is an `OptionSet` with `.banner`,
`.list`, `.sound`, and `.badge`. It is stored in the versioned envelope because
the delegate may need it after process termination and relaunch. Unknown bits
are rejected at schedule time. Foreground presentation is a request to the
system, not a display guarantee.

### Deep-link validation boundary

The service receives a `LocalNotificationDeepLinkPolicy` containing only an
`@Sendable (URL) -> Bool` validation closure. Live composition builds that
closure from `DeepLinkParser.parse(_:)`, accepting only `.success`. The policy
does not expose `NavigationIntent`, `AppRouter`, scene state, or fallback
navigation to the service.

Request deep links are checked during scheduling. Action deep links are checked
during category registration. A non-`nil` URL rejected by the policy produces
`.invalidDeepLink` before any category or notification-center mutation. The
in-memory implementation uses the same injected policy. The navigation
coordinator still validates an event URL again before delivering it to a scene,
because a stored envelope is external process state and may be corrupt or from
a later binary.

## Triggers

`LocalNotificationTrigger` is a closed enum:

```swift
nonisolated
enum LocalNotificationTrigger: Hashable, Codable, Sendable {
    case immediate
    case timeInterval(seconds: TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
}
```

The mapping and validation rules are exact:

- `.immediate` maps to a `nil` system trigger.
- A nonrepeating time interval must be finite and greater than zero.
- A repeating time interval must be finite and at least 60 seconds.
- A calendar trigger must contain at least one supported matching component.
- The supported calendar fields are era, year, month, day, hour, minute,
  second, weekday, weekday ordinal, week of month, week of year, year for week
  of year, and quarter. Calendar and time-zone values may accompany them.
- Nanoseconds and unsupported `DateComponents` fields are rejected rather than
  silently discarded.
- After conversion, `nextTriggerDate()` must be non-`nil` for both one-shot and
  repeating calendar triggers.

The service does not invent a default time zone or calendar. Values present in
the supplied `DateComponents` are preserved. Values omitted by the caller keep
the system trigger's matching semantics.

There is no location-trigger case, Core Location import, region model, or
location authorization behavior.

## Attachments

An attachment request contains:

```swift
nonisolated
struct LocalNotificationAttachment: Sendable {
    let id: LocalNotificationAttachmentID
    let fileURL: URL
    let options: LocalNotificationAttachmentOptions
}
```

The options support:

- an optional Uniform Type Identifier hint;
- hiding the thumbnail;
- an optional normalized thumbnail clipping rectangle; and
- an optional nonnegative thumbnail time for time-based media.

A clipping rectangle must be finite, remain within the unit rectangle, and
have positive width and height. A thumbnail time must be finite and
nonnegative. Type hints and inferred filename types are accepted only when
they conform to image, audio, or movie content. The system attachment
initializer remains the final authority on exact supported formats and size.

Before any system add operation, every attachment must be:

- a file URL;
- an existing readable regular file;
- neither a directory nor a symbolic link; and
- uniquely identified within the request.

The service performs no network access and accepts no `http` or `https` URL.

Apple's attachment scheduling flow may move the file passed to the system.
The service therefore never passes the caller's source file directly. For each
source it:

1. enters security-scoped access when available;
2. copies the source into a unique service-owned temporary staging directory;
3. constructs the system attachment from the disposable copy;
4. stops source security-scoped access;
5. submits the request only after every attachment is ready; and
6. removes any leftover staging copy on conversion or add failure.

The original source file remains unchanged. The caller only needs to keep it
readable until `schedule(_:)` returns. The staging directory is never reused as
a permanent cache and is not a source of truth.

If one attachment fails, the service submits no request and leaves an existing
pending request with the same ID untouched. Attachment errors identify the
logical attachment ID and a redacted reason but never expose a path, filename,
file contents, or underlying localized description.

Pending and delivered snapshots expose the system-owned attachment URL and
type identifier, not the original source path. A consumer that reads a
snapshot attachment URL must use security-scoped resource access for the
duration of that read.

## Typed Metadata and Versioned Envelope

Arbitrary `userInfo` is not public API. Metadata uses a recursive, JSON-shaped
`LocalNotificationMetadataValue` with exactly these cases:

- string;
- signed 64-bit integer;
- finite double;
- boolean;
- array;
- object with string keys; and
- null.

Metadata keys must be nonempty after a whitespace check and contain no NUL or
ASCII control characters. Values are never bridged through public `Any`.
Non-finite doubles are rejected before encoding.

The mapper writes one namespaced `Data` value into `userInfo`. Envelope version
1 contains only service-owned round-trip state:

- schema version;
- logical request ID;
- logical category ID when present;
- the logical `.none`, `.default`, or named-sound specification;
- typed metadata;
- the default-open deep link;
- foreground-presentation options; and
- the logical custom/text action route snapshot for the registered category.

Visible title, subtitle, body, badge, trigger fields, and original attachment
source URLs are not duplicated in the envelope. The logical sound
specification is retained because the public system content does not provide a
stable way to recover a named sound's resource name. Snapshots rebuild all
other visible values from the system request and combine them with the decoded
envelope.

The action route snapshot is immutable for a scheduled request. Re-registering
a category later may change the buttons the system displays, but it does not
rewrite deep-link behavior already embedded in a pending or delivered request.

The decoder accepts version 1 only in this cycle. A future version must add an
explicit migration or preservation rule. Missing, malformed, future, or
identifier-mismatched envelopes do not crash, force-cast, fall back to a
different route, or expose their raw data. They produce an unreadable snapshot
and a redacted diagnostic event when encountered through the delegate.

## Categories and Actions

`LocalNotificationCategory` contains:

- one category ID;
- zero to ten ordered actions;
- optional hidden-preview body placeholder and category summary format;
- whether hidden previews may show title or subtitle; and
- whether dismiss actions are reported to the delegate.

Category IDs must be unique within one `setCategories(_:)` call. Action IDs
must be unique within their category. More than ten actions is rejected because
the system does not display more than ten even when space is unrestricted and
usually displays no more than two when space is constrained.

An optional hidden-preview placeholder or summary format must contain a
non-whitespace character and no NUL. Accepted text is preserved without
trimming or localization.

There are two action forms:

```swift
nonisolated
enum LocalNotificationAction: Sendable {
    case button(LocalNotificationButtonAction)
    case textInput(LocalNotificationTextInputAction)
}
```

Both forms contain an ID, display title, options, and optional deep link. Text
input additionally contains the input button title and placeholder. Action
options are foreground, destructive, and authentication-required. Empty action
titles and text-input button titles are invalid.

The options describe system presentation only. A destructive action does not
perform deletion by itself. The service publishes an event and the consuming
Feature owns business behavior.

A request with a category ID that is not in the last successfully registered
service-owned catalog is rejected before scheduling. This prevents a request
from silently losing expected actions.

All categories are fully validated and converted before the system category
set is mutated. The internal app-global category registry serializes updates,
removes the old local namespace subset, preserves categories outside that
subset, and applies the combined set once. No other application component may
call `setNotificationCategories` directly.

Category registration is idempotent and occurs during runtime bootstrap. It
does not require authorization and never causes a prompt. The initial template
catalog may be empty; the service remains useful for non-actionable
notifications.

The live service actor stores the configured startup catalog and an idempotent
bootstrap state. Runtime startup calls `bootstrapCategoriesIfNeeded()`, and
`schedule(_:)` also awaits that method before submitting a request. The second
call is a no-op after successful registration. This safety net prevents an
immediate categorized notification from racing the scene startup task and
arriving before its actions are registered. A successful public
`setCategories(_:)` replaces the stored startup catalog and becomes the new
last successfully registered catalog. Actor serialization gives concurrent
`setCategories(_:)` and `schedule(_:)` a deterministic order.

## Scheduling and System Truth

`schedule(_:)` uses this order:

1. Check pre-operation task cancellation.
2. Validate request identity, content, metadata, deep links, trigger, category
   reference, and attachment options.
3. Await idempotent category bootstrap if it has not completed.
4. Resolve the registered category and snapshot its action routes.
5. Encode the versioned envelope.
6. Stage and construct every attachment.
7. Construct one immutable system content and trigger.
8. Construct one system request using the deterministic physical ID.
9. Submit exactly one add operation.
10. Clean any remaining staging artifacts.
11. Return only after the system add operation succeeds.

All validation and fallible preparation completes before the add. If any step
before submission fails, no system request is added and an older pending
request with the same ID remains intact.

The system documents same-identifier scheduling as replacement. Therefore a
successful second schedule with the same logical ID replaces the pending
request rather than creating a duplicate. No separate pre-removal is performed;
pre-removal would destroy the old request if construction or add failed.

The service stores no schedule copy in SwiftData, UserDefaults, Keychain, a
file, or process-global memory. Notification Center is authoritative across
relaunches. The registered category catalog and event subscriber registry are
process state, not schedule persistence.

## Pending and Delivered Snapshots

Pending results are represented by:

```swift
nonisolated
struct LocalNotificationPendingSnapshot: Sendable {
    let id: LocalNotificationID
    let payload: LocalNotificationSnapshotPayload
    let nextTriggerDate: Date?
}
```

Delivered results are represented by:

```swift
nonisolated
struct LocalNotificationDeliveredSnapshot: Sendable {
    let id: LocalNotificationID
    let payload: LocalNotificationSnapshotPayload
    let deliveredAt: Date
}
```

The payload is either:

- `.decoded(LocalNotificationStoredRequest)`; or
- `.unreadable(LocalNotificationUnreadableReason)`.

`LocalNotificationStoredRequest` preserves the schedulable content and trigger
semantics, with one deliberate attachment substitution. Each stored attachment
contains its decoded logical attachment ID, system-owned security-scoped URL,
and reported type identifier; it does not claim to reproduce the caller's
original source URL or thumbnail-construction options. Sound is reconstructed
from the envelope, while the remaining content and trigger fields are read
from the system request.

Unreadable reasons are missing envelope, corrupt envelope, unsupported envelope
version, and logical/physical identifier mismatch. The reason carries no title,
body, metadata, URL, path, text-input response, or raw envelope bytes.

Only physical IDs in the local request namespace are returned. Delivered
remote notifications and other unmanaged notifications are filtered out.

Pending snapshots are sorted by next trigger date ascending, with `nil` last,
then by logical ID. Delivered snapshots are sorted by delivery date descending,
then by logical ID. The in-memory service uses the same ordering.

Snapshot decoding never repairs, removes, or rewrites a system request. A
corrupt item remains removable through its valid logical ID and through the
service-owned remove-all operation.

## Removal and Badge Semantics

Point removals map logical IDs directly to namespaced physical IDs and are
successful no-ops when an ID is absent.

`removeAllPending()` and `removeAllDelivered()` first fetch the corresponding
system collection, select only valid service-owned physical IDs, and remove
that exact identifier set. They never call the unscoped system remove-all APIs.

A pending request may be delivered between listing and removal. In that race,
`removeAllPending()` does not also remove the delivered notification; its
contract is limited to pending requests. System delivery and external process
termination remain outside actor serialization.

`setBadgeCount(_:)` rejects a negative value before calling the system.
`clearBadge()` is exactly `setBadgeCount(0)`. A successful return means the
system accepted the badge update, not that every launcher surface refreshed
synchronously.

## Delegate Bridge and Event Semantics

The live graph creates and strongly retains one
`NotificationCenterDelegateBridge`. It assigns that object to the shared
notification center synchronously during `AppDependencies.live()` and before
runtime bootstrap, scheduling, authorization, or scene tasks.

The bridge handles:

- foreground notification delivery;
- default notification opens;
- dismiss callbacks for categories that request them;
- custom button actions; and
- text-input actions with the typed response text.

The public event enum is:

```swift
nonisolated
enum LocalNotificationEvent: Sendable {
    case foreground(
        notification: LocalNotificationEventNotification,
        presentation: LocalNotificationForegroundPresentation
    )
    case opened(
        notification: LocalNotificationEventNotification,
        deepLink: URL?
    )
    case dismissed(
        notification: LocalNotificationEventNotification
    )
    case action(
        notification: LocalNotificationEventNotification,
        id: LocalNotificationActionID,
        deepLink: URL?
    )
    case textAction(
        notification: LocalNotificationEventNotification,
        id: LocalNotificationActionID,
        text: String,
        deepLink: URL?
    )
    case diagnostic(LocalNotificationDiagnostic)
}
```

`LocalNotificationEventNotification` contains the logical request ID and the
same decoded-or-unreadable payload shape as list snapshots. Metadata is
available only through a decoded payload.

`LocalNotificationDiagnostic` contains an optional logical request ID and one
closed reason: missing envelope, corrupt envelope, unsupported envelope
version, identifier mismatch, invalid deep link, or unrecognized action. It
never contains a physical or undecoded identifier, content, metadata, URL,
text input, path, envelope bytes, or underlying error text.

Deep-link selection is exact:

- a default open uses the request deep link;
- a custom or text action uses only that action's embedded deep link;
- a custom or text action with no action deep link does not fall back to the
  request deep link;
- foreground delivery and dismiss never navigate; and
- an unreadable envelope or invalid URL never navigates.

Text entered by the user exists only in the emitted text-action event. The
service does not persist or log it.

For a non-system action identifier, the bridge decodes the namespaced category
and logical action ID. A valid action whose category matches the envelope emits
an action event even when the immutable route snapshot contains no route for
that ID; its event deep link is then `nil`. An undecodable action identifier or
category mismatch emits `.unrecognizedAction` and does not navigate.

For an owned callback, the bridge decodes, enqueues one event, and then invokes
the corresponding system completion handler exactly once. Completion waits for
the event to enter the hub, but does not wait for navigation, subscriber work,
or Feature business behavior.

For a foreground owned notification with an unreadable envelope, the bridge
emits a diagnostic and requests no foreground presentation. For an owned
response with an unreadable envelope, it emits a diagnostic and performs no
navigation.

An unmanaged or remote notification is not published as a local event. The
bridge forwards it to an injected unmanaged handler. That handler returns its
foreground decision or completes its async response work; it never receives
the raw system completion closure. The bridge therefore remains the sole owner
of exactly-once completion. When no unmanaged handler is installed, foreground
presentation defaults to no options and a response is completed without local
processing, matching the absence of an app-specific foreground policy. A
future remote-notification subsystem must install the handler on this bridge
rather than replace the delegate.

## Event Hub Delivery Guarantees

`LocalNotificationEventHub` is an actor. It assigns a monotonically increasing
process-local sequence when an event is enqueued and preserves that order.

It has two delivery paths:

1. The app-owned navigation sink receives every route-bearing event through a
   dedicated process-lifetime FIFO while the process is alive.
2. Each public `events()` subscription receives a separate
   unbounded `AsyncStream` view in event order.

The hub does not drop an event for a live subscription. Enqueueing yields to
each continuation but does not wait for subscriber work. Notification
interaction is low volume, so preserving process-lifetime action events is
preferred to a bounded drop policy. A consumer owns the lifetime of its
consuming task and must cancel that task when it no longer needs events.

Cancellation or termination removes that continuation from the hub. One
subscriber cannot consume, cancel, or reorder another subscriber's events.
The hub is neither a backpressure mechanism nor a durable queue and does not
claim delivery after process termination.

## Navigation Coordinator

`LocalNotificationNavigationCoordinator` is a separate `@MainActor` type. It
depends on the event hub and `DeepLinkParser`; it does not depend on
`UNUserNotificationCenter` or any service implementation.

Each `AppSceneView` creates one stable scene-registration ID and registers its
own `AppSceneNavigationLifecycle` weakly. Registration never creates or shares
an `AppRouter`.

Eligibility is platform-specific:

- On iOS and iPadOS, `scenePhase == .active` marks a scene eligible. The most
  recently marked active scene wins.
- On macOS, a narrow `NSViewRepresentable` probe observes only the window that
  contains that representable. `windowDidBecomeKey` marks the scene eligible;
  `windowDidResignKey` makes it ineligible. The most recently key scene wins.
- Scene disappearance, task cancellation, or lifecycle deallocation removes
  the registration.

The macOS probe does not enumerate `NSApp.windows`, inspect a global key window,
retain an `NSWindow`, mutate window configuration, or perform navigation. It
removes observers when its hosting window changes or the representable is
dismantled.

When a valid route-bearing event arrives:

1. The coordinator validates the URL again with `DeepLinkParser`.
2. If an eligible scene exists, it calls only that scene lifecycle's
   `receive(_:)`.
3. If no scene is eligible, it appends the URL to an in-memory FIFO.
4. When a scene next becomes eligible, it drains the FIFO to that one scene in
   insertion order.

The coordinator does not call the parser's fallback route for invalid data.
Invalid or unsupported URLs produce a redacted diagnostic and no navigation.

Passing a valid URL into `AppSceneNavigationLifecycle.receive(_:)` deliberately
reuses existing behavior:

- routes received before restoration remain queued by the lifecycle;
- authentication or maintenance flows preserve the existing pending-intent
  policy;
- restoration and future-schema preservation remain unchanged;
- the selected scene's existing snapshot observer persists applied navigation;
  and
- other scenes and their routers remain untouched.

A background custom action with a deep link may leave the route in the
coordinator FIFO because no scene is active. A category that expects immediate
visible navigation should mark that action `.foreground`; the service does not
force foreground launch.

The navigation FIFO is process-local and intentionally not persisted. The
system already launches or resumes the app for a notification response, and
persisting a second action queue would require separate replay and deduplication
product policy.

## Composition and Startup

`LocalNotificationDependencies` groups:

- `service: any ILocalNotificationService`;
- the strongly held delegate/runtime bridge;
- the idempotent category bootstrapper;
- the event hub; and
- the MainActor navigation coordinator.

`AppDependencies` owns one `LocalNotificationDependencies` value. Features that
later need scheduling receive only `any ILocalNotificationService`, not the
runtime or navigation coordinator.

Live startup order is:

1. Create the system-center client.
2. Create the event hub and navigation coordinator.
3. Create and strongly retain the delegate bridge.
4. Assign the bridge as the unique system-center delegate.
5. Create the live service and category bootstrapper.
6. Create application flow and scenes.
7. Run idempotent category registration from scene startup without requesting
   authorization.
8. Register each scene lifecycle and its activity state.

The coordinator exists before a scene does. Therefore a response that launches
the app can enter the coordinator FIFO and wait for the first eligible scene.

`uiTesting` and `preview` composition use a fresh
`InMemoryLocalNotificationService` and in-memory event hub. They never access
`UNUserNotificationCenter.current()`, assign a real delegate, schedule a real
notification, or display a system permission prompt.

The existing filesystem-synchronized Xcode groups include new Swift source and
test files automatically; the implementation must not manually add ordinary
source membership entries to `project.pbxproj`.

## Errors, Privacy, and Diagnostics

The public error is a stable `Equatable`, `Sendable` enum:

```swift
nonisolated
enum LocalNotificationServiceError: Error, Equatable, Sendable {
    case invalidIdentifier(LocalNotificationIdentifierKind)
    case invalidAuthorizationOptions
    case invalidContent(LocalNotificationContentFailure)
    case invalidTrigger(LocalNotificationTriggerFailure)
    case invalidCategory(LocalNotificationCategoryFailure)
    case invalidMetadata
    case invalidDeepLink
    case invalidAttachment(
        LocalNotificationAttachmentID,
        LocalNotificationAttachmentFailure
    )
    case unsupportedEnvelopeVersion(Int)
    case system(
        operation: LocalNotificationSystemOperation,
        domain: String,
        code: Int
    )
}
```

Associated reason enums contain closed semantic categories, not arbitrary
strings. Attachment reasons include not-file-URL, missing, unreadable,
not-regular-file, symbolic-link, unsupported-type, invalid-options,
staging-failed, and system-rejected. Trigger and content reasons follow the
validation rules in this document.

The strict internal envelope codec uses `.unsupportedEnvelopeVersion`. List
and event surfaces translate that strict failure into their unreadable snapshot
or diagnostic representation instead of failing an entire collection or
delegate callback.

System failures expose only the operation, error domain, and numeric code.
They never expose `localizedDescription`, `userInfo`, a recovery suggestion, a
file path, or another underlying payload.

`Logger.localNotifications` may record only fixed operation names, numeric
system codes, and closed redacted reason enums. It must not record:

- title, subtitle, or body;
- request, category, action, thread, or attachment IDs;
- metadata keys or values;
- deep-link URLs;
- text-input responses;
- attachment names, paths, type hints, or contents;
- named-sound resource names;
- raw envelopes or system `userInfo`; or
- underlying error descriptions.

Invalid or corrupt external state is diagnosed but not automatically deleted.
Removal and repair remain explicit caller actions.

## Concurrency and Cancellation

`LocalNotificationService` and `InMemoryLocalNotificationService` are actors.
Mutable category state, in-memory request state, and internal operation ordering
do not escape actor isolation.

The system client hides callback threading and resumes async operations exactly
once. Framework objects and untyped dictionaries do not cross the public
`Sendable` boundary.

Fallible mutating methods check cancellation before validation and again before
the first irreversible system mutation. Attachment staging checks between
files and cleans staged copies when cancellation occurs before submission.

Once a noncancelable Notification Center add, authorization, category set, or
badge operation has begun, the service does not claim it can stop the system
operation. It returns that operation's actual result and performs no
post-success cancellation check that could report cancellation after a
successful side effect.

`CancellationError` remains `CancellationError`; it is never wrapped in
`LocalNotificationServiceError.system`. Nonthrowing list and removal methods
do not manufacture cancellation errors.

Delegate completion is guarded by an internal once-only token. A malformed
envelope, unknown action, cancelled observer, fallback handler, or navigation
failure cannot cause zero or multiple system completion calls.

## In-Memory Semantics

`InMemoryLocalNotificationService` shares the platform-neutral validator,
identifier namespace rules, metadata codec, category rules, ordering, and
replacement semantics with the live service.

Each instance owns:

- configurable settings and authorization outcome;
- the last successfully registered category catalog;
- pending and delivered snapshots;
- badge count; and
- its own event hub.

Scheduling replaces a pending item with the same logical ID. It does not sleep
or advance wall-clock time. Internal test hooks can mark a request delivered,
inject a foreground or response event, and inspect badge/category state. Those
hooks are not requirements on `ILocalNotificationService` and are unavailable
to ordinary Feature code.

Attachment requests receive the same logical URL, file, media-type, and option
validation, but the in-memory service does not construct a system attachment or
move a file. Tests for staging and system attachment conversion target the live
stager through an injected temporary directory and fake center client.

Preview, UI-test, and test dependency factories create a fresh instance on
every call. No global in-memory singleton or cross-test notification state is
permitted.

## Test Strategy

Implementation follows red-green-refactor TDD. Ordinary automated tests use a
fake `LocalNotificationCenterClient`; they must not request real authorization,
schedule a real notification, or depend on wall-clock sleeps.

### Model and validation tests

- all identifier boundaries, preservation, and physical encoding;
- authorization option allowlist and unknown-bit rejection;
- empty/observable content behavior;
- badge, summary, relevance, sound-name, and text validation;
- passive/active interruption-level closure;
- immediate, interval, and calendar trigger mapping and invalid dates;
- metadata recursive round trips and non-finite rejection;
- category/action uniqueness, limits, text-input fields, and route validation;
- attachment URL, regular-file, symlink, type, clipping, and thumbnail-time
  rules; and
- explicit absence of location, time-sensitive, and critical cases.

### Mapper, envelope, and attachment tests

- exact content, sound, trigger, category, action, and foreground option maps;
- envelope version-1 round trip;
- missing, corrupt, future, and ID-mismatched envelope behavior;
- sound, metadata, and action routes surviving simulated relaunch;
- no title/body or original attachment path in the envelope;
- source file remains byte-for-byte present after staging and scheduling;
- disposable staging copy cleanup on conversion, cancellation, and add failure;
- system-owned snapshot attachment mapping; and
- public/system error redaction.

### Service and system-client tests

- settings mapping without an authorization request;
- explicit authorization result, errors, and cancellation;
- idempotent catalog bootstrap and managed-category replacement;
- foreign category preservation;
- one system add per successful schedule;
- no add on any validation or preparation failure;
- same-ID pending replacement without pre-removal;
- pending/delivered filtering, unreadable snapshots, and deterministic sort;
- point and owned-only remove-all behavior;
- app-global badge set and clear; and
- in-memory instance isolation and deterministic delivery hooks.

### Delegate and event tests

- foreground options restored from the envelope;
- default open, dismiss, custom action, and text action decoding;
- action-specific route selection without request-route fallback;
- user-entered text appears only in the event;
- corrupt owned notifications emit diagnostics and do not navigate;
- unmanaged notifications use the fallback path;
- every delegate callback completes exactly once;
- navigation FIFO receives every route-bearing event;
- multicast subscriber ordering, no-drop process-lifetime delivery, isolation,
  and cleanup; and
- cancellation of one stream leaves other streams active.

### Navigation and composition tests

- most recently active iOS/iPadOS scene selection;
- most recently key macOS scene selection;
- resign, unregister, and weak-lifecycle cleanup;
- FIFO accumulation with no eligible scene and ordered drain on activation;
- one event navigates one scene only;
- invalid URL produces no lifecycle call or fallback navigation;
- pre-restoration delivery reuses the lifecycle queue;
- authentication/maintenance deferral and navigation persistence remain intact;
- macOS probe observes only its hosting window and removes observers;
- live composition strongly owns and installs one delegate before bootstrap;
- preview/UI-test composition never touches the system center; and
- no automatic authorization call occurs in any composition path.

### Verification matrix

Automated verification includes the full macOS unit-test suite and iPhone and
iPad simulator builds/tests supported by the project scheme. Source guards
verify there is no `UNLocationNotificationTrigger`, critical-alert
authorization, or `.timeSensitive`/`.critical` mapper branch.

Manual smoke verification on signed development builds covers:

- first explicit authorization request and denied/allowed settings refresh;
- immediate and scheduled delivery;
- foreground banner/list/sound/badge options;
- cancellation and same-ID replacement;
- image, audio, and video attachments;
- button, dismiss, and text-input actions;
- cold-launch and warm-launch deep-link navigation;
- inactive-scene FIFO behavior; and
- two-window macOS routing to the last key window.

Manual delivery checks are release evidence, not a replacement for deterministic
unit tests.

## Documentation and Release Constraints

Implementation updates:

- `docs/ARCHITECTURE.md` with the service/runtime/navigation boundaries;
- `docs/CUSTOMIZATION.md` with namespace, catalog, deep-link, sound, and
  attachment adoption guidance; and
- `docs/RELEASE_CHECKLIST.md` with authorization and device smoke checks.

This cycle makes no `Info.plist` permission-description change and adds no
entitlements file, Push Notifications capability, App Group, background remote
notification mode, critical-alert entitlement, or location usage key.

The following remain explicit non-goals:

- APNs registration or remote notification payload handling;
- notification service/content extensions;
- network attachment download or cache eviction;
- recurring schedule persistence outside Notification Center;
- notification analytics or delivery receipts;
- business execution for custom actions;
- a settings screen or automatic permission prompt;
- location triggers;
- time-sensitive or critical interruption levels; and
- cross-process durable event or navigation queues.

## Acceptance Criteria

The implementation is complete only when all of the following are true:

1. Features can depend on a platform-neutral `ILocalNotificationService` with
   no public `UN*` type.
2. Live, preview, UI-test, and test graphs inject the correct isolated service.
3. Launch installs one strongly held delegate and registers categories without
   requesting authorization.
4. Authorization occurs only through an explicit service call.
5. Immediate, interval, and calendar requests validate and map exactly as
   specified.
6. Local attachments support image/audio/video and leave original files intact.
7. Same-ID scheduling replaces pending state without destructive pre-removal.
8. Lists and remove-all operations affect only service-owned local requests.
9. Corrupt owned state is represented safely and never redirects to a fallback
   destination.
10. Foreground, open, dismiss, custom, and text events are multicast and system
    callbacks complete exactly once.
11. Notification navigation targets only the last eligible scene and queues
    while none is eligible.
12. Existing restoration, application-flow deferral, and per-scene persistence
    continue to work through `AppSceneNavigationLifecycle.receive(_:)`.
13. Error and diagnostic output contains no notification content, text input,
    metadata, deep links, physical identifiers, or file paths. A returned
    attachment-validation error may identify only its public logical attachment
    ID, as defined by the error contract.
14. Automated tests and platform builds pass, and the release checklist records
    the required signed-build smoke checks.
15. Source and project configuration contain no location trigger,
    `.timeSensitive`, `.critical`, push capability, or new entitlement.

## Apple Framework References

- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- [UNNotificationRequest identifier replacement](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier)
- [UNTimeIntervalNotificationTrigger](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger/init(timeinterval:repeats:))
- [UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)
- [UNNotificationAttachment initializer](https://developer.apple.com/documentation/usernotifications/unnotificationattachment/init(identifier:url:options:))
- [Notification category registration](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/setnotificationcategories(_:))
- [Handling notification actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
