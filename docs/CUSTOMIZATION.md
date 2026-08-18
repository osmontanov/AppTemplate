# Customization

Make these changes before adding product behavior. Keep identifiers stable
after release because changing them can break installs, deep links, stored
state, signing, and external integrations.

## 1. Bundle identifier and URL scheme

Edit `Config/Template.xcconfig`:

```text
APP_BUNDLE_IDENTIFIER = com.yourcompany.YourApp
APP_URL_SCHEME = yourapp
```

`APP_BUNDLE_IDENTIFIER` feeds the app target and the `.tests` and `.uitests`
bundle identifiers. `APP_URL_SCHEME` feeds the `CFBundleURLSchemes` entry in
`AppTemplate/Resources/Info.plist`. Use a lowercase, URL-safe scheme, then
update deep-link examples, integrations, and tests that use the old scheme.

## 2. Display name and source names

To set the user-visible name independently of the target name, add this entry
inside the root dictionary in `AppTemplate/Resources/Info.plist`:

```xml
<key>CFBundleDisplayName</key>
<string>Your App</string>
```

`AppInfoService` reads `CFBundleDisplayName`, then falls back to
`CFBundleName`. Localize the display name through the appropriate InfoPlist
strings localization if the product needs different names by locale.

Renaming the Xcode project, targets, shared scheme, product module, test
modules, `AppTemplateApp`, directories, or the `AppTemplate` persistence-key
prefix is optional and separate from the display name. If you rename any of
them, use Xcode's rename operation, update matching paths/references and local
build/test commands, and run all destinations before deleting the old names.

## 3. Icons, accent color, and strings

- Replace every required image slot in
  `AppTemplate/Resources/Assets.xcassets/AppIcon.appiconset`; keep its
  `Contents.json` consistent with the supplied files.
- Set the product accent in
  `AppTemplate/Resources/Assets.xcassets/AccentColor.colorset`.
- Replace template copy and add supported locales in
  `AppTemplate/Resources/AppText.xcstrings`. Every visible string resolves
  through `AppText` into that table; `Localizable.xcstrings` holds only the
  launch-failure message and needs no attention. Xcode does not extract strings
  into these catalogs (see `SWIFT_EMIT_LOC_STRINGS` in `Config/Template.xcconfig`),
  so add each new key by hand — `AppTextLocalizationTests` fails when a producer
  uses a key the catalog lacks.
- Verify icons, tinting, high-contrast appearances, and localized layouts on
  both iOS/iPadOS and macOS.

## 4. App information service

`IAppInfoService` currently exposes `displayName` and `version`.
`AppInfoService` reads them from `Bundle.main`, and
`AppDependencies.live()` exposes it to the Services application-information
lab. Keep this implementation if bundle metadata is sufficient. To replace it:

1. Update `IAppInfoService` with only the values the Services lab needs.
2. Implement those requirements in a `Sendable` concrete type.
3. Change the `appInfoService:` construction in `AppDependencies.live()`.
4. Supply explicit preview, test, and UI-test values; do not add a global
   resolver or production fallback fixture.

## 5. Services and features

### Local Notification Service

Adopt the notification boundary deliberately before a product release:

1. Change `LocalNotificationNamespace.live` from
   `AppTemplate.LocalNotification` to one stable product namespace before the
   first shipped notification. Keep the namespace and every logical request,
   category, action, and attachment ID stable. A post-release namespace change
   requires an explicit migration/removal strategy for requests and categories
   created under the old namespace; the service does not discover or migrate
   them automatically.
2. Define one stable category catalog in product code and register it during
   startup. Category IDs are unique, action IDs are unique within a category,
   and each category has at most 10 ordered actions. Replacing the catalog
   replaces only this service's namespaced categories and preserves unrelated
   app-global categories. A scheduled request may reference only the last
   successfully registered catalog.
3. Keep permission timing user-driven. `settings()` only reads state and never
   prompts. Call `requestAuthorization(_:)` only from an `explicit user action`,
   such as an Enable Notifications button, and refresh `settings()` after the
   returned system result. Do not add a launch, composition, scene, or category
   registration prompt.
4. Use only routes accepted by the app's `DeepLinkParser`. A default open uses
   the request route. A button or text-input action uses only its own route; a
   missing action route intentionally performs no navigation and never falls
   back to the request route.
5. Package a named sound where Notification Center can load it and pass only
   its leaf resource name, such as `Reminder.aiff`. Do not pass a path or URL.
   Service validation does not prove that the resource is packaged or that
   user settings will allow it to play.
6. Supply attachments as readable local regular files. The service supports
   image, audio, and video types, rejects network URLs and symbolic links, and
   stages a disposable copy before system submission. The caller's source file
   must remain readable until `schedule(_:)` returns and is left unchanged; on
   success it can be moved or deleted because Notification Center accepted the
   staged attachment. Snapshot attachment URLs are system-owned and require
   security-scoped access while read; they are not the original source URL.
7. Treat successful scheduling as system acceptance, not a delivery guarantee
   or receipt. User settings, Focus, platform policy, and process state still
   govern presentation. Scheduling the same logical request ID replaces its
   pending request without pre-removal; it does not remove an already delivered
   notification with that ID.
