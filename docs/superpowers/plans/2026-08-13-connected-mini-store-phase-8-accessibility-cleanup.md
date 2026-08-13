# Connected Mini Store Phase 8: Accessibility and Replacement Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the connected mini-store with localized and adaptive accessibility gates, maintainable UI-test robots, verified release checks, and deletion of superseded examples only after their replacements pass.

**Architecture:** Product copy is centralized in a new `StoreServices.xcstrings` table so the user's dirty `Localizable.xcstrings` is never touched. Semantic accessibility identifiers and compact/regular presentation policies stay in production UI; XCUITest mechanics move into small robots and representative journeys. A fail-fast release script proves replacement gates before a final manifest-driven legacy deletion and documentation update.

**Tech Stack:** Swift 6, SwiftUI, Foundation `FormatStyle`, Xcode String Catalogs, Swift Testing, XCTest/XCUITest, zsh, Xcode 26

**Normative design base:** commit `e372913`, `docs/superpowers/specs/2026-08-13-connected-mini-store-design.md`

## Global Constraints

- Execute after phases 1–7 are committed and all roadmap compatibility gates pass.
- Use RED → observed expected failure → minimal GREEN → focused commit for every task.
- Support macOS, compact iPhone, and regular-width iPad; Main retains exactly Store and Services.
- Every new visible string uses the `StoreServices` String Catalog; price uses localized USD `FormatStyle` and identifies USD as a demo assumption.
- Required flows support accessibility Dynamic Type sizes, VoiceOver semantics/announcements, keyboard focus and Escape/Cancel, non-color status, target size, contrast, and Reduce Motion.
- Stable accessibility identifiers describe semantic roles and never contain visible English copy.
- UI coverage is representative: platform-neutral model tests run once; each platform gets compact shell/navigation/accessibility smoke coverage.
- Legacy source deletion is forbidden until Task 4's pre-deletion replacement gate passes.
- Preserve the exact pre-phase working content of dirty `AppTemplate.xcodeproj/project.pbxproj`, `AppTemplate/Resources/Localizable.xcstrings`, and `graphify-out/`. Never stage any of them.
- Consume the immutable baseline captured by the roadmap before Phase 1. Before Task 1, verify it exists; never create or overwrite it here:

```bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
git_common_dir="$(git rev-parse --git-common-dir)"
[[ "$git_common_dir" == /* ]] || git_common_dir="$repo_root/$git_common_dir"
baseline_dir="$git_common_dir/codex-connected-mini-store-baseline"
[[ "$baseline_dir" == "$git_common_dir/"* ]] || exit 64
test -s "$baseline_dir/protected.sha256"
test -s "$baseline_dir/graphify.paths"
test -f "$baseline_dir/graphify.sha256"
```

- After every task commit, recompute actual byte hashes and the graph path manifest into fresh `mktemp` files in that baseline directory, then `cmp` them with `protected.sha256`, `graphify.sha256`, and `graphify.paths`. Run each block under `set -euo pipefail`; any producer failure or difference stops execution.
- New files use filesystem-synchronized groups; `AppTemplate.xcodeproj/project.pbxproj` must not change for membership.

---

### Task 1: Dedicated String Catalog and Localized Formatting

**Files:**

- Create: `AppTemplate/Resources/StoreServices.xcstrings`
- Create: `AppTemplate/Utilities/Localization/StoreServicesText.swift`
- Modify: `AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift`
- Modify: `AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Cart/View/CartView.swift`
- Modify: `AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift`; `AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift`; `AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift`
- Modify: `AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryView.swift`; `AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryViewModel.swift`
- Modify: `AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift`
- Modify: `AppTemplate/Features/Store/Flow/StoreFlowView.swift`; `AppTemplate/Features/Services/Flow/ServicesFlowView.swift`
- Modify: `AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift`
- Modify: `AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift`; `AppTemplate/Features/Services/Navigation/ServicesRoute.swift`
- Modify: `AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift`
- Modify: `AppTemplate/Features/Services/Screens/AppState/ServicesAppStateView.swift`; `AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoView.swift`
- Modify: `AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabView.swift`; `AppTemplate/Features/Services/Screens/Keychain/KeychainLabView.swift`
- Modify: `AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabView.swift`; `AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabView.swift`; `AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabView.swift`
- Modify: `AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift`; `AppTemplate/Features/Onboarding/Flow/OnboardingFlowView.swift`
- Modify: `AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift`; `AppTemplate/Features/Maintenance/Flow/MaintenanceFlowView.swift`; `AppTemplate/App/Navigation/Containers/SessionRestoringView.swift`; `AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift`
- Modify visible-copy producers: `AppTemplate/Features/Store/Reminders/StoreProductNotificationCategory.swift`; `AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift`; every `ViewModel`/`State` under `AppTemplate/Features/Store/Screens/` that maps a safe result to visible copy
- Modify visible-copy producers: `AppTemplate/Features/Services/Shared/Model/ServiceLabGuide.swift`; `AppTemplate/Features/Services/Screens/ServicesCatalog/ViewModel/ServicesCatalogViewModel.swift`; every `*ViewModel.swift` under `AppTemplate/Features/Services/Screens/`
- Modify visible-copy producers: every `ViewModel`/`State` under `AppTemplate/Features/Authentication/`, `AppTemplate/Features/Onboarding/`, and `AppTemplate/Features/Maintenance/` that supplies a visible result/error/help message
- Test: `AppTemplateTests/App/Localization/StoreServicesLocalizationTests.swift`
- Test: `AppTemplateTests/App/Localization/StoreFormattingTests.swift`

**Interfaces:**

- Consumes domain `Product.price: Decimal`, reminder/diagnostic timestamps from injected clocks, and all Store/Services state produced by phases 4–7.
- Produces:

```swift
nonisolated enum StoreServicesText {
    static func resource(_ key: Key) -> LocalizedStringResource
    nonisolated enum Key: String, CaseIterable, Sendable {
        case storeTitle, servicesTitle, why, preset, tryIt
        case expected, actual, resetDemoData, advanced
        case demoUSDAssumption, appWideImpact
    }
}

nonisolated enum StoreFormatting {
    static func priceUSD(_ value: Decimal, locale: Locale) -> String
    static func dateTime(_ value: Date, locale: Locale, timeZone: TimeZone) -> String
}
```

- [ ] **Step 1: Write localization and format RED**

```swift
@Test func everySharedKeyExistsInDedicatedCatalog() throws {
    let catalog = try StoreServicesCatalogFixture.loadSourceCatalog()
    for key in StoreServicesText.Key.allCases {
        #expect(catalog.keys.contains(key.rawValue))
    }
}

@Test func USDAndDateFormattingHonorLocale() {
    #expect(StoreFormatting.priceUSD(19.5, locale: Locale(identifier: "en_US"))
        == "$19.50")
    #expect(StoreFormatting.priceUSD(19.5, locale: Locale(identifier: "de_DE"))
        .contains("19,50"))
    #expect(StoreFormatting.priceUSD(19.5, locale: Locale(identifier: "ar_SA")) != StoreFormatting.priceUSD(19.5, locale: Locale(identifier: "en_US")))
}
```

