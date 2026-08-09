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

The local database service remains an empty example. The remote service now
demonstrates a URLSession-backed, Moya-inspired target/provider flow with a
reserved `https://example.invalid` base URL; it is not a configured production
API. Before enabling remote product behavior:

1. Replace `ExampleTarget`, `ExampleRequest`, `ExampleResponse`, and
   `fetchExample(_:)` with domain-specific operations and models.
2. Supply the real environment base URL at the composition root; do not leave
   the reserved placeholder or hide configuration in a global singleton.
3. Add actor-safe `RequestAdapter`s for credentials and explicit,
   privacy-reviewed `NetworkEventMonitor`s for diagnostics. Do not log secrets,
   authorization headers, or bodies by default.
4. Define each target's status validation and sample response, then test it
   with an in-memory transport or provider stubbing rather than public network
   access.
5. Expose only semantic methods through feature-scoped service protocols and
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
