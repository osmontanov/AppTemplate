# Release checklist

Complete this checklist for the adopted product, not for the untouched sample.

> **Re-derive the privacy manifest for your product.**
> `AppTemplate/Resources/PrivacyInfo.xcprivacy` ships filled in for the code in
> this repository: no tracking, no collected data, and required reasons for
> UserDefaults (CA92.1) and the file timestamps the notification attachment
> stager and Nuke's image disk cache read (C617.1). Those declarations must match *your* APIs, data
> collection, and the manifests of every SDK you add, so review and update the
> file before you submit.

## Identity and signing

- [ ] Replace `APP_BUNDLE_IDENTIFIER` and `APP_URL_SCHEME`; verify app, unit
  test, and UI-test identifiers resolve correctly.
- [ ] Set the display name, marketing version, and build number.
- [ ] Select the distribution team, certificates, provisioning profiles, and
  Release signing settings for every platform and target.
- [ ] Validate universal links, custom URL schemes, associated domains, and
  other registered identifiers used by the product.

## Mandatory Keychain adopter gate

> **RELEASE BLOCKER:** The local ad-hoc macOS Release build is compile/link
> evidence only; unsigned iOS builds, simulator runs, unit tests, and
> command-line probes are too. They cannot show that the Data Protection
> Keychain works at runtime and cannot clear this signed-and-provisioned gate.

- [ ] Build and run the final team and final bundle identity with signing and
  provisioning in a normal user context, on supported physical iPhone/iPad
  hardware and as the signed macOS app.
- [ ] Inspect final app and archive entitlements. On iOS/iPadOS use
  `application-identifier`; on macOS use
  `com.apple.application-identifier`. `keychain-access-groups` must be absent,
  or it must be exactly one entry equal to that platform application
  identifier. Reject any additional, wildcard, legacy, or shared group.
- [ ] Confirm `com.apple.security.application-groups` is absent from source,
  project configuration, and signed artifacts unless a separately designed and
  validated App Group policy is being adopted.
- [ ] With an isolated fixed test service/account, exercise missing, add,
  read, update, Bool-remove, and explicit cleanup on the signed app. Record
  the tested build, profile, identity, platforms, and results.
- [ ] Validate the unlocked and locked-device behavior against the product's
  actual foreground execution model. This policy is not for background access
  while locked without a separate security design.
- [ ] Review logout, retention, device-transfer, backup, account recovery, and
  incident-response behavior with product and security owners before release.

## Product assets and localization

- [ ] Replace and visually inspect every required iOS, iPadOS, and macOS app
  icon, including dark/tinted variants where applicable.
- [ ] Replace and verify the accent color in light, dark, increased-contrast,
  and tinted appearances.
- [ ] Complete `AppText.xcstrings`, display-name localization, screenshots, and
  accessibility labels for every supported locale.
- [ ] Test layout, truncation, pluralization, right-to-left behavior, VoiceOver,
  keyboard navigation, and Dynamic Type where applicable.

## Mandatory Local Notification signed-build gate

> **RELEASE BLOCKER:** Unit tests, UI tests, simulator runs, and unsigned builds
> verify deterministic service and composition behavior only. They cannot prove
> permission UI, real Notification Center delivery or presentation, attachment
> rendering, action callbacks, relaunch behavior, or signed multi-window routing.

- [ ] On signed development builds, trigger the first permission request from
  an explicit user action; record both allow and deny paths, then refresh and
  verify the detailed notification settings after each path.
- [ ] On supported signed iPhone, iPad, and macOS builds, verify immediate,
  nonrepeating/repeating interval, and one-shot/repeating calendar delivery.
- [ ] Verify foreground banner, list, sound, and badge presentation against the
  app's request and the current system settings.
- [ ] Verify same-ID pending replacement, point cancellation, owned-only
  pending/delivered removal, and app-global badge set/clear behavior.
- [ ] Verify local image, audio, and video attachments on signed builds.
  Inspect system presentation and prove every original source file remains
  byte-for-byte intact after scheduling.
- [ ] Verify default open, reported dismiss, custom button, and text-input
  actions. Confirm action text is neither persisted nor logged, and confirm an
  action with no route does not fall back to the request route.
- [ ] Verify valid notification deep links from both cold launch and a warm
  process, including authentication/maintenance deferral and restoration.
- [ ] With no eligible scene, invoke multiple route-bearing actions and verify
  their process-local FIFO drains once, in order, to the next active scene.
- [ ] With two signed macOS windows, alternate key status and verify each route
  reaches only the last key window; also verify resign, close, and reactivation.