In the same catalog test, require a real Arabic localization sentinel for `storeTitle` (not base-language fallback), then resolve it through `String(localized:locale: Locale(identifier:"ar_SA"))`. Freeze and scan an exact sorted source manifest covering every listed View/Flow plus all visible-copy producers listed in Files. The scanner recognizes SwiftUI text/control labels, accessibility labels/hints/announcements, `ServiceLabGuide`/`ServiceLabResult` messages, ViewModel/State safe-error messages, and OS-visible `LocalNotificationContent`/category/action titles. Permit `Text(verbatim:)` only for sanitized external runtime values and stable accessibility identifiers; never require external product/error data to be localization keys. The test fails if an active Store/Services/Auth/root/notification producer is absent from the manifest.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/StoreServicesLocalizationTests \
  -only-testing:AppTemplateTests/StoreFormattingTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL because the dedicated catalog and formatting API do not exist.

- [ ] **Step 3: Add minimal catalog-backed copy and formatters**

```swift
nonisolated enum StoreServicesText {
    static func resource(_ key: Key) -> LocalizedStringResource {
        LocalizedStringResource(
            String.LocalizationValue(key.rawValue),
            table: "StoreServices"
        )
    }
}

nonisolated enum StoreFormatting {
    static func priceUSD(_ value: Decimal, locale: Locale) -> String {
        value.formatted(.currency(code: "USD").locale(locale))
    }
}
```

Populate every literal in every exact active View/Flow and visible-copy producer listed in Files, including notification content/action titles, guide Expected/Actual/result strings, Reviews, Preferences/native Settings, Authentication Help, Restoring, Onboarding, and Maintenance. Use localized interpolation for product names/counts/safe errors, localized date/duration/count formatters, and visible demo-USD copy. The catalog test maintains the exact producer manifest and fails if a new active Store/Services/Auth/root/notification visible-copy source contains an uncatalogued literal. Do not open or rewrite `Localizable.xcstrings`.

- [ ] **Step 4: Run GREEN and verify resource inclusion**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/StoreServicesLocalizationTests \
  -only-testing:AppTemplateTests/StoreFormattingTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: PASS; build log processes `StoreServices.xcstrings`; protected dirty-file comparisons pass.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Resources/StoreServices.xcstrings \
  AppTemplate/Utilities/Localization/StoreServicesText.swift \
  AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift AppTemplate/Features/Store/Screens/Cart/View/CartView.swift \
  AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift \
  AppTemplate/Features/Store/Screens/SessionRecovery \
  AppTemplate/Features/Store/Flow/StoreFlowView.swift AppTemplate/Features/Services/Flow/ServicesFlowView.swift \
  AppTemplate/Features/Services/Navigation/ServicesRoute.swift \
  AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift AppTemplate/Features/Authentication/Flow/AuthenticationFlowView.swift AppTemplate/Features/Onboarding AppTemplate/Features/Maintenance AppTemplate/App/Navigation/Containers/SessionRestoringView.swift AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift \
  AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift AppTemplate/Features/Services/Screens/AppState/ServicesAppStateView.swift AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoView.swift \
  AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabView.swift AppTemplate/Features/Services/Screens/Keychain/KeychainLabView.swift AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabView.swift AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabView.swift AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabView.swift \
  AppTemplate/Features/Store/Reminders/StoreProductNotificationCategory.swift AppTemplate/Features/Store/Reminders/ProductReminderRepository.swift AppTemplate/Features/Store/Screens AppTemplate/Features/Services/Shared/Model/ServiceLabGuide.swift AppTemplate/Features/Services/Screens AppTemplate/Features/Authentication AppTemplate/Features/Onboarding AppTemplate/Features/Maintenance \
  AppTemplateTests/App/Localization/StoreServicesLocalizationTests.swift \
  AppTemplateTests/App/Localization/StoreFormattingTests.swift
git commit -m "feat: localize store and services experience"
```

### Task 2: Accessibility Semantics and Adaptive Policies

**Files:**

- Create: `AppTemplate/Utilities/Accessibility/AppAccessibilityIdentifier.swift`
- Create: `AppTemplate/Features/Store/Shared/StoreToolbarPolicy.swift`
- Modify: `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift`
- Modify: `AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Cart/View/CartView.swift`
- Modify: `AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
- Modify: `AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift`; `AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift`; `AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift`; `AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift`
- Modify: `AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryView.swift`
- Modify: `AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift`
- Modify: `AppTemplate/Features/Services/Screens/ServicesCatalog/View/ServicesCatalogView.swift`; `AppTemplate/Features/Services/Screens/AppState/ServicesAppStateView.swift`; `AppTemplate/Features/Services/Screens/AppInfo/ServicesAppInfoView.swift`
- Modify: `AppTemplate/Features/Services/Screens/UserDefaults/UserDefaultsLabView.swift`; `AppTemplate/Features/Services/Screens/Keychain/KeychainLabView.swift`; `AppTemplate/Features/Services/Screens/LocalDatabase/LocalDatabaseLabView.swift`; `AppTemplate/Features/Services/Screens/RemoteAPI/RemoteAPILabView.swift`; `AppTemplate/Features/Services/Screens/LocalNotifications/LocalNotificationLabView.swift`
- Modify: `AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift`; `AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift`; `AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift`
- Modify: `AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift`; `AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift`; `AppTemplate/App/Navigation/Containers/SessionRestoringView.swift`
- Test: `AppTemplateTests/App/Accessibility/AccessibilityIdentifierTests.swift`
- Test: `AppTemplateTests/Features/Store/StoreToolbarPolicyTests.swift`

**Interfaces:**

- Consumes phase-4 adaptive two-section shell and the phase-7 guide hierarchy.
- Produces:

```swift
nonisolated enum AppAccessibilityIdentifier {
    nonisolated enum Screen: String, CaseIterable, Sendable { case storeCatalog, productDetail, reviews, cart, checkout, authentication, sessionRecovery, favorites, profile, storePreferences, productReminder, servicesCatalog, serviceLab, onboarding, maintenance, restoring }
    nonisolated enum Action: String, CaseIterable, Sendable { case tryService, resetService, scheduleReminder, favorite, signIn, signOut, cancel, continueCheckout }
    nonisolated enum ResultRole: String, CaseIterable, Sendable { case actualSuccess, actualFailure, loading, empty }
    nonisolated enum ServiceDestination: String, CaseIterable, Sendable { case appState, appInfo, userDefaults, keychain, localDatabase, remoteAPI, localNotifications }
    static func screen(_ value: Screen) -> String
    static func action(_ value: Action) -> String
    static func result(_ value: ResultRole) -> String
    static func serviceDestination(_ value: ServiceDestination) -> String
}

// Task 2 adds CaseIterable to the phase-4 declaration (case order remains normative).
nonisolated enum ServicesRoute: NavigationRoute, CaseIterable { case appState, appInfo, userDefaults, keychain, localDatabase, remoteAPI, localNotifications }
nonisolated extension ServicesRoute { var accessibilityDestination: AppAccessibilityIdentifier.ServiceDestination { get } }

nonisolated enum StoreToolbarAction: Equatable, Sendable {
    case search, filter, cart, favorites, profile, more
}

nonisolated enum StoreToolbarPolicy {
    static func actions(horizontalSizeClass: UserInterfaceSizeClass?)
        -> [StoreToolbarAction]
}
```