8. Give each Feature only `any ILocalNotificationService`. The Feature owns its
   `events()` consumer task and all business behavior caused by foreground,
   open, dismiss, button, or text-input events. Do not inject the event hub,
   navigation coordinator, delegate bridge, or system center into a Feature.
9. Keep preview, UI-test, and unit-test graphs isolated. The existing factories
   create a fresh in-memory service and event graph each time; inject that
   service explicitly when a preview or test needs configured settings,
   categories, pending requests, delivered requests, or events. Do not add a
   global in-memory singleton.
10. Design a separate subsystem if the product needs APNs, remote payloads,
    network attachment downloads, durable action queues, location triggers,
    time-sensitive or critical interruption levels, notification extensions,
    analytics, or delivery receipts. None is included here.

The following samples use only the neutral service contract and models. This
permission function belongs behind a visible control's action handler:

```swift
func enableNotifications(
    using service: any ILocalNotificationService
) async throws -> Bool {
    try await service.requestAuthorization([.alert, .sound, .badge])
}
```

Register stable actions before scheduling a request that references them:

```swift
func registerReminderCatalog(
    using service: any ILocalNotificationService
) async throws {
    guard let projectURL = URL(
        string: "apptemplate://projects/project/example"
    ) else { return }

    let category = LocalNotificationCategory(
        id: try LocalNotificationCategoryID("reminder"),
        actions: [
            .button(
                LocalNotificationButtonAction(
                    id: try LocalNotificationActionID("open-project"),
                    title: "Open",
                    options: [.foreground],
                    deepLink: projectURL
                )
            ),
            .textInput(
                LocalNotificationTextInputAction(
                    id: try LocalNotificationActionID("reply"),
                    title: "Reply",
                    deepLink: nil,
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Message"
                )
            )
        ],
        reportsDismissal: true
    )
    try await service.setCategories([category])
}
```

Scheduling performs one system add only after validation and local attachment
staging succeed:

```swift
func scheduleReminder(
    imageURL: URL,
    using service: any ILocalNotificationService
) async throws {
    guard let projectURL = URL(
        string: "apptemplate://projects/project/example"
    ) else { return }

    let request = LocalNotificationRequest(
        id: try LocalNotificationID("example-reminder"),
        content: LocalNotificationContent(
            title: "Project reminder",
            body: "Review the example project.",
            sound: .named(resourceName: "Reminder.aiff"),
            categoryID: try LocalNotificationCategoryID("reminder"),
            attachments: [
                LocalNotificationAttachment(
                    id: try LocalNotificationAttachmentID("preview"),
                    fileURL: imageURL
                )
            ],
            deepLink: projectURL,
            foregroundPresentation: [.banner, .sound]
        ),
        trigger: .timeInterval(seconds: 300, repeats: false)
    )
    try await service.schedule(request)
}
```

### Local SwiftData reference store

Before shipping product data:

The engine is typed and explicitly registered: it is not a schemaless or
arbitrary-`Codable` store. Add a product model in this order:

1. Create a detached immutable `Sendable` record and typed `Query`.
2. Create a schema entity with a schema-enforced unique business ID.
3. Add its adapter and record conformance.
4. Add a new immutable `VersionedSchema` version—never edit a shipped schema.
5. Add a migration stage and disk transition fixture.
6. Add the production registry entry.
7. Add schema/registry bijection and uniqueness tests.
8. Add a semantic Feature repository that maps Domain values to local records.

The production registry's entity set and cardinality must equal the active
schema. Keep SwiftData entities, contexts, containers, predicates, and
identifiers behind the persistence implementation. ViewModels receive a
feature protocol, never SwiftData or `AppDependencies`; do not use `payload`
as an untyped domain envelope.

Continue to apply these product decisions before shipping:

1. Keep the live URL stable at
   `Application Support/<bundle identifier>/LocalDatabase.store`, or design and
   test an explicit move before changing it.
2. Retain every shipped `VersionedSchema`. Add a real migration stage only when
   a transition exists, and verify that transition with a disk fixture created
   from the earlier schema.
3. Decide retention, user-visible deletion, backup/restore, import/export, and
   recovery from initialization or migration failure. Never silently erase or
   replace an unreadable store with memory.
4. Decide separately whether CloudKit, App Groups, cross-process access, or
   application-level encryption is required. The template configures
   `cloudKitDatabase: .none` and provides none of those guarantees.
5. Preserve operation-specific persistence-boundary tests: exactly one save for
   state-changing upsert/delete-one, exactly one type-level call and zero saves
   for successful nonempty delete-all, documented no-op tests, deterministic
   pre-call failure and cancellation tests, the disk-backed immediate-durability
   regression, and reopen tests for the final feature contract.
6. Keep `AppStateStore` in UserDefaults unless an independently designed
   asynchronous startup and migration flow replaces it.

### Typed UserDefaults settings

`AppStateStore` remains synchronous UserDefaults-owned launch state through
`UserDefaultsAppStateStorage`. Keep that startup path synchronous unless an
independently designed asynchronous launch, migration, and root-selection flow
replaces it.

