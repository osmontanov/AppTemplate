# Connected Mini Store and Service Playground Design

## Status

The user approved this design section by section on 2026-08-13, then approved
a detailed architecture, feasibility, security, and UX review on the same
date. This revision incorporates that review and is the normative input to the
implementation plans. Implementation is intentionally split into sequential,
independently testable phases rather than treated as one atomic rewrite.

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
favorite, opening Favorites, or opening the Account section is protected;
Profile's Settings/About shell remains public. The app presents Authentication,
stores a successful session securely, and then continues the original action
exactly once.

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

The work is delivered in ordered phases. Each phase must leave the project
compiling, its focused tests passing, and all still-active legacy examples
working until their replacements are ready. Advanced notification authoring
is deliberately later than the connected Store, session, and basic reminder
flows.

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
refresh token requires a new login. JWT `exp` values are optional scheduling
metadata rather than a promised lifetime; DummyJSON remains the source of
truth for validity.

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

Migration has an explicit resolution rather than being treated as corrupt
data. The store decodes schema 1 into schema 2, attempts to persist schema 2,
and only then marks persistence writable. If that migration write fails, the
two decoded policy flags remain visible because they truthfully reflect the
persisted schema-1 value, but AppState becomes read-only and exposes a
`migrationSaveFailed` diagnostic. It never overwrites the old bytes with the
initial state.

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

`AppFlowPolicy` resolves both persisted AppState and the local session
bootstrap phase. Policy order is exact:

1. maintenance enabled -> Maintenance;
2. onboarding incomplete -> Onboarding;
3. local Keychain read incomplete -> Restoring;
4. otherwise -> Main.

Maintenance and Onboarding do not wait for a remote server. The app-scoped
session bootstrap may continue behind either root. Restoring covers only the
bounded local secure-store read for a returning user whose onboarding is
already complete. `/auth/me` and refresh never hold public Store navigation or
the Maintenance escape action behind a full-screen network wait. Neither
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
    case validating
    case online
    case offline(SessionOfflineReason)
}

