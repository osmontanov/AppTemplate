# Connected Mini Store and Service Playground Design

## Status

The user approved this design section by section on 2026-08-13. This document
is the normative input to the implementation plan. Implementation must not
begin until the user has reviewed this written specification.

This design replaces the current disconnected Home, Browse, Projects,
Settings, Authentication, Onboarding, and Maintenance demonstrations with one
coherent mini-store. The existing low-level navigation, dependency-injection,
networking, UserDefaults, Keychain, SwiftData, AppInfo, and Local Notification
infrastructure remains the foundation, but its example Features and routes are
reworked around the store narrative.

## Goal

Turn AppTemplate into a clear, connected reference application with two main
sections:

1. **Store** demonstrates product navigation, application state, session
   restoration, protected actions, modal flows, deep links, and scene
   restoration through realistic user tasks.
2. **Services** exposes an interactive, low-level playground for every public
   capability of the six application services, plus an App State inspector.

The same services power both sections. Store shows why a product uses each
service; Services shows how each low-level contract behaves.

Success means an adopter can run the application on iPhone, iPad, or macOS and
understand:

- how root application policy differs from per-window navigation;
- how a guest becomes authenticated without replacing the Main root;
- how a protected action resumes after authentication;
- how a persisted JWT session restores and refreshes;
- how live remote data, local persistence, typed preferences, Keychain,
  AppInfo, and local notifications fit behind semantic repositories; and
- how to manually exercise every public operation of each low-level service.

## Product Narrative

The reference application is a small store backed by DummyJSON. A guest may
browse and search products, open product details, inspect reviews and related
products, manage the local cart, and schedule product reminders. Saving a
favorite or opening Favorites/Profile is a protected action. The app presents
Authentication, stores a successful session securely, and then continues the
original action exactly once.

The application uses the public DummyJSON APIs:

- Products: <https://dummyjson.com/docs/products>
- Authentication: <https://dummyjson.com/docs/auth>
- HTTP diagnostics: <https://dummyjson.com/docs/http>

The live application calls `https://dummyjson.com`. Automated tests never
depend on that host; they use the existing injectable network transport and
target sample responses.

DummyJSON is a public testing service with no production availability
guarantee. Its documented demo account, `emilys` / `emilyspass`, is offered as
a prefilled test credential. It is not a product account or secret.

## Scope and Non-goals

This cycle includes:

- a new Store feature hierarchy and a new Services feature hierarchy;
- a two-section adaptive application shell;
- AppState schema and flow-policy changes;
- a persistent DummyJSON JWT session with automatic refresh;
- product, favorite, cart, preference, and reminder examples;
- real live product/authentication requests;
- deterministic network behavior in previews and automated tests;
- cursor-based local-database pagination; and
- migrations and replacement tests for the superseded examples.

This cycle does not include:

- payments, real orders, inventory mutation, or server-side cart persistence;
- production identity, account creation, password recovery, OAuth, passkeys,
  biometrics, or multi-factor authentication;
- APNs, remote notifications, background refresh, or a push provider;
- CloudKit, cross-device synchronization, App Groups, or shared Keychain
  access;
- durable restoration of sheets, authentication modals, checkout steps, or
  pending protected actions across process termination; or
- a promise that a third-party test session can remain server-valid forever.

The app automatically refreshes the session and does not sign a user out for a
temporary network failure. A later authoritative server rejection of the
refresh token requires a new login. DummyJSON currently issues short-lived
access tokens and a longer-lived refresh token; the server remains the source
of truth for validity.

## Application State Model

### Persisted AppState

`AppState` advances to schema 2 and persists only application policy:

```swift
nonisolated
struct AppState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    var hasCompletedOnboarding: Bool
    var isMaintenanceEnabled: Bool
}
```

`isAuthenticated` is removed. A Boolean in UserDefaults must not claim that a
usable session exists when Keychain data is missing, unreadable, expired, or
rejected by the server.

The AppState storage boundary retains its current properties:

- synchronous typed UserDefaults access;
- corrupt/unsupported-old recovery to the initial state;
- future-schema preservation and read-only behavior; and
- persistence-before-visible-mutation semantics.