- [ ] **Step 1: Write semantic-ID and compact-policy RED**

```swift
@Test func identifiersAreStableAndNotVisibleCopy() {
    #expect(AppAccessibilityIdentifier.screen(.storeCatalog) == "screen.store.catalog")
    #expect(AppAccessibilityIdentifier.action(.tryService) == "action.service.try")
    #expect(AppAccessibilityIdentifier.result(.actualSuccess) == "result.actual.success")
    #expect(AppAccessibilityIdentifier.serviceDestination(.appState) == "service.app-state")
    #expect(ServicesRoute.allCases.map { AppAccessibilityIdentifier.serviceDestination($0.accessibilityDestination) } == ["service.app-state", "service.app-info", "service.user-defaults", "service.keychain", "service.local-database", "service.remote-api", "service.local-notifications"])
}

@Test func compactToolbarKeepsPrimaryTasks() {
    #expect(StoreToolbarPolicy.actions(horizontalSizeClass: .compact) == [
        .search, .filter, .cart, .more
    ])
}
```

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/AccessibilityIdentifierTests \
  -only-testing:AppTemplateTests/StoreToolbarPolicyTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL because identifier and toolbar policy types do not exist.

- [ ] **Step 3: Implement semantics, focus, motion, and adaptive behavior**

```swift
nonisolated enum StoreToolbarPolicy {
    static func actions(horizontalSizeClass: UserInterfaceSizeClass?)
        -> [StoreToolbarAction] {
        horizontalSizeClass == .compact
            ? [.search, .filter, .cart, .more]
            : [.search, .filter, .cart, .favorites, .profile]
    }
}
```

Map every enum case to a frozen semantic literal and assert uniqueness/completeness. `ServicesRoute.accessibilityDestination` is an exhaustive switch, and each Services catalog row applies the corresponding `service.*` identifier consumed by the black-box robot. Apply stable IDs, explicit labels/values/traits, accessibility announcements for load/error/favorite/reminder/root/modal changes, non-color status symbols, minimum target frames, scalable layouts, and `@AccessibilityFocusState` to the first invalid field in every exact View listed in Files. Add keyboard default actions and Escape/Cancel on iPad/macOS. Disable nonessential custom animation when `accessibilityReduceMotion` is true. Keep iPad `sidebarAdaptable`; minimum macOS content is 820×620.

- [ ] **Step 4: Run GREEN on all build surfaces**

Run Step 2, then build iPhone 17 Pro, iPad Pro 13-inch (M5), and `platform=macOS,arch=arm64` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. Expected: PASS with no clipped compile-time toolbar path and no warning.

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Utilities/Accessibility \
  AppTemplate/Features/Store/Shared/StoreToolbarPolicy.swift AppTemplate/Features/Store/Screens/Catalog/View/CatalogView.swift AppTemplate/Features/Store/Screens/ProductDetail/View/ProductDetailView.swift AppTemplate/Features/Store/Screens/Cart/View/CartView.swift AppTemplate/Features/Store/Checkout/Flow/CheckoutFlowView.swift \
  AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift AppTemplate/Features/Authentication/Screens/AuthenticationHelp/View/AuthenticationHelpView.swift AppTemplate/Features/Store/Screens/SessionRecovery/SessionRecoveryView.swift AppTemplate/Features/Store/Screens/Favorites/View/FavoritesView.swift AppTemplate/Features/Store/Screens/Profile/View/ProfileView.swift AppTemplate/Features/Store/Screens/ProductReminder/View/ProductReminderView.swift AppTemplate/Features/Services/Shared/View/ServiceLabGuideView.swift AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift AppTemplate/Features/Maintenance/Screens/Maintenance/View/MaintenanceView.swift AppTemplate/App/Navigation/Containers/SessionRestoringView.swift \
  AppTemplate/Features/Store/Screens/Reviews/View/ReviewsView.swift AppTemplate/Features/Store/Screens/Preferences/View/StorePreferencesForm.swift AppTemplate/Features/Store/Settings/StoreSettingsSceneView.swift AppTemplate/Features/Services/Screens \
  AppTemplate/Features/Services/Navigation/ServicesRoute.swift \
  AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift \
  AppTemplateTests/App/Accessibility AppTemplateTests/Features/Store/StoreToolbarPolicyTests.swift
git commit -m "feat: harden adaptive accessibility semantics"
```

### Task 3: Split UI-Test Robots and Platform Smoke Journeys

**Files:**

- Move: `AppTemplateUITests/TestSupport/AppRobot.swift` → `AppTemplateUITests/Robots/AppRobot.swift`
- Move: `AppTemplateUITests/TestSupport/StoreRobot.swift` → `AppTemplateUITests/Robots/StoreRobot.swift`
- Create: `AppTemplateUITests/Robots/AuthenticationRobot.swift`
- Modify: `AppTemplateUITests/Robots/ServicesRobot.swift`
- Create: `AppTemplateUITests/Journeys/StoreJourneyTests.swift`
- Create: `AppTemplateUITests/Journeys/ServicesJourneyTests.swift`
- Create: `AppTemplateUITests/Journeys/AccessibilitySmokeTests.swift`
- Create: `Scripts/verify-xcresult-required-tests.swift`; `Scripts/connected-mini-store-required-ui-tests.tsv`
- Modify: `AppTemplateUITests/AppTemplateUITests.swift`
- Modify: `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`; `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Test: `AppTemplateTests/App/Entry/AccessibilityUITestScenarioTests.swift`; `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`
- Test: `AppTemplateTests/Project/XCResultRequiredTestsVerifierTests.swift`

**Interfaces:**

- Consumes phase-1 `UITestScenario.Name` raw values (`guest-store`, `protected-favorite`, `product-reminder`, `services-basic`, `accessibility-smoke`), `UITestScenario.named(_ id: String) throws -> UITestScenario`, stable IDs from Task 2, and phase-7 `ServicesRobot`. The black-box XCUITest bundle does not import app-module types; its robot enums are typed wire adapters whose raw values are exercised through the fail-closed launch parser and rendered accessibility IDs.
- Produces:

