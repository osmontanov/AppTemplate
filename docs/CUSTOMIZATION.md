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
  `AppTemplate/Resources/Localizable.xcstrings`.
- Verify icons, tinting, high-contrast appearances, and localized layouts on
  both iOS/iPadOS and macOS.

## 4. App information service

`IAppInfoService` currently exposes `displayName` and `version`.
`AppInfoService` reads them from `Bundle.main`, and
`AppDependencies.live()` injects it through
`SettingsDependencies(appInfo:)`. Keep this implementation if bundle metadata
is sufficient. To replace it:

1. Update `IAppInfoService` with only the values Settings actually needs.
2. Implement those requirements in a `Sendable` concrete type.
3. Change the `settings:` construction in `AppDependencies.live()`.
4. Supply explicit preview, test, and UI-test values; do not add a global
   resolver or production fallback fixture.

## 5. Services and features

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
private keys, and other secrets require a separately designed
`KeychainService` and product data policy.

### Remote service

The remote service now demonstrates a URLSession-backed, Moya-inspired
target/provider flow with a reserved `https://example.invalid` base URL; it is
not a configured production API. Before enabling remote product behavior:

1. Replace `ExampleTarget`, `ExampleRequest`, `ExampleResponse`, and
   `fetchExample(_:)` with domain-specific operations and models.
2. Supply the real environment base URL at the composition root; do not leave
   the reserved placeholder or hide configuration in a global singleton.
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

> **App Store distribution is blocked until the adopter adds and validates the
> correct `PrivacyInfo.xcprivacy` for the finished app and every included SDK.**
> This template intentionally does not add one: required-reason APIs and data
> declarations must describe the adopter's actual code and dependencies.
