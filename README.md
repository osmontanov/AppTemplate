# AppTemplate

AppTemplate is a SwiftUI application template for iOS, iPadOS, and macOS. It
provides typed scene-local navigation, persisted demo app policy, explicit
dependency injection, deep links, previews, unit and UI tests, a hardened
network layer, and a local-only typed SwiftData reference engine.
Platform verification is performed locally.

The template also includes a typed, local-only Local Notification service.
Permission is requested only when product code calls it from an explicit user
action. It supports immediate, interval, and calendar requests; local
image/audio/video attachments; button and text-input actions; foreground
events; and per-scene deep-link navigation. Preview and UI-test graphs use
fresh in-memory instances. There is no APNs registration or remote-notification
subsystem. See [Architecture](docs/ARCHITECTURE.md),
[Customization](docs/CUSTOMIZATION.md), and the
[Release checklist](docs/RELEASE_CHECKLIST.md) before adopting it.

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

The template includes a typed, explicitly registered SwiftData reference
engine. `ExampleRecord` is its first detached local-persistence model, not a
hard-coded service API. Generic does not mean schemaless or arbitrary Codable storage.
It is one compile-time engine for models explicitly added to a schema/registry,
not runtime model discovery. The engine demonstrates a
Sendable service facade, an internal ModelActor, explicit schema versioning,
lazy disk bootstrap, isolated in-memory preview/UI-test composition, bounded
reads, operation-specific persistence boundaries, and failure-safe operation
contexts.

Feature and ViewModel code should depend on a semantic repository over domain
values rather than `ILocalDatabaseService`. The engine does not choose product
entities, a feature repository contract, retention policy, backup policy,
application-level encryption, CloudKit synchronization, App Group sharing, or
cross-process access. Add each product model deliberately to the schema and
registry; do not encode unrelated domain data into `payload` merely to reuse
`ExampleRecord`.

`AppStateStore` remains separate from SwiftData and now uses a synchronous,
typed app-private UserDefaults boundary for its launch-policy record. This
boundary is for nonsensitive settings only. Small secrets belong in the
implemented app-private Data Protection Keychain boundary; it stores no sample
credential. Features should depend on semantic repositories over domain values
rather than on the low-level `KeychainService`.

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Customization](docs/CUSTOMIZATION.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