```swift
nonisolated enum UITestContentSize: String, Sendable { case standard, accessibilityExtraExtraExtraLarge }
nonisolated enum UITestLayoutDirection: String, Sendable { case leftToRight, rightToLeft }
nonisolated enum UITestLocale: String, Sendable { case system, arabic = "ar_SA" }
nonisolated enum UITestLocalizationVariant: String, Sendable { case standard, doubled }
nonisolated struct UITestPresentationOverrides: Equatable, Sendable { let contentSize: UITestContentSize; let layoutDirection: UITestLayoutDirection; let locale: UITestLocale; let reduceMotion: Bool; static let standard: Self; static let largestText: Self; static let arabicRTL: Self }
@MainActor final class AppRobot {
    enum Scenario: String, CaseIterable { case guestStore = "guest-store", protectedFavorite = "protected-favorite", productReminder = "product-reminder", servicesBasic = "services-basic", accessibilitySmoke = "accessibility-smoke" }
    enum ContentSize: String { case standard, accessibilityExtraExtraExtraLarge }
    enum LayoutDirection: String { case leftToRight, rightToLeft }
    enum Locale: String { case system, arabic = "ar_SA" }
    struct Overrides { let contentSize: ContentSize; let layoutDirection: LayoutDirection; let locale: Locale; let reduceMotion: Bool; static let standard: Self; static let largestText: Self; static let arabicRTL: Self }
    enum Localization: String { case standard, doubled }
    func launch(_ scenario: Scenario, overrides: Overrides = .standard,
                localization: Localization = .standard) -> XCUIApplication
    func assertScenarioScriptsExhausted(in app: XCUIApplication) throws
}
@MainActor struct StoreRobot {
    let app: XCUIApplication; func openProduct() throws; func favorite() throws
    func authenticateWithDemoAccount() throws; func signOut() throws; func assertPrimaryActionsReachable() throws
}
@MainActor struct AuthenticationRobot { let app: XCUIApplication; func submitDemoAccount() throws; func cancel() throws }
@MainActor struct ServicesRobot {
    enum Destination: String, CaseIterable { case appState = "service.app-state", appInfo = "service.app-info", userDefaults = "service.user-defaults", keychain = "service.keychain", localDatabase = "service.local-database", remoteAPI = "service.remote-api", localNotifications = "service.local-notifications" }
    let app: XCUIApplication; func runBasicLab(_ destination: Destination) throws
}
```

`verify-xcresult-required-tests.swift` is a fail-closed CLI. It invokes `xcrun xcresulttool get test-results summary` and `... tests` for one `.xcresult`, recursively decodes only test identifiers/statuses, and exits nonzero for command/JSON failure, any failed test, any skipped test unless explicitly allowlisted by exact identifier, duplicate required identifiers, a missing required `<platform, identifier>` manifest row, or a required result other than Passed. `XCResultRequiredTestsVerifierTests` runs its pure decoder/validator against fixtures for pass, missing, duplicate, failed, skipped, malformed, and unknown-status cases. The TSV freezes every journey named below with platform `all`, plus the platform-specific compact iPhone, regular iPad, and macOS keyboard/focus smoke identifiers.

- [ ] **Step 1: Write scenario RED and representative smoke test**

```swift
@Test func accessibilityScenarioIsOfflineAndLargestText() throws {
    let scenario = try UITestScenario.named("accessibility-smoke")
    #expect(scenario.networkPolicy == .failClosed)
    #expect(scenario.id == .accessibilitySmoke)
}

@Test func presentationOverridesParseOnlyInsideValidUITestLaunch() throws {
    let value = AppLaunchConfiguration(arguments: [
        "AppTemplate", "--ui-testing", "--ui-test-scenario", "accessibility-smoke",
        "--ui-test-content-size", "accessibilityExtraExtraExtraLarge",
        "--ui-test-layout-direction", "rightToLeft", "--ui-test-locale", "ar_SA",
        "--ui-test-reduce-motion"
    ])
    guard case let .uiTesting(_, overrides) = value else { Issue.record("Expected typed UI launch"); return }
    #expect(overrides == .init(contentSize: .accessibilityExtraExtraExtraLarge, layoutDirection: .rightToLeft, locale: .arabic, reduceMotion: true))
}

@MainActor func testLargestTextKeepsStorePrimaryActionsReachable() throws {
    let app = AppRobot().launch(.accessibilitySmoke, overrides: .largestText)
    try StoreRobot(app: app).assertPrimaryActionsReachable()
    try AppRobot().assertScenarioScriptsExhausted(in: app)
}
```

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/AccessibilityUITestScenarioTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO \
  -only-testing:AppTemplateUITests/AccessibilitySmokeTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: the unit command fails on the new typed override contract and the UI-test command fails on the moved robot/journey API. Both failures are specific to Task 3 rather than an already-passing scenario assertion.

- [ ] **Step 3: Move mechanics into robots and retain representative journeys**

```swift
@MainActor func runBasicLab(_ destination: ServicesRobot.Destination) throws {
    try open(destination.rawValue)
    try tap("action.service.try")
    try require("result.actual.success")
    try tap("action.service.reset")
}
```

Move the existing Phase-4 robots with `git mv` and extend them; do not introduce duplicate `AppRobot`/`StoreRobot` declarations. Extend the fail-closed app launch parser with exact typed content-size/layout-direction/locale/reduce-motion options accepted only beside a valid scenario; malformed/duplicate/unknown values remain `.invalidUITesting`. The app-module `UITestPresentationOverrides` and the XCUITest-only `AppRobot.Overrides` meet only as documented CLI raw values; parser unit tests plus one launch per override prove that wire and prevent silent drift. `AppTemplateApp` applies the parsed content size, layout direction, and `Locale(identifier:"ar_SA")` at the root environment for tests only; the robot also supplies the matching `-AppleLanguages (ar)` and `-AppleLocale ar_SA` launch pairs so Foundation/catalog resolution—not merely visual mirroring—runs in RTL locale. The doubled variant adds Foundation's `-NSDoubleLocalizedStrings YES` process pair. Keep journeys for onboarding→Store; catalog→product→reviews→related; guest favorite→auth→completion; cancel/invalid auth; public Profile/protected Account/Sign Out; cart→checkout; product/protected links; Maintenance preservation; independent Store/Services paths; App State actions; one Basic Services journey. Add compact iPhone, regular iPad, and macOS keyboard/focus smoke; largest text; doubled strings; Arabic RTL with an assertion that localized USD/date formatting uses the injected locale and leading/trailing semantics remain reachable; and Reduce Motion launch variants without multiplying all business journeys. Every journey's final assertion waits for phase-1 `ui-test.script-status.exhausted` and fails immediately on `...failed`; this proves from the XCUITest process that all planned network and image steps were consumed. A pending marker timing out is also failure.

- [ ] **Step 4: Run GREEN platform matrix**

```zsh
set -euo pipefail
result_root="$(mktemp -d "${TMPDIR:-/tmp}/AppTemplate-ui-results.XXXXXX")"
test -d "$result_root" && test ! -L "$result_root"
destinations=('platform=macOS,arch=arm64' 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5')
platforms=(macos iphone ipad)
for index in {1..3}; do
  destination="${destinations[$index]}"; platform="${platforms[$index]}"
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -parallel-testing-enabled NO \
    -only-testing:AppTemplateUITests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -resultBundlePath "$result_root/$platform.xcresult"
  swift Scripts/verify-xcresult-required-tests.swift \
    --result "$result_root/$platform.xcresult" \
    --required Scripts/connected-mini-store-required-ui-tests.tsv \
    --platform "$platform" --reject-any-skips
done
printf '%s\n' "Verified result bundles: $result_root"
```

Expected: all three destinations PASS with zero failed/skipped required tests; scenarios report zero unscripted requests.

- [ ] **Step 5: Commit**

