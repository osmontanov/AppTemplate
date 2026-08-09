# Release checklist

Complete this checklist for the adopted product, not for the untouched sample.

> **BLOCKER — DO NOT DISTRIBUTE THROUGH THE APP STORE:** App Store distribution
> remains blocked until the adopter adds and validates the correct
> `PrivacyInfo.xcprivacy` for the final app and every included SDK. This task
> intentionally does not add a privacy manifest because the declarations must
> match the adopter's actual APIs, data collection, tracking, and dependencies.

## Identity and signing

- [ ] Replace `APP_BUNDLE_IDENTIFIER` and `APP_URL_SCHEME`; verify app, unit
  test, and UI-test identifiers resolve correctly.
- [ ] Set the display name, marketing version, and build number.
- [ ] Select the distribution team, certificates, provisioning profiles, and
  Release signing settings for every platform and target.
- [ ] Validate universal links, custom URL schemes, associated domains, and
  other registered identifiers used by the product.

## Product assets and localization

- [ ] Replace and visually inspect every required iOS, iPadOS, and macOS app
  icon, including dark/tinted variants where applicable.
- [ ] Replace and verify the accent color in light, dark, increased-contrast,
  and tinted appearances.
- [ ] Complete the string catalog, display-name localization, screenshots, and
  accessibility labels for every supported locale.
- [ ] Test layout, truncation, pluralization, right-to-left behavior, VoiceOver,
  keyboard navigation, and Dynamic Type where applicable.

## Behavior, tests, and migration

- [ ] Replace all static examples and empty local/remote service scaffolds used
  by the released product with reviewed production behavior.
- [ ] Run the complete unit and UI test suites with warnings treated as errors.
- [ ] Confirm CI passes on macOS, iPhone 17 / iOS 26.5, and iPad (A16) /
  iOS 26.5.
- [ ] Review the schema-1 app-state model, storage key, recovery behavior, and
  migration policy against every previously shipped version.
- [ ] Review scene navigation restoration and migrations for every previously
  shipped navigation snapshot schema.

## Privacy, permissions, and security

- [ ] Add and validate the product-specific `PrivacyInfo.xcprivacy`, including
  required-reason API declarations and the manifests of included SDKs.
- [ ] Audit data collection, tracking, retention, deletion, encryption,
  credentials, logs, and network transport against the product privacy policy.
- [ ] Add only necessary permission usage descriptions, capabilities, and
  entitlements; exercise both grant and denial paths.
- [ ] Verify macOS sandbox and hardened-runtime settings and iOS/iPadOS
  entitlements in the signed archive.
- [ ] Inspect signed Debug and Release macOS app entitlements: require
  `com.apple.security.app-sandbox = true` and
  `com.apple.security.network.client = true`, and require
  `com.apple.security.network.server` to be absent.
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