Schema 1 migrates by preserving `hasCompletedOnboarding` and
`isMaintenanceEnabled` and discarding `isAuthenticated`. A missing Keychain
session then produces a guest Main state, even if schema 1 previously stored
`isAuthenticated = true`.

### Runtime root and session state

The root flow becomes:

```swift
enum AppFlow: String, Codable, Equatable, Sendable {
    case restoring
    case onboarding
    case maintenance
    case main
}
```

Policy order is exact:

1. session bootstrap incomplete -> Restoring;
2. maintenance enabled -> Maintenance;
3. onboarding incomplete -> Onboarding;
4. otherwise -> Main.

Maintenance therefore has priority over Onboarding after bootstrap. Neither
Authentication nor guest/authenticated state is an application root.

The app-scoped session store exposes UI-safe state without exposing tokens:

```swift
enum SessionState: Equatable, Sendable {
    case restoring
    case guest
    case unavailable(SessionUnavailableReason)
    case authenticated(UserProfile, availability: SessionAvailability)
}

enum SessionUnavailableReason: Equatable, Sendable {
    case secureStorageReadFailed
    case secureStorageCleanupFailed
}

enum SessionAvailability: Equatable, Sendable {
    case online
    case offline
}
```

Tokens remain actor-confined inside the session repository. ViewModels receive
profile and availability state, not raw bearer credentials.

`unavailable` is distinct from Guest. It represents a recoverable secure-store
read failure: public browsing remains available, protected actions explain the
problem and offer Retry, and the app does not delete the unread session.

### Startup and session restoration

Startup follows one ordered sequence:

1. Construct live or isolated dependencies.
2. Load and resolve persisted AppState synchronously.
3. Display Restoring while the session repository reads its versioned
   Keychain record.
4. If no session exists, resolve the session as Guest.
5. If the access token is locally unexpired, validate it through `/auth/me`.
   Success enters Authenticated/online, an unauthorized response continues to
   refresh, and transport failure enters Authenticated/offline with the cached
   profile.
6. If the access token is expired or `/auth/me` rejects it, attempt one
   refresh.
7. On refresh success, atomically replace the stored session and enter
   Authenticated/online.
8. On transport failure, keep the cached session and enter
   Authenticated/offline.
9. On an authoritative invalid-refresh response, remove the Keychain session
   and enter Guest.
10. On a Keychain system read failure, preserve the unread record and enter
    Session unavailable after bootstrap. A corrupt app-owned Codable record is
    removed and resolves to Guest; removal failure resolves to unavailable.
11. Resolve Maintenance, Onboarding, or Main through AppFlowPolicy.

JWT payload dates may be decoded only to schedule refresh. Local decoding is
not signature verification and never overrides a server response.

All simultaneous requests that discover an expired/unauthorized access token
join one single-flight refresh. A request may be retried once after that
refresh. Refresh failure must not recurse.

### Root transitions

- Completing Onboarding persists the completion flag before showing Main.
- “Replay Onboarding” from Services clears the completion flag, temporarily
  shows Onboarding, and returns to the preserved Main navigation after
  completion.
- Enabling demo Maintenance persists the flag and temporarily replaces Main.
  Disabling it returns every scene to its preserved navigation.
- Sign Out removes the Keychain session and switches only the session state to
  Guest. Main remains visible.
- Sign Out closes protected Favorites/Profile destinations and clears pending
  protected actions. Public product destinations remain open.
- An explicit demo navigation reset is the only user action that clears both
  Store and Services histories.

### Onboarding and Maintenance content

Onboarding is a short, coherent introduction rather than a generic routing
demo. Its pages explain browsing as a Guest, protected favorites and persistent
session behavior, and the Services playground. It requests no notification or
other system permission. The final explicit Continue action persists
completion.

Maintenance states that the demo store is temporarily unavailable, preserves
the hidden Main scene state, and includes “Disable Demo Maintenance” so a user
who enabled it from Services can always return. It performs no timer-driven or
remote maintenance check.

## Adaptive Shell and Scene Ownership

Main has exactly two sections:

- **Store** (`storefront` system image)
- **Services** (`wrench.and.screwdriver` system image)