```bash
git add Scripts/verify-xcresult-required-tests.swift Scripts/connected-mini-store-required-ui-tests.tsv AppTemplateTests/Project/XCResultRequiredTestsVerifierTests.swift \
  AppTemplateUITests/Robots/AppRobot.swift AppTemplateUITests/Robots/StoreRobot.swift AppTemplateUITests/Robots/AuthenticationRobot.swift AppTemplateUITests/Robots/ServicesRobot.swift \
  AppTemplateUITests/Journeys/StoreJourneyTests.swift AppTemplateUITests/Journeys/ServicesJourneyTests.swift AppTemplateUITests/Journeys/AccessibilitySmokeTests.swift AppTemplateUITests/AppTemplateUITests.swift \
  AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift \
  AppTemplateTests/App/Entry/AccessibilityUITestScenarioTests.swift AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift
git commit -m "test: split adaptive store ui journeys into robots"
```

### Task 4: Replacement Gate, Legacy Removal, and Release Documentation

**Files:**

- Create: `Scripts/verify-connected-mini-store-release.zsh`; `Scripts/connected-mini-store-legacy-paths.txt`; `Scripts/connected-mini-store-remote-reference-paths.txt`; `Scripts/connected-mini-store-final-change-paths.txt`; `Scripts/connected-mini-store-required-unit-tests-predelete.tsv`; `Scripts/connected-mini-store-required-unit-tests-final.tsv`
- Create: `AppTemplateTests/Project/LegacySourceRemovalTests.swift`
- Modify: `AppTemplateTests/Project/ProjectConfigurationTests.swift`
- Modify: `AppTemplate/App/Services/Remote/IRemoteService.swift`; `AppTemplate/App/Services/Remote/RemoteService.swift`; `AppTemplate/App/AppDependencies/AppDependencies.swift`
- Modify: `AppTemplateTests/App/Services/Remote/RemoteServiceTests.swift`; `AppTemplateTests/App/Composition/AppDependenciesTests.swift`; `AppTemplateTests/App/Networking/NetworkResponseTests.swift`
- Modify: every exact Swift path frozen in `Scripts/connected-mini-store-remote-reference-paths.txt` after phase 7; this includes all app/test `IRemoteService` conformers, spies, harnesses, consumers, and legacy Example remote references before removal
- Modify: `AppTemplate/App/Entry/ContentView.swift`; `AppTemplate/App/PreviewSupport/PreviewFixtures.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppRootView.swift`; `AppTemplate/App/Navigation/Containers/AppSceneView.swift`; `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`; `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Modify: `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`; `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/CUSTOMIZATION.md`
- Modify: `docs/RELEASE_CHECKLIST.md`
- Modify: `docs/README.md`
- Delete manifest source: every tracked file under `AppTemplate/Features/{Home,Browse,Projects,Settings}/` and `AppTemplateTests/Features/{Home,Browse,Projects,Settings}/` as frozen at normative commit `e372913` (143 files; exact sorted path manifest SHA-256 below)
- Delete: `AppTemplate/App/Models/Domain/BrowseItem.swift`
- Delete: `AppTemplate/App/Models/Domain/NavigationGuideItem.swift`
- Delete: `AppTemplate/App/Models/Domain/ProjectItem.swift`
- Delete: `AppTemplate/App/Models/Domain/ProjectTaskItem.swift`
- Delete: `AppTemplate/App/Models/Remote/ExampleRequest.swift`; `AppTemplate/App/Models/Remote/ExampleResponse.swift`; `AppTemplate/App/Services/Remote/ExampleTarget.swift`
- Delete: `AppTemplateTests/App/Models/Domain/ProjectItemTests.swift`; `AppTemplateTests/App/Models/Remote/ExampleRemoteModelTests.swift`

**Interfaces:**

- Consumes all replacement Store/Services routes, feature views, robots, migrations, and phase gates.
- Produces `Scripts/verify-connected-mini-store-release.zsh` with `#!/bin/zsh`, `emulate -LR zsh`, `set -euo pipefail`, no arguments, and exit status 0 only when unit/UI/build/legacy-reference gates pass; all documented array/substitution snippets in this task are explicitly zsh, and active docs describe only Store/Services. Final remote boundary is:

```swift
nonisolated protocol IRemoteService: Sendable {
    func products(_ request: ProductPageRequest) async throws -> ProductPageDTO; func categories() async throws -> [ProductCategoryDTO]
    func product(id: Int) async throws -> ProductDTO; func login(_ request: LoginRequestDTO) async throws -> AuthSessionDTO
    func me(accessToken: String) async throws -> UserProfileDTO; func refresh(_ request: RefreshRequestDTO) async throws -> AuthTokensDTO
    func diagnostic(_ request: HTTPDiagnosticRequest) async throws -> HTTPDiagnosticDTO
}
```

- [ ] **Step 1: Write the exact legacy-manifest RED**

```swift
@Test func everyAuditedLegacyPathIsAbsent() throws {
    let paths = try LegacySourceManifest.loadAuditedPaths()
    #expect(paths.count == 152)
    #expect(LegacySourceManifest.sha256(paths) == "f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8")
    for path in paths {
        #expect(!FileManager.default.fileExists(atPath: projectRoot + "/" + path))
    }
}
@Test func legacyManifestContractIsFrozenBeforeDeletion() throws {
    let paths = try LegacySourceManifest.loadAuditedPaths()
    #expect(paths.count == 152)
    #expect(LegacySourceManifest.sha256(paths) == "f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8")
}
```

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests/LegacySourceRemovalTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: FAIL because audited legacy paths still exist; count/hash mismatch also fails closed if the manifest drifts.

- [ ] **Step 3: Pass the mandatory pre-deletion replacement gate**

```zsh
set -euo pipefail
result_root="$(mktemp -d "${TMPDIR:-/tmp}/AppTemplate-predelete-results.XXXXXX")"
test -d "$result_root" && test ! -L "$result_root"
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -skip-testing:AppTemplateTests/LegacySourceRemovalTests/everyAuditedLegacyPathIsAbsent \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  -resultBundlePath "$result_root/unit-predelete.xcresult"
swift Scripts/verify-xcresult-required-tests.swift \
  --result "$result_root/unit-predelete.xcresult" \
  --required Scripts/connected-mini-store-required-unit-tests-predelete.tsv \
  --platform macos --reject-any-skips
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
destinations=('platform=macOS,arch=arm64' 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5')
platforms=(macos iphone ipad)
for index in {1..3}; do
  destination="${destinations[$index]}"; platform="${platforms[$index]}"
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -parallel-testing-enabled NO \
    -only-testing:AppTemplateUITests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -resultBundlePath "$result_root/ui-$platform.xcresult"
  swift Scripts/verify-xcresult-required-tests.swift \
    --result "$result_root/ui-$platform.xcresult" \
    --required Scripts/connected-mini-store-required-ui-tests.tsv \
    --platform "$platform" --reject-any-skips
  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
done
```

