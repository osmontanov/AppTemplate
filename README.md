# AppTemplate

AppTemplate is a SwiftUI starting point for iOS 26, iPadOS 26, and macOS 26.
It provides typed, scene-local navigation; persisted demo app policy; explicit
dependency injection; deep links; previews; unit tests; UI tests; and documented
local verification for macOS, iPhone, and iPad. Authentication, local storage,
remote access, and feature data are intentionally non-production examples.

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

The template does not choose a real identity provider, database, network
client, repository layer, or feature persistence strategy. Replace the example
services and screens deliberately; do not treat them as production behavior.

## Documentation

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Customization](docs/CUSTOMIZATION.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