iPhone and iPad use two native tabs. macOS uses the same two values in the
sidebar. The native macOS Settings scene remains available and displays the
same Store preferences shown from Profile on iOS/iPadOS; it is not a third
main section.

Each window owns:

- one selected `AppSection`;
- one Store `FlowRouter` path;
- one Services `FlowRouter` path;
- scene-local sheets and modal-flow presentation;
- one scene-local pending protected action; and
- one navigation-restoration checkpoint.

The application owns:

- AppState and root policy;
- the authenticated session;
- semantic Store repositories;
- low-level service instances;
- notification event handling; and
- local product/cart/favorite data.

Logging in or out in one window updates the shared session in all windows.
Navigation in one window never mutates another window's path. If multiple
windows have pending protected actions, each originating scene may resume its
own still-pending action after the shared session becomes authenticated.
Idempotent favorite upsert prevents duplicate data.

## Store Navigation and User Experience

### Store root

`StoreFlowView` owns one `NavigationStack`. Its root catalog provides:

- live products from DummyJSON;
- text search;
- category selection;
- remote pagination;
- a filters/sort sheet;
- grid/list presentation driven by typed preferences;
- Favorites, Profile, and Cart toolbar destinations; and
- loading, content, empty, error, retry, and incremental-loading states.

Remote pagination uses DummyJSON `limit` and `skip`. Changing search,
category, sort, or page size cancels the old request and resets remote paging.
Response metadata supplies `total`, `skip`, and `limit`.

### Typed Store routes

The Store push path contains only durable value routes:

```swift
enum StoreRoute: NavigationRoute {
    case product(Product.ID)
    case reviews(Product.ID)
    case favorites
    case profile
}
```

Selecting a related product pushes another `.product` route. The detail
ViewModel loads by ID, so restored paths and deep links do not encode an entire
remote object.

The product screen contains:

- product images, title, description, price, rating, and availability;
- reviews returned by the product payload;
- related products selected from the product category;
- Favorite and Add to Cart actions; and
- “Remind me” presentation.

Favorites and Profile are protected. Guests may browse the catalog, product
details, reviews, related products, cart, checkout, and reminders. The cart is
an app-local guest-capable cart and survives sign-in/sign-out. Favorites are
scoped to the authenticated DummyJSON user ID and remain stored but hidden
after sign-out until that user signs in again.

### Protected actions and Authentication

Scene-local protected actions are:

```swift
enum ProtectedStoreAction: Hashable, Sendable {
    case favorite(Product.ID)
    case openFavorites
    case openProfile
}
```

When a Guest invokes one:

1. store it in the originating scene router;
2. present an Authentication modal containing its own `NavigationStack`;
3. submit credentials to DummyJSON `/auth/login`;
4. persist the returned profile, access token, refresh token, and decoded
   expiry metadata as one versioned Keychain session;
5. publish Authenticated only after the Keychain write succeeds;
6. dismiss Authentication; and
7. consume and execute the protected action exactly once.

Cancel dismisses Authentication and clears only that scene's pending action.
Invalid credentials remain inline in Authentication. Passwords are never
stored. If login succeeds remotely but the Keychain write fails, the app does
not claim a durable authenticated state and does not execute the action.

Authentication uses username and secure password fields. The documented
DummyJSON demo credential can be filled with one labelled action; it is not
silently submitted. Authentication also explains that it is a public test
account and that no real personal data should be entered.

### Cart and checkout

Cart data is stored locally as one cart aggregate rather than as AppState or
navigation state. The cart supports quantity changes and item removal.

Checkout is an independent modal `NavigationStack`:

```text
Cart -> Delivery -> Review -> Success
```

Delivery values live only for the modal lifetime and are not persisted.
“Place Demo Order” performs no remote mutation or payment. Success removes the
single local cart aggregate and dismisses the flow. Cancelling preserves the
cart.

Checkout steps and modal presentation are not restored after process
termination.

### Store modal ownership

The following presentations are screen- or flow-owned and are not encoded in
the scene snapshot:

- filters and sort;
- product reminder configuration;
- Authentication;
- checkout; and
- destructive confirmation alerts.

## Deep Links and Notification Navigation

