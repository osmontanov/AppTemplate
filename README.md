# AppTemplate

AppTemplate is a SwiftUI application template for iOS, iPadOS, and macOS. It
provides typed scene-local navigation, persisted demo app policy, explicit
dependency injection, deep links, previews, unit and UI tests, a hardened
network layer, and a local-only SwiftData reference store for `ExampleRecord`.
Platform verification is performed locally.

## Start here

1. Open `AppTemplate.xcodeproj` in Xcode 26.6 or later.
2. Choose the shared `AppTemplate` scheme and run on macOS, iPhone, or iPad.
3. Follow the [customization guide](docs/CUSTOMIZATION.md) before building your
   product.
4. Read the [architecture guide](docs/ARCHITECTURE.md) before changing app
   policy, navigation, persistence, or dependency ownership.
5. Use the [release checklist](docs/RELEASE_CHECKLIST.md) before distribution.

> **Distribution blocker:** App Store distribution remains blocked until the
> adopter adds and validates the correct `PrivacyInfo.xcprivacy` for the final
> app and all included SDKs. The template intentionally does not include a
> privacy manifest because the required declarations depend on the adopter's
> product.

## Scope

The implemented examples focus on reusable application structure:

- one app-scoped `AppStateStore`, `AppFlowCoordinator`, and `AppFlowRouter`;
- one independent `AppRouter` and navigation snapshot per window;
- typed routes, deep-link parsing, root-flow policy, modal flows, and
  platform-adaptive shells;
- explicit live, preview, test, and UI-test dependency construction;
- static Home, Browse, Projects, and Settings content that is safe to replace.

The template includes an intentionally small SwiftData reference store for the
sample `ExampleRecord` value. It demonstrates a Sendable service facade, an
internal ModelActor, explicit schema versioning, lazy disk bootstrap, isolated
in-memory preview/UI-test composition, bounded reads, operation-specific
persistence boundaries, and failure-safe operation contexts. It does not
choose product entities, a feature-specific repository contract, retention
policy, backup policy, application-level encryption, CloudKit synchronization,
App Group sharing, or cross-process access. Replace the sample boundary
deliberately when adding a real feature; do not encode unrelated domain data
into `payload` merely to reuse it.

`AppStateStore` remains a separate UserDefaults-backed launch-policy store. It
is not migrated to SwiftData by this reference implementation.

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Customization](docs/CUSTOMIZATION.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