The matrix already runs the representative offline journeys from Task 3 on macOS/iPhone/iPad and inspects every result bundle. The predelete unit TSV freezes at least one exact critical test identifier for every implemented phase handoff—security/harness, AppState/migrations/database/repositories, session restore/refresh, navigation/checkout, protected actions, notification dispatch, every Services lab, localization/accessibility, composition—and requires `legacyManifestContractIsFrozenBeforeDeletion`, but deliberately does not require the still-RED absence test. The final TSV is a strict superset and additionally requires `everyAuditedLegacyPathIsAbsent`. The verifier requires every manifest entry and rejects every unallowlisted skip, so an exit-0 run with zero or silently skipped critical tests cannot pass. `ProjectConfigurationTests` constructs Store, Services, Authentication, Onboarding, Maintenance, Profile/Account, Checkout, preview, unit-test, and UI-test graphs. It exercises the production/live topology only through explicit inert seams: a temporary in-memory SwiftData container, in-memory notification runtime, fresh in-memory UserDefaults/Keychain/AppState, scripted remote/image services, fixed clock, and disabled refresh scheduler. No eager `.live()` default, disk Store, Security Keychain, notification delegate/prompt, or network transport may be evaluated; spies assert zero external calls. Expected: all commands and result inspection PASS with no required skip. If any composition cannot be constructed, stop without editing or deleting legacy sources.

- [ ] **Step 4: Remove only the exact manifest and update active references**

Before editing, run `rg -l -g '*.swift' '(IRemoteService|fetchExample|Example(Request|Response|Target))' AppTemplate AppTemplateTests AppTemplateUITests | LC_ALL=C sort -u`, inspect every result, and create `connected-mini-store-remote-reference-paths.txt` with `apply_patch` from that exact output. It deliberately includes every app/test/UI-test Swift source that references the remote boundary or legacy Example types—not merely the obvious protocol/service files—so session harnesses, Product spies, Remote-lab adapters, previews, and composition spies cannot be omitted. Then, still before any source edit, run this one-time freeze block. It rejects an existing receipt, independently recomputes the live hit set, compares it to the reviewed manifest, and atomically stores both exact bytes plus the starting HEAD outside the worktree:

```zsh
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"; [[ -n "$repo_root" && "$(pwd -P)" == "$repo_root" ]] || exit 62
git_common_dir="$(git rev-parse --git-common-dir)"; [[ "$git_common_dir" == /* ]] || git_common_dir="$repo_root/$git_common_dir"
receipt_dir="$git_common_dir/codex-connected-mini-store-phase8-remote-manifest"
[[ "$receipt_dir" == "$git_common_dir/"* && ! -e "$receipt_dir" && ! -L "$receipt_dir" ]] || exit 62
stage="$(mktemp -d "$git_common_dir/phase8-remote-manifest.tmp.XXXXXX")"; umask 077
rg -l -g '*.swift' '(IRemoteService|fetchExample|Example(Request|Response|Target))' AppTemplate AppTemplateTests AppTemplateUITests | LC_ALL=C sort -u > "$stage/discovered.txt"
test -s "$stage/discovered.txt"
remote_manifest="Scripts/connected-mini-store-remote-reference-paths.txt"
[[ -f "$remote_manifest" && ! -L "$remote_manifest" ]] || exit 62
cmp "$remote_manifest" "$stage/discovered.txt"
cp -p "$remote_manifest" "$stage/manifest.copy"
git rev-parse HEAD > "$stage/original-head"
mkdir "$receipt_dir"
for name in discovered.txt manifest.copy original-head; do mv "$stage/$name" "$receipt_dir/$name"; done
rmdir "$stage"
```

Only after this block passes, make every listed caller construct the replacement graph, remove `fetchExample` everywhere, and give `NetworkResponseTests` a private local fixture. Update `ProjectConfigurationTests` only through the inert seams from Step 3. Never recompute the hit set against the rewritten sources and call it the pre-edit manifest.

Create `connected-mini-store-final-change-paths.txt` with `apply_patch` from the reviewed, C-locale-sorted union of every Task-4 path whose bytes actually change plus all 152 legacy deletions. It includes itself and both required-unit manifests, excludes the three protected targets, and is the exact allowed final index—not a directory prefix. The frozen remote-reference manifest remains a complete pre-edit audit set, but a pure `IRemoteService` consumer need not receive a meaningless byte change: the gate partitions every hit into an actually changed/deleted member of the final manifest or an unchanged retained consumer that contains no legacy Example symbol. Run focused tests/builds, but do not delete a real legacy file yet. The zsh block then stages only the nonlegacy set, builds a synthetic candidate in isolated Git worktrees, applies the exact deletion there, runs the full release gate against a clean commit containing that exact tree, and only after success applies the same `git rm` to the real worktree. Final real-index tree identity must equal the tested candidate tree byte-for-byte. Do not delete Onboarding, Maintenance, reusable services, migration fixtures, or new Authentication.