Supported application URLs are:

```text
apptemplate://store
apptemplate://store/product/<positive integer ID>
apptemplate://store/favorites
apptemplate://store/profile
apptemplate://services
apptemplate://services/<service identifier>
```

Service identifiers are stable raw values for `app-state`, `app-info`,
`user-defaults`, `keychain`, `local-database`, `remote-api`, and
`local-notifications`.

Product links are public. Favorites and Profile links become protected
actions for a Guest. Deep links received before scene restoration queue in the
existing scene lifecycle and apply after restoration. Links received while
Maintenance or Onboarding owns the root remain queued and replay when Main
becomes available.

Legacy `home`, `browse`, `projects`, and `settings` links no longer represent
product destinations and return the existing unknown-destination error rather
than silently opening an unrelated screen.

Local-notification opening selects Store and opens the referenced product in
one eligible scene through the existing notification navigation coordinator.

## Dependency and Repository Boundaries

`AppDependencies` continues to own low-level application services and gains
semantic repositories/stores composed from them. Downstream slices are narrow:

| Dependency slice | Contents |
| --- | --- |
| `StoreDependencies` | products, session, favorites, cart, preferences, reminders, AppInfo |
| `ServicesDependencies` | six low-level service protocols, AppState actions/status, session actions/status, redacted network diagnostics |
| `OnboardingDependencies` | AppState onboarding action only |
| `MaintenanceDependencies` | AppState maintenance action only |

Store ViewModels never receive the entire `AppDependencies` graph and never
import SwiftData, Security, UserNotifications, or raw UserDefaults APIs.

Store uses semantic protocols:

- `IProductRepository`
- `ISessionRepository`
- `IFavoritesRepository`
- `ICartRepository`
- `IStorePreferencesRepository`
- `IProductReminderRepository`

Services is an intentional developer-playground exception: each playground
ViewModel receives only the one low-level protocol it demonstrates. It uses
dedicated demo keys, identifiers, and records and must not expose or mutate
Store-owned secrets/data except through explicitly labelled semantic AppState
or session commands.

## Remote Products and Authentication

The remote boundary replaces the neutral `fetchExample` example with typed
DummyJSON operations for:

- product list/search with limit and skip;
- category list and products by category;
- product detail by ID;
- login;
- current authenticated profile;
- refresh; and
- explicit delay/status diagnostics used only by Services.

The existing Foundation network layer remains responsible for target
description, request building, transport, status validation, decoding,
cancellation, stubbing, adapters, and monitors. Feature code never constructs
URLs or bearer headers.

Live base URL is injectable and defaults to `https://dummyjson.com`. Every
target supplies a representative sample response. Preview and automated-test
graphs use controlled transports and never call the public host.

Services may display method, redacted URL, status, elapsed time, and decoded
response. It must never display or log:

- Authorization header values;
- access or refresh tokens;
- submitted passwords;
- raw Keychain session bytes; or
- unredacted transport errors that may include a request body.

## Keychain Session

The session repository stores one versioned Codable value under a dedicated
account such as `Store.AuthSession.schema-1`. The value contains:

- profile identity needed for offline UI;
- access token;
- refresh token; and
- decoded access/refresh expiry dates when present.

The live Keychain policy remains app-private,
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and nonsynchronizing.

Sign Out removes only the Store session account. It does not delete service
playground keys, favorites, cart, AppState, or Store preferences.

Services displays only session presence, cached username, availability, and
expiry timestamps. Validate and Refresh use semantic session operations; the
screen never reads or renders the real token strings.

## Local Database Models and Cursor Pagination

The SwiftData schema advances from V1 to V2 and retains the existing
`ExampleRecord` playground model while adding registered detached models for:

- a user-scoped favorite product snapshot; and
- one app-local cart aggregate.

The active schema and registry continue to match exactly. A lightweight V1 to
V2 migration preserves existing ExampleRecord data while adding the new
entities. Product snapshots store only the fields required to render a useful
offline favorite/cart row; they are not a remote cache or source of catalog
truth.

The generic `ILocalDatabaseService` contract remains unchanged. Pagination is
model/query semantics rather than a universal engine-imposed sorting rule.