Declare each product setting as a fixed typed key in its semantic storage
adapter or repository, for example:

```swift
private static let appearanceKey: UserDefaultsKey<String> =
    .string("Appearance")
```

Choose one stable service namespace and one stable logical name for every key;
after release, changing either changes the physical key and requires an
explicitly designed migration. Use a native factory (`.bool`, `.int`,
`.float`, `.double`, `.string`, `.data`, or `.date`) when the property-list
representation is the intended compatibility contract. Use `.codable` only
when JSON stored as raw `Data` is the intended long-term representation, and
do not switch factories for a shipped logical key.

Keys are compile-time constants, never values derived from user input, account
IDs, routes, remote configuration, or other arbitrary data. UserDefaults is
for nonsensitive app-private settings only; passwords, credentials, tokens,
private keys, and other secrets use the app-private Keychain boundary below.

### App-private Keychain secrets

The Keychain service namespace and every account name are stable, opaque,
fixed metadata. Do not derive either from a secret, user ID, email, server
response, localized text, or bundle metadata. The template's live namespace is
`AppTemplate`; change it before the first product release, then treat a change
to either service or account spelling as an explicit storage migration.

Choose one representation for each fixed account:

- Raw `Data` is the canonical boundary for opaque bytes.
- `String` keys use exact UTF-8 bytes for their entire shipped lifetime.
- `KeychainCodableKey<Value>` stores direct JSON for one `Codable & Sendable`
  value type and one positive, monotonically increasing schema version; the
  version is part of the physical account name.

Do not switch a shipped account's representation as a fallback. For an
incompatible Codable change, declare the new schema version, read the new key
first, then read and map the old value only when needed. Write and await the
new value before removing the old one. A failed new write leaves the old item
intact; a failed cleanup can leave both, with the new key remaining
authoritative.

Wrap this low-level service in a semantic repository before giving a feature
access to credentials or sessions. It is not a feature API, token lifecycle,
or general data store. Shared groups, Keychain synchronization, biometrics or
other user-presence policy, access while locked in the background, and changes
to team, App ID prefix, bundle identity, or platform application identity each
change the authorization or storage model and require a separate design,
migration strategy, tests, and release validation.

### Remote service

The remote service uses a URLSession-backed, Moya-inspired target/provider
flow for the retained DummyJSON Store and Services-lab operations. Before
pointing an adopted product at another API:

1. Replace `DummyJSONTarget` and its DTOs with domain-specific endpoints and
   models while keeping `IRemoteService` semantic.
2. Supply each real environment base URL at the composition root; do not hide
   configuration in a global singleton.
3. At the production composition root, create one long-lived `URLSession` from
   an explicit configuration and inject it into `URLSessionTransport`. Configure
   timeout, cache, cookie, connectivity, redirect, and trust policies there as
   required; do not create a session per request. Redirect handling follows the
   injected session's policy, and target status validation applies to the
   terminal HTTP response rather than intermediate redirect responses.
4. Add actor-safe `RequestAdapter`s for credentials and explicit,
   privacy-reviewed `NetworkEventMonitor`s for diagnostics. Monitor callbacks
   must return quickly and queue expensive telemetry internally. Do not log
   secrets, authorization headers, or bodies by default.
5. Define each target's status validation and sample response, then test it
   with an in-memory transport or provider stubbing rather than public network
   access.
6. Expose only semantic methods through feature-scoped service protocols and
   dependency structs. Do not inject `NetworkProvider` or `AppDependencies`
   into a ViewModel.

For a new feature, create its flow and screens under
`AppTemplate/Features/<Feature>`. A screen owns its outgoing routes and
destination mappings. Add a main-shell section only when the feature is a
top-level destination; in that case update `AppSection`,
`AppSectionContentView`, snapshot persistence/restoration, deep-link parsing,
and their tests together. Files under the synchronized source groups are
included by Xcode automatically.

When removing a sample feature, remove its routes, shell/deep-link cases,
dependency construction, snapshot fields, previews, localized strings, and
tests as one change. Preserve migration handling for any navigation schema
already shipped to users.

## 6. Signing, capabilities, and permissions

In Xcode, select the `AppTemplate` project and then each app/test target:

1. In **Signing & Capabilities**, select the adopter's team and keep automatic
   signing or configure the intended provisioning profiles explicitly.
2. Confirm the resolved application identifier matches
   `APP_BUNDLE_IDENTIFIER`; register that identifier with Apple when needed.
3. Add only capabilities, entitlements, and usage-description keys required by
   implemented product behavior. Validate the macOS sandbox permissions as
   well as iOS/iPadOS entitlements.
4. Configure Release signing and archive the Release configuration on a clean
   verification machine.

> **Review `AppTemplate/Resources/PrivacyInfo.xcprivacy` before submitting.** It
> ships filled in for the code that is here — no tracking, no collected data, and
> required reasons for UserDefaults (CA92.1) and the file timestamps the
> notification attachment stager and Nuke's image disk cache read (C617.1). Required-reason APIs and data
> declarations must describe *your* code and dependencies, so re-derive every
> entry once your product and its SDKs replace the example.