```zsh
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)" || exit 64
[[ -n "$repo_root" && "$(pwd -P)" == "$repo_root" ]] || exit 64
git_common_dir="$(git rev-parse --git-common-dir)"; [[ "$git_common_dir" == /* ]] || git_common_dir="$repo_root/$git_common_dir"
remote_receipt="$git_common_dir/codex-connected-mini-store-phase8-remote-manifest"
[[ -d "$remote_receipt" && ! -L "$remote_receipt" ]] || exit 63
[[ "$(git rev-parse HEAD)" == "$(<"$remote_receipt/original-head")" ]] || exit 63
remote_manifest="Scripts/connected-mini-store-remote-reference-paths.txt"
[[ -f "$remote_manifest" && ! -L "$remote_manifest" ]] || exit 63
cmp "$remote_manifest" "$remote_receipt/manifest.copy"
cmp "$remote_receipt/discovered.txt" "$remote_receipt/manifest.copy"
remote_reference_files=("${(@f)$(<"$remote_manifest")}")
[[ ${#remote_reference_files[@]} -ge 3 ]] || exit 63
for target in "${remote_reference_files[@]}"; do
  [[ -n "$target" && ( "$target" == AppTemplate/* || "$target" == AppTemplateTests/* || "$target" == AppTemplateUITests/* ) ]] || exit 63
  [[ -f "$target" && ! -L "$target" ]] || exit 63
done
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO -only-testing:AppTemplateTests/RemoteServiceTests -only-testing:AppTemplateTests/NetworkResponseTests -only-testing:AppTemplateTests/ProjectConfigurationTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
manifest="Scripts/connected-mini-store-legacy-paths.txt"
final_manifest="Scripts/connected-mini-store-final-change-paths.txt"
[[ -f "$manifest" && ! -L "$manifest" ]] || exit 65
[[ -f "$final_manifest" && ! -L "$final_manifest" ]] || exit 65
sorted_manifest="$(mktemp)" || exit 66
LC_ALL=C sort -u "$manifest" > "$sorted_manifest" || exit 66
cmp "$manifest" "$sorted_manifest" || exit 66
sorted_final="$(mktemp)" || exit 66
LC_ALL=C sort -u "$final_manifest" > "$sorted_final" || exit 66
cmp "$final_manifest" "$sorted_final" || exit 66
actual_hash="$(shasum -a 256 "$manifest")" || exit 66
[[ "${actual_hash%% *}" == f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8 ]] || exit 66
legacy_files=("${(@f)$(<"$manifest")}")
final_files=("${(@f)$(<"$final_manifest")}")
[[ ${#legacy_files[@]} -eq 152 ]] || exit 67
[[ ${#final_files[@]} -gt ${#legacy_files[@]} ]] || exit 67
for target in "${legacy_files[@]}"; do
  [[ -n "$target" && ( "$target" == AppTemplate/* || "$target" == AppTemplateTests/* ) ]] || exit 68
  [[ -f "$target" && ! -L "$target" ]] || exit 69
  target_dir="${target:h}"; target_leaf="${target:t}"
  resolved_dir="$(cd -- "$target_dir" && pwd -P)" || exit 69
  [[ "$resolved_dir/$target_leaf" == "$repo_root/$target" ]] || exit 69
done
tracked_file="$(mktemp)" || exit 70; status_file="$(mktemp)" || exit 70
git ls-files -- "${legacy_files[@]}" | LC_ALL=C sort > "$tracked_file" || exit 71
cmp "$manifest" "$tracked_file" || exit 72
git status --porcelain=v1 --untracked-files=all -- "${legacy_files[@]}" > "$status_file" || exit 73
[[ ! -s "$status_file" ]] || exit 74

# The final manifest must contain every legacy deletion and no protected target.
missing_legacy="$(mktemp)"; LC_ALL=C comm -23 "$manifest" "$final_manifest" > "$missing_legacy"
[[ ! -s "$missing_legacy" ]] || exit 75
if rg -n '^(AppTemplate\.xcodeproj/project\.pbxproj|AppTemplate/Resources/Localizable\.xcstrings|graphify-out(/|$))' "$final_manifest"; then
  exit 75
else
  protected_rg_status=$?; [[ $protected_rg_status -eq 1 ]] || exit $protected_rg_status
fi

# Classify every pre-edit remote hit: actual final change/deletion or clean retained consumer.
retained_remote="$(mktemp)"; LC_ALL=C comm -23 "$remote_manifest" "$final_manifest" > "$retained_remote"
if [[ -s "$retained_remote" ]]; then
  retained_remote_files=("${(@f)$(<"$retained_remote")}")
  for target in "${retained_remote_files[@]}"; do
    [[ -f "$target" && ! -L "$target" ]] || exit 75
    git diff --quiet HEAD -- "$target" || exit 75
    if rg -n '(fetchExample|ExampleRequest|ExampleResponse|ExampleTarget)' "$target"; then
      exit 75
    else
      retained_rg_status=$?; [[ $retained_rg_status -eq 1 ]] || exit $retained_rg_status
    fi
  done
fi

# Phase commits leave a clean index. Stage only the reviewed nonlegacy candidate.
git diff --cached --quiet || exit 75
nonlegacy_manifest="$(mktemp)"; LC_ALL=C comm -23 "$final_manifest" "$manifest" > "$nonlegacy_manifest"
nonlegacy_files=("${(@f)$(<"$nonlegacy_manifest")}")
[[ ${#nonlegacy_files[@]} -gt 5 ]] || exit 75
git add -A -- "${nonlegacy_files[@]}"
cached_paths="$(mktemp)"; git diff --cached --name-only | LC_ALL=C sort -u > "$cached_paths"
cmp "$nonlegacy_manifest" "$cached_paths" || exit 75
git diff --cached --check

# Nothing implementation-related may remain outside the index.
unstaged_paths="$(mktemp)"; git diff --name-only | LC_ALL=C sort -u > "$unstaged_paths"
printf '%s\n' AppTemplate.xcodeproj/project.pbxproj AppTemplate/Resources/Localizable.xcstrings | LC_ALL=C sort > "$unstaged_paths.allowed"
cmp "$unstaged_paths.allowed" "$unstaged_paths" || exit 75
untracked_paths="$(mktemp)"; git ls-files --others --exclude-standard -z > "$untracked_paths"
while IFS= read -r -d $'\0' target; do [[ "$target" == graphify-out/* ]] || exit 75; done < "$untracked_paths"

# Materialize nonlegacy staged bytes, then perform deletion only in an isolated worktree.
original_head="$(git rev-parse HEAD)"; predelete_tree="$(git write-tree)"
predelete_commit="$(printf '%s\n' 'temporary predelete candidate' | git commit-tree "$predelete_tree" -p "$original_head")"
candidate_root="$(mktemp -d "${TMPDIR:-/tmp}/AppTemplate-final-candidate.XXXXXX")"
candidate_root="$(cd "$candidate_root" && pwd -P)"
[[ -d "$candidate_root" && ! -L "$candidate_root" && "$candidate_root" != "$repo_root" && "$candidate_root" != "$repo_root/"* ]] || exit 76
preflight="$candidate_root/preflight"; clean_candidate="$candidate_root/clean"
git worktree add --detach "$preflight" "$predelete_commit"
git -C "$preflight" rm -- "${legacy_files[@]}"
candidate_tree="$(git -C "$preflight" write-tree)"
candidate_paths="$(mktemp)"; git diff --name-only "$original_head" "$candidate_tree" | LC_ALL=C sort -u > "$candidate_paths"
cmp "$final_manifest" "$candidate_paths" || exit 76
if rg -n -g '*.swift' '(fetchExample|ExampleRequest|ExampleResponse|ExampleTarget)' "$preflight/AppTemplate" "$preflight/AppTemplateTests" "$preflight/AppTemplateUITests"; then
  exit 77
else
  rg_status=$?; [[ $rg_status -eq 1 ]] || exit $rg_status
fi
candidate_commit="$(printf '%s\n' 'temporary tested release candidate' | git commit-tree "$candidate_tree" -p "$original_head")"
git worktree add --detach "$clean_candidate" "$candidate_commit"
candidate_status="$(git -C "$clean_candidate" status --porcelain=v1 --untracked-files=all)" || exit 77
[[ -z "$candidate_status" ]] || exit 77
(cd "$clean_candidate" && zsh Scripts/verify-connected-mini-store-release.zsh)

# The full clean-candidate gate passed. Only now mirror the exact deletion locally.
git rm -- "${legacy_files[@]}"
real_paths="$(mktemp)"; git diff --cached --name-only | LC_ALL=C sort -u > "$real_paths"
cmp "$final_manifest" "$real_paths" || exit 78
[[ "$(git write-tree)" == "$candidate_tree" ]] || exit 78
git diff --cached --check

# Persist an exclusive receipt so later manual checks/commit cannot bless a different tree.
receipt_dir="$git_common_dir/codex-connected-mini-store-phase8-candidate"
[[ ! -e "$receipt_dir" && ! -L "$receipt_dir" ]] || exit 79
mkdir "$receipt_dir"
printf '%s\n' "$original_head" > "$receipt_dir/original-head"
printf '%s\n' "$candidate_tree" > "$receipt_dir/tested-tree"
printf '%s\n' "$candidate_commit" > "$receipt_dir/tested-commit"
printf '%s\n' "$candidate_root" > "$receipt_dir/candidate-root"
printf '%s\n' "$clean_candidate" > "$receipt_dir/clean-candidate-path"
shasum -a 256 "$final_manifest" > "$receipt_dir/final-manifest.sha256"

# Restore/remove only the isolated dirty preflight worktree after the receipt exists.
git -C "$preflight" restore --source=HEAD --staged --worktree -- "${legacy_files[@]}"
git worktree remove "$preflight"
```