`ExampleQuery` becomes:

```swift
struct ExampleQuery: Equatable, Sendable {
    let searchText: String?
    let afterID: String?
    let limit: Int
}
```

The adapter sorts by immutable ID ascending, applies the exclusive cursor,
then applies normalized search and limit. The Services repository requests
`pageSize + 1`, trims the extra record, and returns:

```swift
struct LocalDatabasePage<Value: Sendable, Cursor: Sendable>: Sendable {
    let values: [Value]
    let nextCursor: Cursor?
    let hasMore: Bool
}
```

Services permits page sizes from 1 through 50, safely below the adapter's
bounded query limit after the one-record lookahead. Search, page-size changes,
refresh, and any CRUD mutation reset the cursor. An insertion before the
cursor appears on refresh; an insertion after it appears on a later page.
Deleting records does not create offset-based duplicates.

## Typed UserDefaults and Store Preferences

AppState remains stored under the established `AppTemplate.AppState` physical
record. Store preferences use separate typed logical keys for:

- catalog layout (grid/list);
- sort selection; and
- preferred remote page size.

These are nonsensitive preferences. They are not AppState and cannot change
root policy.

The Services UserDefaults playground uses dedicated demo keys and demonstrates
all available key codecs:

- Bool;
- Int;
- Float;
- Double;
- String;
- Data;
- Date; and
- Codable.

Each supports typed Save, Read, and Remove. The Data example uses an explicit
UTF-8/hex presentation; the Codable example uses a small versioned demo value.
The screen reports typed service errors without exposing unrelated stored
values.

## Product Reminders and Local Notifications

### Store reminder experience

Product Detail offers “Remind me.” Permission is requested only after this
explicit action. The reminder sheet offers:

- 10 seconds for a quick test;
- a user-selected interval; and
- a selected calendar date/time.

The request ID is deterministic per product so rescheduling replaces the
pending reminder for that product. Content includes product title, price,
typed product metadata, and:

```text
apptemplate://store/product/<id>
```

The product screen reads pending notifications to display and cancel its
current reminder.

The Store notification category provides four actions:

1. Open Product;
2. Favorite;
3. Remind Later; and
4. Add Note (text input).

Favorite routes through the same protected-action policy as an in-app heart.
Remind Later schedules the same product ten minutes later. Add Note publishes
the submitted text to the process-local Services event log; it is explicitly
not durable product data.

The Store category enables dismissal reporting so the event stream can show a
dismiss event during manual testing.

The app attempts to download a product image to a temporary local file before
scheduling. Download/staging failure is nonfatal: it schedules text-only and
shows a warning. The low-level notification service itself remains local-file
only and does not acquire networking responsibility.

### Shared category catalog

Store and Services share one complete app-owned category catalog. Services may
edit/re-register its lab category, but every `setCategories` call includes the
required Store category so the playground cannot accidentally remove Store
actions.

### Services notification playground

The Local Notifications screen demonstrates every public service operation:

- read all settings without prompting;
- request any valid combination of alert, sound, badge, and provisional
  authorization;
- register categories;
- schedule immediate, interval, and calendar triggers;
- list pending and delivered snapshots;
- remove selected or all owned pending requests;
- remove selected or all owned delivered notifications;
- set and clear the badge; and
- subscribe to foreground, open, dismiss, button, text-input, and diagnostic
  events.

Basic content exposes title, subtitle, body, badge, default/none/named sound,
category, and deep link. An Advanced disclosure exposes thread/target IDs,
summary values, relevance score, passive/active interruption, foreground
presentation options, and typed metadata. A preset nested metadata value
demonstrates string, integer, double, Boolean, array, object, and null cases.

The category editor exposes button and text-input actions, per-action deep
links, foreground/destructive/authentication-required action options, hidden
preview title/subtitle/body behavior, category summary format, and dismissal
reporting. The attachment editor exposes type hint, hidden-thumbnail behavior,
thumbnail clipping rectangle, and thumbnail time.

The project includes small original demo image, audio, and video resources so
the attachment editor can exercise local attachment types and their thumbnail
options without downloading third-party media. The named notification sound
uses the bundled compatible audio resource.