enum SessionOfflineReason: Equatable, Sendable {
    case transport
    case serverUnavailable
    case rateLimited
    case responseInvalid
    case secureStorageWriteFailed
}
```

Tokens remain actor-confined inside the session repository. ViewModels receive
profile and availability state, not raw bearer credentials.

`unavailable` is distinct from Guest. It represents a recoverable secure-store
read or cleanup failure: public browsing remains available, protected actions
explain the problem and offer Retry, and the app does not claim that the
unread or undeleted session is absent. `authenticated/validating` exposes the
cached profile while server validation proceeds. Every offline reason keeps
local user-scoped favorites available but disables remote authenticated
operations until validation succeeds.

### Startup and session restoration

One app-owned `SessionController` starts and retains an idempotent bootstrap
task. No scene owns or cancels the underlying task. A token-owning repository
actor performs Keychain and remote work; the `@MainActor` controller publishes
only UI-safe state plus a monotonically increasing `sessionRevision`.

Startup follows one ordered sequence:

1. Construct live or isolated dependencies, the repository actor, controller,
   injected wall clock, and injected sleep/refresh scheduler.
2. Load and resolve persisted AppState synchronously.
3. Start the app-owned local Keychain read and mark Session as Restoring.
4. Resolve Maintenance or Onboarding immediately when either policy applies;
   otherwise show Restoring until the local read completes.
5. If no record exists, publish Guest, mark the local bootstrap resolved, and
   resolve Main when policy permits.
6. If a structurally valid record exists, publish its cached profile as
   Authenticated/validating, mark the local bootstrap resolved, and allow Main.
7. If its access token is locally unexpired, call `/auth/me`; success publishes
   Authenticated/online and an explicit unauthorized response starts one
   refresh.
8. If its access token is locally expired, start one refresh without first
   calling `/auth/me`.
9. On refresh success, persist the complete replacement session as one
   Keychain value before publishing Authenticated/online.
10. Transport failures publish offline/transport; 408 or 5xx publishes
    offline/serverUnavailable; 429 publishes offline/rateLimited; and a
    non-authoritative decoding/contract failure publishes
    offline/responseInvalid. These failures never delete the cached session.
11. Only an endpoint-specific authoritative authentication rejection, such as
    the mapped invalid-token response, may reject credentials. On invalid
    refresh, delete the Keychain record before publishing Guest. Cleanup
    failure publishes unavailable/secureStorageCleanupFailed instead.
12. A Keychain system read failure preserves the unread record and publishes
    unavailable/secureStorageReadFailed after local bootstrap. A corrupt
    app-owned envelope is removed and resolves to Guest; removal failure
    resolves to unavailable/secureStorageCleanupFailed.

The three-second local bootstrap deadline is implemented as one race between
the injected sleep and one repository read, identified by a monotonically
increasing bootstrap-attempt ID. When the deadline wins, the controller marks
local bootstrap resolved, publishes unavailable/secureStorageReadFailed,
cancels the read task on a best-effort basis, and invalidates that attempt ID.
A non-cancellable late read may finish inside the repository but cannot mutate
Keychain, publish state, or replace the winning result. Retry creates a fresh
attempt ID and performs a fresh read; it never adopts the stale completion.

Authentication responses use endpoint-specific classification. A status code
alone is not enough to destroy a session; an error body must first decode as
the documented DummyJSON authentication error shape for that endpoint.

| Endpoint/result | Classification and effect |
| --- | --- |
| `/auth/login` 400, 401, or 403 with the mapped authentication error shape | Inline invalid credentials; retain Authentication and its pending protected action |
| `/auth/me` 401 or 403 with the mapped authentication error shape | Join or start the single-flight refresh; do not delete credentials |
| `/auth/refresh` 400, 401, or 403 with the mapped authentication error shape | Authoritative credential rejection; delete the stored session before publishing Guest |
| Any auth endpoint 408 or 429 | Preserve credentials and publish the corresponding server-unavailable or rate-limited result |
| Any auth endpoint 500 through 599 | Preserve credentials and publish server unavailable |
| Transport failure | Preserve credentials and publish offline/transport when a cached session exists |
| Decode failure, an unknown status, or a status/body combination not mapped above | Preserve credentials and publish responseInvalid; never infer credential rejection |

The session state machine also defines the following durable-boundary rules:

| Situation | Required result |
| --- | --- |
| Remote login succeeds, initial Keychain write fails | Keep Authentication open, retain the scene pending action, publish no authenticated state, and offer Retry/Cancel |
| Refresh succeeds, replacement Keychain write fails | Keep the previously stored session and cached profile, publish authenticated/offline/secureStorageWriteFailed, and offer Retry |
| Explicit Sign Out deletion fails | Keep the previous authenticated state, report that Sign Out failed, and offer Retry; never claim Guest |
| Invalid refresh cleanup fails | Publish unavailable/secureStorageCleanupFailed; never claim Guest |
| Request is cancelled | Leave the latest published state unchanged and show no user-visible network error |
| Concurrent login attempts | Reject a second submission while the first is active |

When a remote login or refresh succeeds but its Keychain write fails, the
repository actor retains one generation-bound `PendingCredentialCandidate`.
It contains the complete replacement envelope and never leaves the actor.
The UI receives only an opaque `SessionPersistenceRetryToken`; retrying that
token repeats the same Keychain mutation without repeating the remote request.
The candidate is cleared after a successful write, Authentication Cancel,
Sign Out, a new login attempt, an authoritative credential rejection, or any
session-generation mismatch. A newer candidate replaces an older candidate.
This rule also covers a server-rotated refresh token: only the repository owns
it while persistence is being retried.

JWT payload dates may be decoded only to schedule refresh. Local decoding is
not signature verification and never overrides a server response.

All simultaneous requests that discover an expired/unauthorized access token
join one single-flight refresh. A request may be retried once after that
refresh. Refresh failure must not recurse.

Repository operations capture the current monotonically increasing session
generation and recheck it after every suspension and immediately before each
Keychain mutation or published result. Sign Out increments the generation and
invalidates the shared refresh task before attempting deletion. Stale
bootstrap/login/refresh completions therefore cannot recreate a signed-out or
newly replaced session.

### Root transitions

- Completing Onboarding persists the completion flag before showing Main.
- “Replay Onboarding” from Services clears the completion flag, temporarily
  shows Onboarding, and returns to the preserved Main navigation after
  completion.
- Enabling demo Maintenance persists the flag and temporarily replaces Main.
  Disabling it returns every scene to its preserved navigation.
- Restoring, Onboarding, and Maintenance policy transitions use
  `historyAction: .preserve`; only an explicit scene navigation command uses
  `.reset`.
- Successful Sign Out removes the Keychain session and switches only the
  session state to Guest. Main remains visible. Failed deletion leaves the
  previous state visible with a retryable error.
- Every scene observes `sessionRevision`. Successful Sign Out removes protected
  Favorites destinations and clears scene-local protected actions while public
  product, review, cart, and profile destinations remain open.
- Profile keeps a scene-local selected subsection. Guest, unavailable session,
  or a change to a different authenticated user forces a selected Account
  subsection back to the public Profile overview and clears any cached Account
  presentation data. Preferences and About remain visible.
- “Reset Navigation in This Window” is the only command that clears both Store
  and Services histories, and it never mutates another window.

### Onboarding and Maintenance content

Onboarding is a short, coherent introduction rather than a generic routing
demo. Its pages explain browsing as a Guest, protected favorites and persistent
session behavior, and the Services playground. It requests no notification or
other system permission. The final explicit Continue action persists
completion.

Maintenance states that demo maintenance temporarily hides both Store and
Services to demonstrate app-wide root policy, preserves the hidden Main scene
state, and includes “Disable Demo Maintenance” so a user who enabled it from
Services can always return. It performs no timer-driven or remote maintenance
check.

## Adaptive Shell and Scene Ownership

Main has exactly two sections:

- **Store** (`storefront` system image)
- **Services** (`wrench.and.screwdriver` system image)

iPhone uses two native tabs. iPad uses native `sidebarAdaptable` tab behavior,
so Store and Services remain the only two sections while the system may adapt
their presentation. macOS uses the same two values in a sidebar. The native
macOS Settings scene remains available and displays the same Store preferences
and About content shown from Profile on iOS/iPadOS; it is not a third main
section.

Compact-width screens use push navigation. Regular-width iPad and macOS use a
list/detail presentation inside the selected section where it improves dense
Services editors and the catalog/detail relationship. The minimum macOS window
content size is 820 by 620 points. On compact iPhone, overflow destinations
move into one labelled More menu before primary search, filter, or cart actions
are removed.

Each window owns:

- one selected `AppSection`;
- one inspectable `[StoreRoute]` path bridged to a Store `NavigationStack`;
- one inspectable `[ServicesRoute]` path bridged to a Services
  `NavigationStack`;
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
`SessionController` publishes `SessionPresentation(state, revision)` and
increments the process-local revision for every committed public session-state
change; the revision is never persisted. Every scene remembers its last
applied revision and observes newer presentations exactly once.

Scene startup order is exact: decode or migrate its snapshot, apply the current
root transition, reconcile the first non-restoring session presentation, mark
the scene ready, and finally apply the latest deferred valid link when Main is
available. A Guest-to-Authenticated transition dismisses Authentication in
every scene. Each scene removes its pending action before executing it, making
consumption exactly once from that scene's perspective; failed execution is
shown but not automatically replayed. Idempotent favorite upsert prevents
duplicate persisted data. On Guest restoration, Sign Out, unavailable session,
or authenticated user-identity change, each typed Store path removes
`.favorites`, clears pending protected actions, resets a selected protected
Account subsection to the Profile overview, and clears cached Account
presentation data while retaining the public `.profile` route and all other
public routes. Validating/online/offline changes never alter navigation.

The Services destination set and its external tags are fixed:

```swift
enum ServicesRoute: NavigationRoute {
    case appState
    case appInfo
    case userDefaults
    case keychain
    case localDatabase
    case remoteAPI
    case localNotifications
}
```

Its manual Codable representation uses one `tag` with the exact values
`app-state`, `app-info`, `user-defaults`, `keychain`, `local-database`,
`remote-api`, and `local-notifications`. Store routes likewise use an explicit
`tag` (`product`, `reviews`, `favorites`, `cart`, or `profile`) and a positive
`productID` only for product-bearing cases. No synthesized case name or Swift
type name is part of schema 5.

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

Remote pagination uses DummyJSON `limit` and `skip`. Query mode is explicit:

```swift
enum ProductQueryMode: Equatable, Sendable {
    case all
    case search(String)
    case category(String)
}
```

Search and category are mutually exclusive because DummyJSON documents them
as separate endpoints. The UI never claims a combined server-side filter.
Only sort values supported by the active endpoint are enabled. Search is
debounced, and changing query mode, sort, or page size cancels the old request
and resets paging. Stale responses are ignored, page results are deduplicated
by product ID, and response metadata supplies `total`, `skip`, and `limit`.

### Typed Store routes

The Store push path contains only durable value routes:

```swift
enum StoreRoute: NavigationRoute {
    case product(Product.ID)
    case reviews(Product.ID)
    case favorites
    case cart
    case profile
}
```

Selecting a related product pushes another `.product` route. The detail
ViewModel loads by ID, so restored paths and deep links do not encode an entire
remote object.

The product screen contains:

- product images, title, description, price, rating, and availability;
- a review summary and labelled “See all reviews” control that pushes
  `.reviews(productID)`;
- related products selected from the product category;
- Favorite and Add to Cart actions; and
- “Remind me” presentation.

Favorites are protected. Profile is a public Settings/About shell whose
Account section is protected; a Guest can change nonsensitive Store
preferences and read About on every platform. Guests may browse the catalog,
product details, reviews, related products, cart, checkout, and reminders. The
cart is an app-local guest-capable cart and survives sign-in/sign-out.
Favorites are scoped to the authenticated DummyJSON user ID and remain stored
but hidden after sign-out until that user signs in again. Favorites and the
Account section state clearly: “Saved on this device for this demo profile.”

### Protected actions and Authentication

Scene-local protected actions are:

```swift
enum ProtectedStoreAction: Hashable, Sendable {
    case favorite(Product.ID)
    case openFavorites
    case openAccount
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
Authentication remains open, retains the pending action, presents a
secure-storage-specific error, and offers Retry Persistence and Cancel.

Authentication uses username and secure password fields. The documented
DummyJSON demo credential can be filled with one labelled action; it is not
silently submitted. Authentication also explains that it is a public test
account and that no real personal data should be entered.

### Cart and checkout

Cart data is stored locally as one revisioned cart aggregate rather than as
AppState or navigation state. An app-scoped actor repository serializes
`add`, `setQuantity`, `remove`, and `checkout(expectedRevision:)` so concurrent
windows cannot lose an update. `.cart` is a durable Store destination; checkout
is launched from that destination.

Checkout is an independent modal `NavigationStack`:

```text
Cart -> Delivery -> Review -> Success
```

Delivery begins with clearly fictional prefilled data and says that nothing is
sent or saved. Values live only for the modal lifetime. Minimal inline
validation identifies missing required fields and moves focus to the first
error. “Place Demo Order” performs no remote mutation or payment. Success
deletes the cart only if its expected revision is still current, remains
visible until the user chooses Done, and then dismisses. A revision conflict
returns to Cart with an explanation instead of deleting newer items.

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

Product and Profile-shell links are public. Favorites links and an Account
entry inside Profile become protected actions for a Guest. Deep links received
before scene restoration queue in the existing scene lifecycle and apply after
restoration. While Maintenance or Onboarding owns the root, each scene retains
only its latest deferred navigation link; a newer link replaces the older one.
This deferred navigation slot is distinct from the scene's pending protected
action. URLs are parsed and validated before deferral, so a later invalid URL
does not erase a valid deferred intent.

Application is deterministic and idempotent:

- `store` selects Store and clears the Store path;
- `store/product/<id>` selects Store and replaces its path with one product;
- `store/favorites` replaces the path when authenticated or becomes the
  scene's latest protected action when Guest;
- `store/profile` selects Store and replaces its path with Profile;
- `services` selects Services and clears the Services path; and
- `services/<id>` selects Services and replaces its path with that service.

A newer protected action replaces the previous unconsumed protected action in
the same scene. Duplicate delivery cannot append duplicate destinations.

Legacy `home`, `browse`, `projects`, and `settings` links no longer represent
product destinations. Unknown or malformed links leave the current selection
and paths untouched, publish a typed unknown-destination result, and offer
explicit “Open Store” and “Open Services” recovery actions rather than
silently opening or popping an unrelated screen.

For both a default notification tap and the custom Open Product action, the
typed notification dispatcher owns metadata validation and creates one
`.openProduct(productID)` intent. The notification navigation coordinator owns
only eligible-scene selection and delivery of that typed intent; it never
interprets action identifiers or notification metadata.

## Dependency and Repository Boundaries

`AppDependencies` continues to own low-level application services and gains
semantic repositories/stores composed from them. Downstream slices are narrow:

| Dependency slice | Contents |
| --- | --- |
| `StoreDependencies` | products, session, favorites, cart, preferences, reminders, AppInfo |
| `ServicesDependencies` | scoped playground protocols, AppState actions/status, session actions/status, redacted network diagnostics |
| `OnboardingDependencies` | AppState onboarding action only |
| `MaintenanceDependencies` | AppState maintenance action only |

The Services App State screen additionally receives a narrow scene-owned
`ISceneNavigationActions` after that scene constructs its router. Resetting the
current scene is not an AppState or app-global dependency.

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
ViewModel receives only the one scoped protocol it demonstrates. UserDefaults
and Keychain labs use a physically separate `AppTemplate.ServicesLab`
namespace/service plus a closed key catalog, so a typo cannot address AppState,
Store preferences, or the real auth-session account. The Local Database lab
operates only on `ExampleRecord`. Notification operations whose contract is
necessarily app-wide are not described as isolated and require an impact
summary and confirmation.

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

Authentication requests use a dedicated `URLSession` built from an ephemeral
configuration with `httpShouldSetCookies = false`, `httpCookieStorage = nil`,
`urlCredentialStorage = nil`, and `urlCache = nil`. Every auth request also
sets `httpShouldHandleCookies = false`. Redirect handling never forwards
credentials or Authorization to a different origin. DummyJSON response cookies
are neither stored nor resent, so Keychain remains the sole durable session
store and Sign Out cannot leave a cookie credential behind.

Live base URL is injectable and defaults to `https://dummyjson.com`. Every
target supplies a representative sample response. Preview and automated-test
graphs use controlled transports and never call the public host.

The Services recorder never consumes a raw `NetworkRequestContext`, target,
`NetworkResponse`, or `NetworkError`. The network boundary emits an allowlisted
`NetworkDiagnosticEvent` containing only operation ID, method, safe path,
query-key names, status class, elapsed time from an injected clock, safe failure
category, and endpoint-specific response summary. A bounded actor retains the
last 100 events. Services may render only that DTO. It must never receive,
display, retain, or log:

- Authorization header values;
- access or refresh tokens;
- submitted passwords;
- raw Keychain session bytes; or
- response bytes or unredacted errors that may include a request body.

Sentinel tests place recognizable secrets in a URL value, header, login body,
target, successful response, error response, and nested error, then assert
that none can be found in the diagnostic DTO or its rendered description.

## Keychain Session

The session repository stores one versioned Codable envelope under the stable
physical account `Store.AuthSession`. The schema version lives inside the
envelope rather than in the Keychain account name, so a future schema cannot
orphan an undiscoverable credential. The value contains:

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

The SwiftData schema advances from V1 to V2. V1 remains frozen and is never
rewritten. V2 declares a V2 `StoredExampleRecord` with the same persisted
identity and fields, then adds registered detached models for:

- a user-scoped favorite product snapshot; and
- one app-local cart aggregate.

All production adapters, container factories, and the model registry point to
V2 entity types, and the active schema/registry identity sets match exactly. An
explicit lightweight V1-to-V2 migration stage preserves existing ExampleRecord
data while adding the new entities. A disk acceptance test creates and closes
a store using a genuinely V1-only container, reopens it through V2, verifies
the original bytes, exercises the new entities, and rechecks registry/schema
bijection. Product snapshots store only the fields required to render a useful
offline favorite/cart row; they are not a remote cache or source of catalog
truth. Reviews decode only fields displayed by the UI and never persist or
diagnose reviewer email.

Favorite identity is one canonical key derived from `(userID, productID)`.
Cart identity is one constant aggregate ID and its model carries a revision
used by atomic repository commands.

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

The Services create form restricts new ExampleRecord IDs to nonempty lowercase
ASCII letters, digits, `-`, `_`, and `.`. The physical V1 adapter contract,
however, already accepts any exact nonblank String and remains backward
compatible. Migrated rows with spaces, mixed case, or Unicode IDs therefore
remain visible, pageable, editable under their existing identity, and
deletable; they are not silently rewritten. The Services repository enforces
the stricter rule only when creating a new identity.

The adapter applies `id > afterID` inside the SwiftData fetch with the same
ascending ID `SortDescriptor`; cursor comparison is never reimplemented in
Swift. It then performs normalized payload search over the ordered post-cursor
scan and applies the limit. It must not restart each page's filtered scan
before the cursor. Persistent-store tests include ASCII, whitespace, mixed-case,
and Unicode legacy IDs and prove stable ordering across reopen. The Services
repository requests `pageSize + 1`, trims the extra record, and returns:

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
root policy. The semantic preference repository provides explicit defaults,
validates page size, repairs only its own corrupt keys, and broadcasts changes
to every Store window and the macOS Settings scene.

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
values. Data/hex input and rendered output have explicit size bounds. Dedicated
demo values may be revealed by a labelled action; real session values remain
permanently redacted.

## Product Reminders and Local Notifications

### Store reminder experience

Product Detail offers “Remind me.” Permission is requested only after this
explicit action. The reminder sheet offers:

- 10 seconds for a quick test;
- a user-selected interval; and
- a selected calendar date/time.

The interval must be finite and positive; repeating intervals use the
low-level service minimum of 60 seconds. Calendar input must resolve to a
strict future date. Before scheduling, the sheet displays the localized
resolved fire date/time, time zone, and price using `FormatStyle`. Calendar
reminders retain the selected absolute date across later time-zone changes.
Authorization is requested before any product-image download begins.

The request ID is deterministic per product so rescheduling replaces the
pending reminder for that product. Content includes product title, price,
typed product metadata, and:

```text
apptemplate://store/product/<id>
```

The product screen reads pending notifications to display and cancel its
current reminder.

The Store notification category provides three actions, ordered by usefulness
on limited-space banners:

1. Open Product;
2. Favorite;
3. Remind Later.

Favorite is a foreground action and routes through the same protected-action
policy as an in-app heart in one selected eligible scene. A scene is eligible
only after restoration is complete, Main owns its root, and its typed
navigation actions are registered and ready. The OS
`authenticationRequired` action option means device unlock and is never
presented as Store login. Remind Later schedules the same product ten minutes
later as background-safe semantic work before the notification response
callback completes. Repeated action delivery is idempotent.

The Store category enables dismissal reporting so the event stream can show a
dismiss event during manual testing.

After permission permits scheduling, a shared injected image loader attempts
to download a product image to a temporary local file. It requires HTTPS,
allows only configured image origins and redirects, applies time, byte, MIME,
signature, and decoded-dimension bounds, supports cancellation, and removes
the downloaded source with `defer`. Download/staging failure is nonfatal: the
use case schedules text-only and shows a warning. The low-level notification
service itself remains local-file only and does not acquire networking
responsibility.

### Shared category catalog

An app-owned category composer is the only live caller allowed to replace the
system catalog. Store registers an immutable Store contribution. Services may
edit only its lab contribution. The composer validates and atomically commits
their union, serializes concurrent bootstrap/lab updates, and preserves the
previous union after rejection. Caller discipline cannot accidentally remove
Store actions.

An app-scoped typed notification action dispatcher owns Store category/action
semantics, metadata validation, default-tap behavior, custom Open Product,
Favorite, Remind Later, and response-level deduplication. For UI work it asks
the notification navigation coordinator to deliver a typed command such as
`.protected(.favorite(productID))` to the most recently active eligible scene;
it performs background-safe Remind Later work directly. The coordinator does
not subscribe to the event history and does not reinterpret the response.
Each response has one semantic owner and is consumed at most once.

The live delegate bridge, category composer, and dispatcher are constructed
and connected before scenes become active. The bridge first publishes a safe
observation event, then directly awaits exactly one dispatcher call before it
completes the system callback. A cold-launch response is routed through that
dispatcher and its UI intent is held by the navigation coordinator when no
scene is eligible; it does not depend on a later Services subscription.
Coordinator intents are FIFO, bounded to the newest 32, and delivered only
after an eligible scene registers. Overflow drops the oldest intent and emits
a safe diagnostic event. The system completion callback is invoked after
background-safe work finishes or after a UI command is safely queued. Internal
observation streams use bounded buffering and cannot grow without limit.

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

The event log is a bounded, replayable, process-local history of the last 100
safe summaries with sequence and timestamp plus an explicit Clear command. It
is available even if the Services screen subscribed after the event. Note text
and arbitrary notification metadata are never written to OSLog.

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

A Services-only “Add Note” text-input preset demonstrates the text response
contract and records a safe summary in the bounded event history. Store action
IDs are fixed category-level identifiers; product identity comes from typed
notification metadata inspected by the action dispatcher, never from a
product-specific category action deep link.

The project includes small original demo image, audio, and video resources so
the attachment editor can exercise local attachment types and their thumbnail
options without downloading third-party media. The named notification sound
uses the bundled compatible audio resource.

The screen clearly distinguishes “accepted by Notification Center” from
“displayed by the operating system.” Denial never causes an automatic repeated
prompt or blocks unrelated Store behavior. It also explains that banners show
only the first two actions, while expanded notification surfaces may show more.
Advanced controls unavailable or visually ineffective on the current platform
are disabled with an explanation rather than appearing broken.

The lab uses request IDs under a dedicated logical prefix. Selected removal is
lab-scoped. The public low-level `removeAllPending`, `removeAllDelivered`, and
badge operations necessarily affect all app-owned notifications or the app
icon, including Store state. Their buttons display that impact, require
confirmation, and report exactly what changed.

## Services Information Architecture

Services is a guided catalog, not a raw capability dump. The catalog displays
a recommended learning order. Every service screen uses the same structure:

1. why Store uses the service;
2. one safe preset;
3. a labelled Try It action;
4. the expected result;
5. the current/actual result;
6. Reset Demo Data; and
7. an Advanced disclosure containing complete contract coverage.

The catalog visually separates isolated labs from app-wide controls. App-wide
controls keep an impact summary visible instead of borrowing the isolated-lab
appearance.

Services is grouped as follows:

### Application

1. **App State**
   - schema and persistence status;
   - Restoring/Onboarding/Maintenance/Main root;
   - Guest/Unavailable/Authenticated validating/online/offline session;
   - last semantic mutation result;
   - a **Navigation & Scenes** subsection showing this window's selected
     section, typed paths, restoration result/checkpoint, sample deep-link
     launchers, and second-window guidance;
   - Replay Onboarding, Enable Maintenance, and Sign Out as clearly labelled
     app-wide controls; and
   - Reset Navigation in This Window through injected scene navigation
     actions.
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
   - hidden-by-default demo values with explicit reveal; and
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

The following action-scope contract is normative:

| Action | Scope and retained state | Confirmation and recovery |
| --- | --- | --- |
| Replay Onboarding | All windows temporarily leave Main; both paths and data remain | Explain all-window impact; completion or app relaunch can return according to persisted policy |
| Enable Maintenance | All windows temporarily hide Main; both paths and all data remain | Confirm app-wide effect; Maintenance always exposes Disable |
| Sign Out | Shared session only; cart/preferences remain, local favorites stay stored but hidden | Confirm account effect; deletion failure keeps authenticated state and offers Retry |
| Reset Navigation in This Window | Current window's Store/Services paths, selected section, deferred link, pending action, and scene modals | Confirm current-window scope; no data deletion; no all-window variant in this cycle |
| Delete All Example Records | Services `ExampleRecord` entities only | Confirm record count; Store entities remain; action is not undoable |
| Remove All Pending/Delivered Notifications | All app-owned Store and lab notification requests of the selected kind | Confirm that Store reminders may be removed; lists can be refreshed afterward |
| Set/Clear Badge | App icon globally | Explain platform-visible side effect; Clear restores zero |

Every screen follows the existing feature capsule convention with separate
Model, State, ViewModel, View, and Navigation ownership where a route exists.
Each ViewModel receives only its required dependency.

## Accessibility, Localization, and Adaptive Presentation

All new user-visible text uses the String Catalog. Product prices use localized
USD currency `FormatStyle` because DummyJSON does not return a currency code;
the UI labels this as a demo assumption. Dates, reminder summaries, durations,
and counts use their localized formatters. Long-string verification covers at
least one expansion-prone locale, and layout is checked in one right-to-left
locale.

Acceptance includes:

- Dynamic Type through accessibility sizes without clipped required actions;
- meaningful VoiceOver labels, values, traits, reading order, and announcements
  for loading, errors, saved favorite, reminder status, and root/modal changes;
- keyboard navigation, visible focus, logical default focus, Escape/Cancel, and
  focus transfer to the first invalid checkout/reminder field on iPad/macOS;
- minimum platform target sizes, non-color-only status, and sufficient
  contrast;
- Reduce Motion behavior for nonessential custom transitions; and
- accessibility identifiers that describe stable semantic roles rather than
  visible English copy.

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

Schema 5 encodes `[StoreRoute]` and `[ServicesRoute]` directly. Both route
types implement explicit stable Codable tags; the snapshot does not persist a
`NavigationPath.CodableRepresentation`, compiler-generated type name, or
process-local `sessionRevision`.

Sheets, alerts, checkout, Authentication, and protected actions are not
persisted.

Schemas 2, 3, and 4 migrate to:

- selected section Store;
- empty Store path;
- empty Services path; and
- the previous transition checkpoint when schema 4 provides one.

Dedicated legacy V2/V3/V4 DTOs decode their old section values as legacy raw
strings and ignore their obsolete path payloads. They do not decode through
the new Store/Services `AppSection`. Schema 4 extracts only its transition
checkpoint. This permits deleting old route types after replacement without
making valid legacy snapshots appear corrupt.

The old example routes have no honest product equivalent, so they are not
invented or partially translated. In schema 5, an invalid Store or Services
route payload resets only that section's path and preserves the valid other
section. Corrupt outer data and unsupported-old data reset both paths to Store.
Future-schema bytes remain preserved, runtime navigation uses a safe empty
Store state, and snapshot writes stop, matching the current downgrade-safety
rule. After decoding/migration, root transition is reconciled first and the
first non-restoring session presentation removes guest-ineligible routes before
the corrected snapshot is persisted.

## Fixed Demo Limits and Defaults

The implementation does not invent environment-dependent limits:

| Concern | Fixed product/demo rule |
| --- | --- |
| Local session bootstrap | A 3-second injected-clock deadline; timeout publishes secureStorageReadFailed and ignores the stale completion |
| DummyJSON request | 15-second request/resource timeout, no automatic retry except the single documented auth retry |
| Login access token request | `expiresInMins = 30`; refresh scheduling uses a 60-second leeway when `exp` exists |
| Product search | 300-millisecond debounce, 100-character input limit |
| Remote page size | Choices 10, 20, 30, 50; default 20 |
| Local Database page size | Any integer 1 through 50; default 20; repository requests one lookahead record |
| Services Data/hex input | At most 4,096 decoded bytes and at most 8,192 rendered hex characters |
| Diagnostics and notification event history | Newest 100 safe events per app process, each with explicit Clear |
| Deferred notification UI intents | FIFO newest 32 per app process; overflow drops the oldest and records a safe diagnostic |
| Product image acquisition | HTTPS origins `dummyjson.com` and `cdn.dummyjson.com`, 15 seconds, 5 MiB encoded data, maximum 4,096 by 4,096 decoded pixels |
| Product reminder interval | One-shot 1 through 604,800 seconds; repeating 60 through 604,800 seconds |
| Product calendar reminder | Strictly future and no more than one year from the injected current date |
| Checkout text field | 100 Unicode scalar maximum per fictional delivery field |
| Named notification sound | Bundled compatible file shorter than 30 seconds |

## Failure and Cancellation Semantics

### General

- Cancellation exits silently and never becomes a user-visible error.
- Async ViewModels ignore stale responses from superseded searches/pages.
- Every destructive action is explicit; isolated labs touch only demo-owned
  data, while unavoidable app-wide notification effects are labelled and
  confirmed.
- No service silently falls back from live persistence to in-memory storage.
- All externally sourced image and attachment data is bounded and cancellable.
- App-wide or destructive Services actions display their exact scope before
  execution.

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
- 408/429/5xx and non-authoritative decode failures never become credential
  rejection.
- Stale session generations never write Keychain or publish state.
- Auth transport stores and sends no cookies.

### Local database

- Initialization, validation, read, and write errors remain distinct.
- Failed favorites/cart writes do not optimistically claim success.
- CRUD/search mutation resets Services pagination before reloading.
- Checkout success dismisses only after the cart delete succeeds.
- Cross-window cart/favorite mutations are serialized by semantic repository
  actors, and checkout uses an expected revision.

### Notifications

- Denied permission leaves Store usable and explains that system settings
  control delivery.
- Attachment acquisition failure falls back to text-only at the product use
  case boundary.
- A schedule failure does not display a false “reminder set” state.
- Pending/delivered lists tolerate owned unreadable snapshots.
- Store category composition cannot be replaced by a lab-only catalog.
- Notification responses have one typed semantic dispatcher and bounded event
  history.

### AppState

- A rejected AppState persistence mutation does not transition roots.
- Future AppState remains read-only and is never overwritten.
- Maintenance and onboarding controls surface rejection rather than claiming
  completion.
- A failed schema-1-to-2 migration write preserves decoded policy visibly,
  leaves the old bytes intact, and marks AppState read-only.

## Preview, UI-test, and Test Isolation

Preview and automated-test graphs use:

- a fail-closed scripted network transport whose unplanned request fails the
  test instead of reaching the internet;
- a typed `UITestScenario` manifest that seeds AppState, session state,
  database records, preferences, notification state, and ordered remote
  results;
- injected clocks/schedulers and an injected image loader with bundled fixture
  images;
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

Preview graphs never start an uncontrolled refresh task. Product images and
reminder attachment acquisition use the injected loader in every environment;
`AsyncImage`, `URLSession.shared`, and direct file/network access are not hidden
escape paths around the scenario graph.

## Test Strategy

### Unit and contract tests

Tests cover:

- AppState schema 1 to 2 migration, repair, future-schema preservation, and
  persistence rejection;
- exact root policy priority, one app-owned bootstrap across multiple scenes,
  Restoring ending after local Keychain resolution, and root-history
  preservation;
- missing, valid, expired, offline, refreshed, rejected, and corrupt session
  restoration, plus recoverable Keychain read failure;
- every row of the session durable-boundary matrix, including authoritative
  error classification, single-flight refresh, one-retry limits, failed login
  persistence, failed refresh replacement, failed cleanup, late completion,
  and login/refresh versus Sign Out races;
- cookie isolation, credential-free redirects, and auth-origin enforcement;
- sentinel secrets absent from every diagnostic representation;
- protected action success, cancellation, one-time consumption, deep links,
  per-scene session revision reconciliation, protected-route pruning, public
  route preservation, and multi-window isolation;
- Store and Services route encoding/restoration;
- raw frozen navigation snapshot 2/3/4 fixtures migrating to 5 without old
  route types, plus partial schema-5 path recovery;
- rejected deep links causing zero mutation and latest valid deferred-link
  semantics;
- product search/category/detail/pagination mapping and stale-request
  cancellation;
- favorites user scoping and atomic revisioned cross-window cart semantics;
- all UserDefaults codecs and Keychain Data/String/Codable conveniences;
- local-database CRUD, normalized search, batch behavior, and cursor
  pagination, including strict new-ID validation, stable legacy-ID ordering
  across reopen, insertion/deletion around the cursor, and a large
  sparse-search guard;
- a frozen-V1 on-disk SwiftData store reopening through V2 with byte-preserved
  ExampleRecords and working new entities;
- the existing Local Notification contract permutations, plus new Store/lab
  category composition, action dispatch, bounded replay history, impact-scoped
  removals, asset validation, and reminder orchestration;
- reminder text-only fallback; and
- ViewModel loading, content, empty, error, retry, and cancellation states.

### UI tests

UI coverage is representative rather than a Cartesian product of operations
and platforms. The isolated UI-test graph covers these journeys:

- first launch -> Onboarding -> Store;
- catalog -> product -> reviews -> related product;
- filters sheet;
- Guest favorite -> Authentication -> automatic favorite completion;
- Authentication cancel and invalid credentials;
- Favorites/Account protection, public Profile settings, and Sign Out without
  leaving Main;
- cart -> checkout -> success;
- product and protected deep links;
- Maintenance preserve/return behavior;
- Store/Services path independence;
- AppState playground commands;
- one Basic Try It/actual/reset journey for UserDefaults, Keychain, Local
  Database pagination, Remote stub, and Local Notification in-memory labs; and
- a compact shell/navigation/accessibility smoke suite on iPhone, regular iPad,
  and macOS.

Low-level codec, trigger, attachment, metadata, category, and error
permutations remain unit/contract tests. Platform-neutral repository and
ViewModel tests run once. Live Notification Center behavior remains manual.
The implementation plan records exact test destinations and commands so
“complete platform verification” does not mean duplicating every scenario on
every platform.

### Manual live verification

Manual verification covers the two environment-owned behaviors that automated
tests deliberately isolate:

- real DummyJSON product/login/profile/refresh requests; and
- real system notification permission, foreground delivery, actions,
  attachments, pending/delivered lists, and deep-link routing.

Manual notification verification confirms that the first two actions appear
on limited-space banners and additional lab actions require an expanded
surface. It also verifies the named sound resource is compatible and shorter
than 30 seconds.

## Delivery Phases

Implementation is divided into eight sequential plans. A later phase consumes
only committed, tested interfaces from earlier phases:

1. **Security and deterministic harness** — cookie-free transport, allowlisted
   diagnostics, injected clocks/image loading, scripted scenarios.
2. **Persistence foundations** — AppState schema 2, frozen SwiftData V1 to V2
   migration, preferences, atomic favorite/cart repositories, cursor ordering.
3. **Session subsystem** — app-owned bootstrap, login/me/refresh, complete
   failure matrix, single-flight and generation rules.
4. **Guest Store and adaptive shell** — Store/Services shell, typed routes and
   snapshot 5, catalog/search/detail/reviews/cart, deterministic images.
5. **Protected navigation** — Authentication modal, Favorites/Account,
   protected deep links, session revision, multi-window Sign Out behavior.
6. **Product reminders** — permission, three triggers, bounded image fallback,
   category composition, Open/Favorite/Remind Later dispatch.
7. **Services learning labs** — Basic/Advanced screens, scoped storage labs,
   Remote diagnostics, full notification lab, bounded replay history.
8. **Accessibility and replacement cleanup** — adaptive polish, localization,
   accessibility acceptance, documentation, removal of superseded Features.

Each phase uses test-first tasks, ends with focused macOS and iOS build/test
commands, and is committed before the next phase begins. Old Features are
removed only in phase 8 after the replacement paths pass.

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
5. Sign Out is explicit, reaches Guest only after successful token deletion,
   and does not leave Main.
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
    attachment fallback, three Store actions, typed dispatch, deep links,
    cancellation, and status; text input remains demonstrated in Services.
13. Navigation is scene-local, session is app-global, and multi-window behavior
    is tested.
14. Old example routes and documentation are removed without discarding
    reusable infrastructure.
15. Complete macOS, iPhone, and iPad verification passes with warnings treated
    as errors and no failed or skipped required tests.
16. Remote validation never blocks the root after the bounded local Keychain
    bootstrap.
17. No cookie, credential store, cache, diagnostic recorder, image loader, or
    redirect creates a second authentication persistence or secret-leak path.
18. Every window reconciles app-global session revisions exactly once while
    navigation remains scene-local.
19. Schema 5 persists typed routes and migrates frozen legacy snapshots without
    retaining superseded route types.
20. A frozen SwiftData V1 disk store migrates to V2 without losing an
    ExampleRecord and with active schema/registry identity agreement.
21. Services distinguishes isolated labs from app-wide controls, explains
    expected versus actual results, and confirms unavoidable global effects.
22. Required flows pass Dynamic Type, VoiceOver/keyboard focus, localized
    formatting, long-string, and RTL acceptance checks.