Generate `connected-mini-store-legacy-paths.txt` from the 143 tracked feature/test files at normative commit `e372913` plus the nine exact legacy model/remote/test files, sort uniquely, then verify the frozen 152/hash contract before using it. `verify-connected-mini-store-release.zsh` creates unique unit/UI xcresults, verifies the final required-unit superset and every platform UI manifest with zero required skips, performs all three builds, validates no legacy/reference leaks with explicit `rg` status handling, and never stages or edits. Expected: focused checks and the clean synthetic candidate all pass; all 152 exact files are tracked, clean, correctly typed, resolve inside the repository without symlink traversal, and are deleted from the real worktree only after that identical candidate tree passes. Empty legacy directories disappear as a consequence, never as recursive deletion targets. If any command fails, stop: do not run the real `git rm`; leave any isolated worktree for inspection instead of retrying cleanup with a stronger command.

`LegacySourceManifest.sha256(_:)` hashes exactly the UTF-8 bytes of those C-locale-sorted unique paths, one path per line with a final newline—the same bytes stored in the manifest and checked by `shasum`—so the Swift RED and shell gate cannot disagree on serialization.

- [ ] **Step 5: Run protected-byte and manual live checks against the tested tree**

```zsh
set -euo pipefail
git_common_dir="$(git rev-parse --git-common-dir)"
[[ "$git_common_dir" == /* ]] || git_common_dir="$(git rev-parse --show-toplevel)/$git_common_dir"
baseline_dir="$git_common_dir/codex-connected-mini-store-baseline"
receipt_dir="$git_common_dir/codex-connected-mini-store-phase8-candidate"
[[ -d "$baseline_dir" && ! -L "$baseline_dir" ]] || exit 76
[[ -d "$receipt_dir" && ! -L "$receipt_dir" ]] || exit 76
[[ "$(git rev-parse HEAD)" == "$(<"$receipt_dir/original-head")" ]] || exit 76
[[ "$(git write-tree)" == "$(<"$receipt_dir/tested-tree")" ]] || exit 76
clean_candidate="$(<"$receipt_dir/clean-candidate-path")"
candidate_root="$(<"$receipt_dir/candidate-root")"
[[ -d "$clean_candidate" && ! -L "$clean_candidate" && "$clean_candidate" == "$candidate_root/clean" ]] || exit 76
[[ "$(git -C "$clean_candidate" rev-parse HEAD)" == "$(<"$receipt_dir/tested-commit")" ]] || exit 76
[[ "$(git -C "$clean_candidate" rev-parse HEAD^{tree})" == "$(<"$receipt_dir/tested-tree")" ]] || exit 76
candidate_status="$(git -C "$clean_candidate" status --porcelain=v1 --untracked-files=all)" || exit 76
[[ -z "$candidate_status" ]] || exit 76
shasum -a 256 -c "$receipt_dir/final-manifest.sha256"
current_protected="$(mktemp "$baseline_dir/current-protected.XXXXXX")"
current_graph="$(mktemp "$baseline_dir/current-graph.XXXXXX")"
current_paths="$(mktemp "$baseline_dir/current-paths.XXXXXX")"
shasum -a 256 AppTemplate.xcodeproj/project.pbxproj \
  AppTemplate/Resources/Localizable.xcstrings > "$current_protected"
cmp "$baseline_dir/protected.sha256" "$current_protected"
cmp "$baseline_dir/project.pbxproj.copy" AppTemplate.xcodeproj/project.pbxproj
cmp "$baseline_dir/Localizable.xcstrings.copy" AppTemplate/Resources/Localizable.xcstrings
find graphify-out -type f -exec shasum -a 256 {} + | LC_ALL=C sort \
  > "$current_graph"
find graphify-out -print | LC_ALL=C sort > "$current_paths"
cmp "$baseline_dir/graphify.sha256" "$current_graph"
cmp "$baseline_dir/graphify.paths" "$current_paths"
```

Perform and record the roadmap's manual live gates from the retained clean worktree at the receipt's `clean-candidate-path`: DummyJSON catalog/search/category/detail/login/profile/refresh/delay/status; real notification settings/permission granted and denied/schedule/open/Favorite/Remind Later/attachment/cancel; VoiceOver/keyboard/largest text/RTL/Reduce Motion. Recording goes outside tracked files; any tracked edit or nonclean candidate invalidates the receipt and requires rebuilding/retesting the candidate. A failed or unavailable required gate blocks the release commit rather than being reported as an automated pass. Expected: the absence RED is now PASS in the inspected final unit result, no required test is failed/skipped, no old active destination remains, and protected working bytes are unchanged/recoverable.

- [ ] **Step 6: Commit**

```zsh
set -euo pipefail
git_common_dir="$(git rev-parse --git-common-dir)"; [[ "$git_common_dir" == /* ]] || git_common_dir="$(git rev-parse --show-toplevel)/$git_common_dir"
receipt_dir="$git_common_dir/codex-connected-mini-store-phase8-candidate"
[[ -d "$receipt_dir" && ! -L "$receipt_dir" ]] || exit 80
[[ "$(git rev-parse HEAD)" == "$(<"$receipt_dir/original-head")" ]] || exit 80
[[ "$(git write-tree)" == "$(<"$receipt_dir/tested-tree")" ]] || exit 80
clean_candidate="$(<"$receipt_dir/clean-candidate-path")"; candidate_root="$(<"$receipt_dir/candidate-root")"
[[ "$clean_candidate" == "$candidate_root/clean" && -d "$clean_candidate" && ! -L "$clean_candidate" ]] || exit 80
[[ "$(git -C "$clean_candidate" rev-parse HEAD)" == "$(<"$receipt_dir/tested-commit")" ]] || exit 80
[[ "$(git -C "$clean_candidate" rev-parse HEAD^{tree})" == "$(<"$receipt_dir/tested-tree")" ]] || exit 80
candidate_status="$(git -C "$clean_candidate" status --porcelain=v1 --untracked-files=all)" || exit 80
[[ -z "$candidate_status" ]] || exit 80
final_paths="$(mktemp)"; git diff --cached --name-only | LC_ALL=C sort -u > "$final_paths"
cmp Scripts/connected-mini-store-final-change-paths.txt "$final_paths"
git diff --cached --check
git commit -m "refactor: remove superseded example features"
[[ "$(git rev-parse HEAD^{tree})" == "$(<"$receipt_dir/tested-tree")" ]] || exit 81
[[ "$clean_candidate" == "$candidate_root/clean" && -d "$clean_candidate" && ! -L "$clean_candidate" ]] || exit 82
candidate_status="$(git -C "$clean_candidate" status --porcelain=v1 --untracked-files=all)" || exit 82
[[ -z "$candidate_status" ]] || exit 82
git worktree remove "$clean_candidate"
rmdir "$candidate_root"
```