The screen clearly distinguishes “accepted by Notification Center” from
“displayed by the operating system.” Denial never causes an automatic repeated
prompt or blocks unrelated Store behavior.

## Services Information Architecture

Services is a catalog grouped as follows:

### Application

1. **App State**
   - schema and persistence status;
   - Restoring/Onboarding/Maintenance/Main root;
   - Guest/Unavailable/Authenticated online/offline session;
   - last semantic mutation result;
   - Replay Onboarding, Enable Maintenance, Sign Out, and explicit navigation
     reset commands.
2. **App Info**
   - bundle display name;
   - short version; and
   - current platform as UI-derived context.

### Storage

3. **UserDefaults**
   - every typed codec and Save/Read/Remove operation using demo keys.
4. **Keychain**
   - Data, UTF-8 String, and versioned Codable Save/Read/Remove using demo
     accounts;
   - masked values; and
   - a separate redacted real-session status/Validate/Refresh section.
5. **Local Database**
   - fetch by ID;
   - single and batch upsert;
   - normalized search;
   - cursor pagination and Load More;
   - delete by ID and delete all;
   - loading, content, empty, error, and retry states.

### Connectivity

6. **Remote API**
   - product search, category, detail, and remote pagination;
   - login, profile validation, refresh, and sign out through the shared
     session repository;
   - redacted request/response summary; and
   - delay, cancellation, retry, and 400/401/404/500 diagnostics.
7. **Local Notifications**
   - the complete playground described above.

Every screen follows the existing feature capsule convention with separate
Model, State, ViewModel, View, and Navigation ownership where a route exists.
Each ViewModel receives only its required dependency.

## AppInfo Use in Store

Profile includes an About section with the injected display name and version.
The macOS Settings scene uses the same AppInfo service beside Store
preferences. No Feature reads `Bundle.main` directly.

## Navigation Snapshot Migration

`NavigationSnapshot` advances from schema 4 to schema 5 and contains:

- selected Store/Services section;
- Store path;
- Services path; and
- `lastAppliedTransitionID`.

Sheets, alerts, checkout, Authentication, and protected actions are not
persisted.

Schemas 2, 3, and 4 migrate to:

- selected section Store;
- empty Store path;
- empty Services path; and
- the previous transition checkpoint when schema 4 provides one.

The old example routes have no honest product equivalent, so they are not
invented or partially translated. Corrupt and unsupported-old data resets.
Future-schema data remains preserved and snapshot writes stop, matching the
current downgrade-safety rule.

## Failure and Cancellation Semantics

### General

- Cancellation exits silently and never becomes a user-visible error.
- Async ViewModels ignore stale responses from superseded searches/pages.
- Every destructive action is explicit and scoped to demo-owned data.
- No service silently falls back from live persistence to in-memory storage.

### Remote and session

- Catalog failure shows Error/Retry while local favorites and cart remain
  available.
- Invalid credentials remain in Authentication and preserve the pending
  action.
- Keychain persistence failure prevents an authenticated transition.
- One 401 may trigger one joined refresh and one request retry.
- Temporary transport failure preserves Authenticated/offline.
- Authoritative invalid refresh clears the session and protected routes.
- Diagnostics redact credentials and tokens.

### Local database

- Initialization, validation, read, and write errors remain distinct.
- Failed favorites/cart writes do not optimistically claim success.
- CRUD/search mutation resets Services pagination before reloading.
- Checkout success dismisses only after the cart delete succeeds.

### Notifications

- Denied permission leaves Store usable and explains that system settings
  control delivery.
- Attachment acquisition failure falls back to text-only at the product use
  case boundary.
- A schedule failure does not display a false “reminder set” state.
- Pending/delivered lists tolerate owned unreadable snapshots.

### AppState

- A rejected AppState persistence mutation does not transition roots.
- Future AppState remains read-only and is never overwritten.
- Maintenance and onboarding controls surface rejection rather than claiming
  completion.

## Preview, UI-test, and Test Isolation

Preview and automated-test graphs use:

- controlled in-memory network transports with target sample responses;
- fresh in-memory Keychain services;
- fresh in-memory UserDefaults/AppState storage;
- fresh in-memory SwiftData containers with the production registry; and
- fresh in-memory Local Notification graphs.