- [ ] Record Notification Center/user-settings limitations with the evidence:
  successful scheduling is system acceptance, never a delivery guarantee.

## Behavior, tests, and migration

- [ ] From a clean final candidate, run
  `zsh Scripts/verify-release.zsh`. Retain its unique
  result directory and confirm the required unit and UI manifests report no
  failures or unauthorized skips on macOS, iPhone, and iPad.
- [ ] Confirm the run did **not** end with "Release gate passed WITHOUT macOS UI
  coverage". That line means this machine denies UI automation to the test
  runner, so the macos-scoped UI rows went unverified; grant it and rerun before
  shipping.
- [ ] For the active schema, confirm the production registry entity set and
  cardinality equal the active schema.
- [ ] Verify schema-enforced unique business-ID behavior for every registered
  entity.
- [ ] Keep all prior-schema disk transition fixtures, and run them with direct
  V1 and generic reopen tests that cover inserts, updates, single deletion,
  and bulk deletion in a second container.
- [ ] Before adopting any new Xcode or SwiftData toolchain, rerun the
  disk-backed bulk-delete characterization and revalidate the
  zero-explicit-save persistence contract, even if no behavior change has been
  observed; investigate and amend the storage contract before accepting any
  changed result.
- [ ] Run delete-all SDK characterization and failed-write recovery without
  automatic erase, retry loops, or in-memory fallback.
- [ ] For every schema after V1, retain the prior schema and pass disk-backed
  transition fixtures. V1 has no fake predecessor or migration stage.
- [ ] Confirm retention, deletion, backup/restore, and corrupted-store support
  policy for product data.
- [ ] Confirm local database privacy, retention, backup, sync, and
  cross-process decisions; the template enables no CloudKit sync or App Group
  sharing by default.
- [ ] Inspect the release gate's full macOS unit bundle and macOS/iPhone/iPad
  UI bundles with `verify-xcresult-required-tests.swift`; do not infer success
  from the `xcodebuild` exit code alone.
- [ ] Confirm macOS, iPhone 17 Pro / iOS 26.5, and iPad Pro 13-inch (M5) /
  iOS 26.5 builds complete with warnings treated as errors. Perform
  distribution signing and archive checks separately.
- [ ] Review the schema-1 app-state model, storage key, recovery behavior, and
  migration policy against every previously shipped version.
- [ ] Preserve the exact `AppTemplate.AppState` physical key and raw `Data`
  representation, or ship and test an explicit namespace/logical-key or value
  migration; verify existing AppState bytes still load and save unchanged.
- [ ] Review scene navigation restoration and migrations for every previously
  shipped navigation snapshot schema.

## Privacy, permissions, and security

- [ ] Re-derive `PrivacyInfo.xcprivacy` for the shipped product: required-reason
  API declarations, collected data types, and the manifests of included SDKs.
- [ ] Review `NSPrivacyAccessedAPICategoryUserDefaults` against the shipped app
  and every included SDK. Use `CA92.1` only when the final behavior remains
  app-private standard-defaults access and revalidate the approved reason at
  release time.
- [ ] Audit data collection, tracking, retention, deletion, encryption,
  credentials, logs, and network transport against the product privacy policy.
- [ ] Add only necessary permission usage descriptions, capabilities, and
  entitlements; exercise both grant and denial paths.
- [ ] Confirm Local Notification adoption added no Info.plist prompt text,
  `aps-environment`, remote-notification background mode, Push Notifications,
  critical-alert or location capability/key, entitlement file, or
  time-sensitive/critical/location code path.
- [ ] Verify macOS sandbox and hardened-runtime settings and iOS/iPadOS
  entitlements in the signed archive.
- [ ] Inspect signed Debug and Release macOS app entitlements: require
  `com.apple.security.app-sandbox = true` and
  `com.apple.security.network.client = true`, and require
  `com.apple.security.network.server` to be absent.
- [ ] Require `com.apple.security.application-groups` to be absent from source
  and signed app entitlements unless an independently designed App Group,
  shared-suite, and cross-process policy has been implemented and tested.
- [ ] Inspect the archive's signing identities, embedded profiles, entitlements,
  bundled SDKs, debug symbols, and privacy manifests.

## Store submission

- [ ] Complete product name, subtitle, description, keywords, category, support
  URL, marketing URL, privacy-policy URL, age rating, and review notes.
- [ ] Supply current localized screenshots, previews, contact details, export
  compliance, content rights, pricing, and availability.
- [ ] Upload a clean Release archive, review automated validation results, and
  test the exact candidate through TestFlight before phased or full release.
- [ ] Record the commit, build number, migration decisions, known limitations,
  rollout owner, rollback plan, and post-release monitoring plan.