No preview or automated test:

- contacts DummyJSON;
- reads or writes the live Data Protection Keychain;
- opens the live disk SwiftData store;
- displays a system notification prompt;
- installs a real notification request; or
- shares mutable service state with another test graph.

## Test Strategy

### Unit and contract tests

Tests cover:

- AppState schema 1 to 2 migration, repair, future-schema preservation, and
  persistence rejection;
- exact root policy priority and root-history preservation;
- missing, valid, expired, offline, refreshed, rejected, and corrupt session
  restoration, plus recoverable Keychain read failure;
- single-flight refresh and one-retry limits;
- Keychain-write failure after successful remote login;
- protected action success, cancellation, one-time consumption, deep links,
  and multi-window isolation;
- Store and Services route encoding/restoration;
- navigation snapshot 2/3/4 to 5 migration;
- product search/category/detail/pagination mapping and stale-request
  cancellation;
- favorites user scoping and app-local cart semantics;
- all UserDefaults codecs and Keychain Data/String/Codable conveniences;
- local-database CRUD, normalized search, batch behavior, and cursor
  pagination, including insertion/deletion around the cursor;
- every Local Notification public operation, trigger, category/action type,
  attachment type, metadata type, event, deep link, badge operation, and
  owned-removal rule;
- reminder text-only fallback; and
- ViewModel loading, content, empty, error, retry, and cancellation states.

### UI tests

The isolated UI-test graph covers:

- first launch -> Onboarding -> Store;
- catalog -> product -> reviews -> related product;
- filters sheet;
- Guest favorite -> Authentication -> automatic favorite completion;
- Authentication cancel and invalid credentials;
- Favorites/Profile protection and Sign Out without leaving Main;
- cart -> checkout -> success;
- product and protected deep links;
- Maintenance preserve/return behavior;
- Store/Services path independence;
- AppState playground commands;
- UserDefaults, Keychain, Local Database CRUD/pagination, Remote stub, and
  Local Notification in-memory playground actions; and
- adaptive navigation on iPhone, iPad, and macOS.

### Manual live verification

Manual verification covers the two environment-owned behaviors that automated
tests deliberately isolate:

- real DummyJSON product/login/profile/refresh requests; and
- real system notification permission, foreground delivery, actions,
  attachments, pending/delivered lists, and deep-link routing.

## Replacement and Cleanup

The implementation removes superseded example Feature sources and their tests
only after Store/Services replacements compile and their corresponding tests
pass. It retains reusable infrastructure and UI components. Documentation and
localization are updated so no README, screen, route, test, or string presents
Home/Browse/Projects/Settings as the active examples.

Existing unrelated working-tree changes remain outside this work.

## Acceptance Criteria

The design is complete when implementation can demonstrate all of the
following:

1. Main exposes exactly Store and Services on all supported platforms.
2. Store is useful as Guest and Authentication is a scene-local modal, not a
   root.
3. A protected action resumes exactly once after persistent login.
4. Relaunch restores a Keychain session; access expiry refreshes; transport
   failure preserves offline authentication; invalid refresh returns Guest.
5. Sign Out is explicit, removes session tokens, and does not leave Main.
6. AppState contains no authentication Boolean and migrates schema 1 safely.
7. Maintenance and replayed Onboarding preserve Main navigation.
8. Store exercises all six services through semantic product behavior.
9. Services exposes App State plus a manual example for every public operation
   of AppInfo, UserDefaults, Keychain, Local Database, Remote, and Local
   Notifications.
10. Local Database demonstrates stable cursor pagination combined with search
    and CRUD.
11. Live Remote uses DummyJSON while preview/unit/UI tests remain fully
    deterministic and offline.
12. Product notifications support permission, three trigger styles,
    attachment fallback, four actions, deep links, cancellation, and status.
13. Navigation is scene-local, session is app-global, and multi-window behavior
    is tested.
14. Old example routes and documentation are removed without discarding
    reusable infrastructure.
15. Complete macOS, iPhone, and iPad verification passes with warnings treated
    as errors and no failed or skipped required tests.
