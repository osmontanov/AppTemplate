# Native Cross-Platform App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Task 11 with one semantic navigation shell, native adaptive iPhone/iPad tabs, a native macOS sidebar, deterministic UI-test scene state, and stable nonlocalized tab identifiers installed through public UIKit APIs.

**Architecture:** Preserve the application-scoped flow coordinator/router and each scene's existing `AppRouter`, per-section `FlowRouter` values, deep-link handling, and schema-4 snapshot. Extract shared section presentation/content from two thin platform containers; on iOS/iPadOS reinforce SwiftUI tab accessibility metadata with an isolated, nonfunctional UIKit adapter. UI-test launches explicitly ignore and do not write scene snapshots, while live launches retain current restoration behavior.

**Tech Stack:** Swift 6, SwiftUI, Observation, UIKit public tab APIs, Swift Testing, XCTest UI testing, SceneStorage, String Catalogs, Xcode 26.6, iOS/iPadOS 26.5 simulators, and macOS 26.

## Global Constraints

- Work only in `/Users/aurora/Documents/AppTemplate/.worktrees/template-hardening-implementation` on `codex/template-hardening-implementation`.
- The starting commit is `356033c`; the worktree also contains intentional, uncommitted Task 11 target/scheme/UI-test/accessibility changes. Preserve them and stage only the exact files named by each task.
- Keep `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `MACOSX_DEPLOYMENT_TARGET = 26.0`; support iPhone, iPad, and macOS.
- Keep Swift 6, approachable concurrency, default MainActor isolation, and zero compiler warnings.
- Keep attributes such as `nonisolated` on their own line before declarations, matching repository style.
- Preserve `AppFlowCoordinator`, `AppFlowRouter`, `AppRouter`, every `FlowRouter`, typed routes, deep links, pending intents, transition checkpoints, and navigation snapshot schema 4.
- Do not add a custom tab bar/sidebar, new navigation protocol, service, repository, model, ViewModel, service locator, AppKit bridge, or UIKit-owned navigation hierarchy.
- The UIKit adapter may use only public `UITabBarController`, `UITab`, `UITabBarItem`, `UIViewController`, and `UIAccessibilityIdentification` APIs.
- Never resolve tabs by index, localized title, symbol, private SwiftUI class, KVC, or hidden/proxy controls.
- Keep the exact UI-test launch arguments `--ui-testing --ui-test-root <root>` and the exact four-element parser contract.
- Keep exact automation identifiers: `screen.onboarding`, `screen.authentication`, `screen.home`, `screen.browse`, `screen.settings`, `screen.navigationGuide`, `screen.browseOptions`, `screen.appSettings`, `tab.home`, `tab.browse`, `tab.projects`, `tab.settings`, `action.openNavigationGuide`, `action.openBrowseOptions`, `action.dismissBrowseOptions`, and `action.openSettingsWindow`.
- Do not select localized labels, sleep, raise timeouts to conceal a selector failure, depend on test ordering, or share application/scene state between test methods.
- Every behavioral Swift change follows RED/GREEN/refactor: add the focused test, observe the expected failure, implement the minimum behavior, and rerun focused plus affected suites.
- Layout-only extraction is verified by metadata tests, compilation, and real UI tests; do not add assertion-free view-construction or source-shape tests.
- Preserve RED/GREEN `.xcresult` artifacts under `.superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/` and update the existing ignored Task 11 implementation report.
- Do not implement Task 12 CI/documentation work in this plan.

---

## File and Responsibility Map

### Scene persistence composition

- Create `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicy.swift`: pure live-versus-ephemeral restoration/write policy.
- Modify `AppTemplate/App/Entry/AppLaunchConfiguration.swift`: map live/UI-test launch composition to the policy without changing argument parsing.
- Modify `AppTemplate/App/Entry/AppTemplateApp.swift`: pass the selected policy into each scene.
- Modify `AppTemplate/App/Navigation/Containers/AppSceneView.swift`: filter restoration input and persistence writes through the policy.
- Create `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicyTests.swift`: pure policy behavior.
- Modify `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`: launch-mode-to-policy mapping.

### Shared and platform shell views

- Replace `AppTemplate/App/Navigation/Containers/AppShellView.swift`: platform dispatcher only.
- Create `AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift`: localized title, SF Symbol, stable presentation ID, and stable automation ID for every `AppSection`.
- Create `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`: the only section-to-flow-root switch.
- Create `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`: iPhone/iPad `.sidebarAdaptable` `TabView`.
- Create `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`: macOS `NavigationSplitView` and native sidebar selection.
- Create `AppTemplateTests/App/Navigation/Containers/AppSectionPresentationTests.swift`: exact/unique metadata contract.

### UIKit metadata and UI coverage

- Create `AppTemplate/App/Navigation/Containers/Platforms/iOS/TabAccessibilityIdentifierInstaller.swift`: public UIKit metadata adapter plus testable installation function.
- Create `AppTemplateTests/App/Navigation/Containers/TabAccessibilityIdentifierInstallerTests.swift`: identifier-based lookup, idempotency, missing-tab, and selection-preservation tests on iOS.
- Finish `AppTemplateUITests/AppTemplateUITests.swift`: cross-platform smoke tests, an iOS/iPad ordered-relaunch regression, and main-root-aware macOS launch behavior.
- Finish the existing Task 11 changes in `AppTemplate.xcodeproj/project.pbxproj` and `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`.
- Finish exact semantic identifiers in the eight already-modified screen views listed in Task 3.

---

### Task 1: Deterministic Scene Navigation for UI-Test Launches

**Files:**

- Create: `AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicy.swift`
- Modify: `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- Modify: `AppTemplate/App/Entry/AppTemplateApp.swift`
- Modify: `AppTemplate/App/Navigation/Containers/AppSceneView.swift`
- Create: `AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicyTests.swift`
- Modify: `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`

**Interfaces:**

- Consumes: the existing `AppLaunchConfiguration.live` / `.uiTesting(initialState:)` cases and `AppSceneView`'s `@SceneStorage` data.
- Produces:

```swift
nonisolated
enum AppSceneNavigationPersistencePolicy: Equatable, Sendable {
    case restored
    case ephemeral

    var allowsSnapshotPersistence: Bool { get }
    func restorationData(from storedData: Data?) -> Data?
}
```

- `AppLaunchConfiguration.sceneNavigationPersistencePolicy` maps `.live` to `.restored` and `.uiTesting` to `.ephemeral`.
- `AppSceneView.init` gains `navigationPersistencePolicy: AppSceneNavigationPersistencePolicy = .restored`.

- [ ] **Step 1: Create the artifact directory**

Run:

```bash
mkdir -p .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell
```

- [ ] **Step 2: Write the focused policy tests**

Create `AppSceneNavigationPersistencePolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

struct AppSceneNavigationPersistencePolicyTests {
    @Test
    func restoredPolicyUsesStoredDataAndAllowsWrites() {
        let storedData = Data("stored-navigation".utf8)

        #expect(
            AppSceneNavigationPersistencePolicy.restored.restorationData(
                from: storedData
            ) == storedData
        )
        #expect(
            AppSceneNavigationPersistencePolicy.restored
                .allowsSnapshotPersistence
        )
    }

    @Test
    func ephemeralPolicyIgnoresStoredDataAndRejectsWrites() {
        let storedData = Data("stored-navigation".utf8)

        #expect(
            AppSceneNavigationPersistencePolicy.ephemeral.restorationData(
                from: storedData
            ) == nil
        )
        #expect(
            !AppSceneNavigationPersistencePolicy.ephemeral
                .allowsSnapshotPersistence
        )
    }
}
```

Add this test to `AppLaunchConfigurationTests.swift`:

```swift
@Test
func launchModeSelectsSceneNavigationPersistence() {
    #expect(
        AppLaunchConfiguration.live.sceneNavigationPersistencePolicy
            == .restored
    )
    #expect(
        AppLaunchConfiguration.uiTesting(initialState: .initial)
            .sceneNavigationPersistencePolicy == .ephemeral
    )
}
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppSceneNavigationPersistencePolicyTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-1-red.xcresult
```

Expected: build/test failure because `AppSceneNavigationPersistencePolicy` and `sceneNavigationPersistencePolicy` do not exist.

- [ ] **Step 4: Implement the pure policy**

Create `AppSceneNavigationPersistencePolicy.swift`:

```swift
import Foundation

nonisolated
enum AppSceneNavigationPersistencePolicy: Equatable, Sendable {
    case restored
    case ephemeral

    var allowsSnapshotPersistence: Bool {
        self == .restored
    }

    func restorationData(from storedData: Data?) -> Data? {
        switch self {
        case .restored:
            storedData
        case .ephemeral:
            nil
        }
    }
}
```

Add to `AppLaunchConfiguration`:

```swift
var sceneNavigationPersistencePolicy: AppSceneNavigationPersistencePolicy {
    switch self {
    case .live:
        .restored
    case .uiTesting:
        .ephemeral
    }
}
```

- [ ] **Step 5: Wire the policy at application and scene composition**

Add a stored property to `AppTemplateApp` and initialize it from the parsed launch configuration:

```swift
private let sceneNavigationPersistencePolicy:
    AppSceneNavigationPersistencePolicy
```

```swift
self.sceneNavigationPersistencePolicy =
    launchConfiguration.sceneNavigationPersistencePolicy
```

Pass it into `AppSceneView`:

```swift
AppSceneView(
    appFlowCoordinator: appFlowCoordinator,
    settings: dependencies.settings,
    navigationPersistencePolicy: sceneNavigationPersistencePolicy
)
```

Add the policy property to `AppSceneView`:

```swift
private let navigationPersistencePolicy:
    AppSceneNavigationPersistencePolicy
```

Extend `AppSceneView.init` while preserving the live default used by construction tests:

```swift
init(
    appFlowCoordinator: AppFlowCoordinator,
    settings: SettingsDependencies,
    navigationPersistencePolicy:
        AppSceneNavigationPersistencePolicy = .restored
) {
    self.appFlowCoordinator = appFlowCoordinator
    self.settings = settings
    self.navigationPersistencePolicy = navigationPersistencePolicy
    _lifecycle = State(
        initialValue: AppSceneNavigationLifecycle(
            appFlowRouter: appFlowCoordinator.appFlowRouter,
            appFlowCoordinator: appFlowCoordinator
        )
    )
}
```

Filter the restoration input:

```swift
let restorationData = navigationPersistencePolicy.restorationData(
    from: encodedSnapshot
)
if lifecycle.restore(
    from: restorationData,
    applying: appFlowRouter.transition
) != nil {
    persist()
}
```

Make every existing persistence call fail closed for ephemeral composition:

```swift
private func persist() {
    guard navigationPersistencePolicy.allowsSnapshotPersistence,
          let snapshot = lifecycle.snapshotForPersistence
    else {
        return
    }
    do {
        guard let encoding = try NavigationSnapshotCodec.encodingIfChanged(
            snapshot,
            comparedTo: encodedSnapshot
        ) else {
            return
        }
        encodedSnapshot = encoding
    } catch {
        Logger.navigation.error(
            "Failed to encode navigation snapshot: \(String(describing: error), privacy: .public)"
        )
    }
}
```

- [ ] **Step 6: Run focused GREEN and affected unit tests**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppSceneNavigationPersistencePolicyTests -only-testing:AppTemplateTests/AppLaunchConfigurationTests -only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests -only-testing:AppTemplateTests/ProjectConfigurationTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-1-green.xcresult
```

Expected: all selected tests pass with no warnings. Existing lifecycle snapshot behavior remains unchanged because `.restored` is the default.

- [ ] **Step 7: Build the affected iOS composition**

Run:

```bash
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: `** BUILD SUCCEEDED **` with zero compiler warnings.

- [ ] **Step 8: Commit Task 1 only**

Run:

```bash
git add AppTemplate/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicy.swift AppTemplate/App/Entry/AppLaunchConfiguration.swift AppTemplate/App/Entry/AppTemplateApp.swift AppTemplate/App/Navigation/Containers/AppSceneView.swift AppTemplateTests/App/Navigation/Lifecycle/AppSceneNavigationPersistencePolicyTests.swift AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift
git commit -m "test: isolate ui test scene navigation"
```

Confirm the pre-existing project/scheme/UI-test/screen changes remain unstaged.

---

### Task 2: Shared Section Presentation and Native Platform Shells

**Files:**

- Modify: `AppTemplate/App/Navigation/Containers/AppShellView.swift`
- Create: `AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift`
- Create: `AppTemplate/App/Navigation/Containers/AppSectionContentView.swift`
- Create: `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`
- Create: `AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift`
- Create: `AppTemplateTests/App/Navigation/Containers/AppSectionPresentationTests.swift`

**Interfaces:**

- Consumes: `AppSection.allCases`, `AppRouter.selectedSection`, the existing four per-section `FlowRouter` properties, and `SettingsDependencies`.
- Produces these `AppSection` presentation properties:

```swift
var localizedTitle: LocalizedStringResource { get }
var systemImage: String { get }
var presentationIdentifier: String { get }
var accessibilityIdentifier: String { get }
```

- Produces `AppSectionContentView(section:router:settings:)`, `AdaptiveTabAppShellView(router:settings:)`, and `MacSidebarAppShellView(router:settings:)`.

- [ ] **Step 1: Write exact and uniqueness metadata tests**

Create `AppSectionPresentationTests.swift`:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct AppSectionPresentationTests {
    @Test(arguments: [
        (AppSection.home, "house", "app.section.home", "tab.home"),
        (
            AppSection.browse,
            "square.grid.2x2",
            "app.section.browse",
            "tab.browse"
        ),
        (
            AppSection.projects,
            "folder",
            "app.section.projects",
            "tab.projects"
        ),
        (
            AppSection.settings,
            "gearshape",
            "app.section.settings",
            "tab.settings"
        )
    ])
    func sectionMetadataIsStable(
        section: AppSection,
        systemImage: String,
        presentationIdentifier: String,
        accessibilityIdentifier: String
    ) {
        #expect(section.systemImage == systemImage)
        #expect(section.presentationIdentifier == presentationIdentifier)
        #expect(section.accessibilityIdentifier == accessibilityIdentifier)
    }

    @Test
    func sectionIdentifiersAreUnique() {
        let presentationIdentifiers = AppSection.allCases.map(
            \.presentationIdentifier
        )
        let accessibilityIdentifiers = AppSection.allCases.map(
            \.accessibilityIdentifier
        )

        #expect(
            Set(presentationIdentifiers).count == AppSection.allCases.count
        )
        #expect(
            Set(accessibilityIdentifiers).count == AppSection.allCases.count
        )
    }
}
```

- [ ] **Step 2: Run the focused metadata tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppSectionPresentationTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-2-red.xcresult
```

Expected: compile failure because the four presentation properties do not exist.

- [ ] **Step 3: Centralize section presentation metadata**

Create `AppSectionPresentation.swift`:

```swift
import Foundation

extension AppSection {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .home:
            "Home"
        case .browse:
            "Browse"
        case .projects:
            "Projects"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .browse:
            "square.grid.2x2"
        case .projects:
            "folder"
        case .settings:
            "gearshape"
        }
    }

    var presentationIdentifier: String {
        "app.section.\(rawValue)"
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
```

- [ ] **Step 4: Extract the single section-content switch**

Create `AppSectionContentView.swift`:

```swift
import SwiftUI

struct AppSectionContentView: View {
    let section: AppSection
    let router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        switch section {
        case .home:
            HomeFlowView(router: router.home)
        case .browse:
            BrowseFlowView(router: router.browse)
        case .projects:
            ProjectsFlowView(router: router.projects)
        case .settings:
            SettingsFlowView(
                router: router.settings,
                dependencies: settings
            )
        }
    }
}
```

- [ ] **Step 5: Create the iPhone/iPad adaptive tab adapter**

Create `AdaptiveTabAppShellView.swift`:

```swift
#if os(iOS)
import SwiftUI

struct AdaptiveTabAppShellView: View {
    @Bindable var router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        TabView(selection: $router.selectedSection) {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.localizedTitle,
                    systemImage: section.systemImage,
                    value: section
                ) {
                    AppSectionContentView(
                        section: section,
                        router: router,
                        settings: settings
                    )
                }
                .customizationID(section.presentationIdentifier)
                .accessibilityIdentifier(
                    section.accessibilityIdentifier
                )
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif
```

- [ ] **Step 6: Create the macOS native sidebar adapter**

Create `MacSidebarAppShellView.swift`:

```swift
#if os(macOS)
import SwiftUI

struct MacSidebarAppShellView: View {
    @Bindable var router: AppRouter
    let settings: SettingsDependencies

    var body: some View {
        NavigationSplitView {
            List(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(
                        section.localizedTitle,
                        systemImage: section.systemImage
                    )
                    .accessibilityIdentifier(
                        section.accessibilityIdentifier
                    )
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            AppSectionContentView(
                section: router.selectedSection,
                router: router,
                settings: settings
            )
        }
    }
}
#endif
```

- [ ] **Step 7: Reduce `AppShellView` to platform dispatch**

Replace its body with:

```swift
var body: some View {
#if os(macOS)
    MacSidebarAppShellView(
        router: router,
        settings: settings
    )
#else
    AdaptiveTabAppShellView(
        router: router,
        settings: settings
    )
#endif
}
```

Do not add state or navigation methods to any of the three shell views.

- [ ] **Step 8: Run metadata GREEN and platform builds**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/AppSectionPresentationTests -only-testing:AppTemplateTests/ProjectConfigurationTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-2-green.xcresult
```

Run:

```bash
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Run:

```bash
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: focused tests and both builds succeed with no warnings.

- [ ] **Step 9: Verify the extracted macOS shell through current UI WIP**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseTabShowsBrowseScreen -only-testing:AppTemplateUITests/AppTemplateUITests/testSettingsWindowCanBeOpened -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-2-macos-ui-green.xcresult
```

Expected: both tests pass through native sidebar rows. If macOS Automation Mode requests authorization, stop and let the user approve it; do not work around the security prompt.

- [ ] **Step 10: Commit Task 2 only**

Run:

```bash
git add AppTemplate/App/Navigation/Containers/AppShellView.swift AppTemplate/App/Navigation/Containers/AppSectionPresentation.swift AppTemplate/App/Navigation/Containers/AppSectionContentView.swift AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift AppTemplate/App/Navigation/Containers/Platforms/macOS/MacSidebarAppShellView.swift AppTemplateTests/App/Navigation/Containers/AppSectionPresentationTests.swift
git commit -m "refactor: split native platform app shells"
```

Confirm the project/scheme/UI-test/screen changes remain unstaged.

---

### Task 3: Public UIKit Tab Metadata and Final UI-Test Target

**Files:**

- Create: `AppTemplate/App/Navigation/Containers/Platforms/iOS/TabAccessibilityIdentifierInstaller.swift`
- Modify: `AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift`
- Create: `AppTemplateTests/App/Navigation/Containers/TabAccessibilityIdentifierInstallerTests.swift`
- Finish: `AppTemplateUITests/AppTemplateUITests.swift`
- Finish: `AppTemplate.xcodeproj/project.pbxproj`
- Finish: `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`
- Finish identifiers in:
  - `AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift`
  - `AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift`
  - `AppTemplate/Features/Browse/Screens/BrowseOptions/View/BrowseOptionsView.swift`
  - `AppTemplate/Features/Home/Screens/Home/View/HomeView.swift`
  - `AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift`
  - `AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift`
  - `AppTemplate/Features/Settings/Screens/AppSettings/View/AppSettingsView.swift`
  - `AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift`

**Interfaces:**

- Consumes: the Task 2 presentation/customization IDs and the current Task 11 UI target WIP.
- Produces:

```swift
#if os(iOS)
struct TabAccessibilityIdentifierInstaller: UIViewControllerRepresentable {
    @discardableResult
    @MainActor
    static func install(
        in tabBarController: UITabBarController
    ) -> Set<AppSection>
}
#endif
```

- `install(in:)` returns unresolved sections, mutates only `UITab.accessibilityIdentifier` and `UITab.viewController?.tabBarItem.accessibilityIdentifier`, and preserves selection.
- The UI-test target remains filesystem-synchronized, supports `iphoneos`, `iphonesimulator`, and `macosx`, and has bundle identifier `$(APP_BUNDLE_IDENTIFIER).uitests` with `TEST_TARGET_NAME = AppTemplate`.

- [ ] **Step 1: Add an explicit ordered-relaunch UI regression**

Add under `#if os(iOS)` in `AppTemplateUITests`:

```swift
@MainActor
func testTabIdentifiersSurviveIndependentRelaunches() {
    let identifiers = [
        "tab.home",
        "tab.browse",
        "tab.projects",
        "tab.settings"
    ]
    let first = launch(root: "main")

    for identifier in identifiers {
        XCTAssertTrue(
            first.descendants(matching: .any)[identifier]
                .waitForExistence(timeout: 5)
        )
    }
    first.terminate()

    let second = launch(root: "main")
    activate(second.descendants(matching: .any)["tab.browse"])

    XCTAssertTrue(
        second.descendants(matching: .any)["screen.browse"]
            .waitForExistence(timeout: 5)
    )
}
```

- [ ] **Step 2: Run the relaunch regression and preserve RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateUITests/AppTemplateUITests/testTabIdentifiersSurviveIndependentRelaunches -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-ui-red.xcresult
```

Expected: the first launch exposes the four identifiers and the later launch fails to find `tab.browse`, reproducing the SwiftUI 26 identifier-loss defect. If the current runtime fails on a different exact `tab.*` identifier, preserve the hierarchy attachment and continue only when the failure is selector metadata rather than app launch/navigation behavior. If the ordered relaunch is already GREEN after Task 2, stop and return for a design/plan amendment; do not add a UIKit adapter without a reproducible failing behavior.

- [ ] **Step 3: Write public UIKit installation tests**

Create `TabAccessibilityIdentifierInstallerTests.swift`:

```swift
#if os(iOS)
import Testing
import UIKit
@testable import AppTemplate

@MainActor
struct TabAccessibilityIdentifierInstallerTests {
    @Test
    func installationUsesStableIdentifiersAndPreservesSelection() throws {
        let tabs = AppSection.allCases.map { section in
            UITab(
                title: "Same localized title",
                image: nil,
                identifier: section.presentationIdentifier
            ) { _ in
                UIViewController()
            }
        }
        let controller = UITabBarController(tabs: tabs)
        controller.selectedTab = tabs[1]
        let selection = controller.selectedTab

        #expect(
            TabAccessibilityIdentifierInstaller.install(
                in: controller
            ).isEmpty
        )
        #expect(
            TabAccessibilityIdentifierInstaller.install(
                in: controller
            ).isEmpty
        )
        #expect(controller.selectedTab === selection)

        for section in AppSection.allCases {
            let tab = try #require(
                controller.tab(
                    forIdentifier: section.presentationIdentifier
                )
            )
            #expect(
                tab.accessibilityIdentifier
                    == section.accessibilityIdentifier
            )
            #expect(
                tab.viewController?.tabBarItem.accessibilityIdentifier
                    == section.accessibilityIdentifier
            )
        }
    }

    @Test
    func missingTabsAreReportedWithoutPositionalFallback() {
        let home = UITab(
            title: "Same localized title",
            image: nil,
            identifier: AppSection.home.presentationIdentifier
        ) { _ in
            UIViewController()
        }
        let controller = UITabBarController(tabs: [home])

        #expect(
            TabAccessibilityIdentifierInstaller.install(in: controller)
                == Set([.browse, .projects, .settings])
        )
        #expect(
            home.accessibilityIdentifier
                == AppSection.home.accessibilityIdentifier
        )
    }
}
#endif
```

- [ ] **Step 4: Run the UIKit unit tests and verify RED**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/TabAccessibilityIdentifierInstallerTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-unit-red.xcresult
```

Expected: compile failure because `TabAccessibilityIdentifierInstaller` does not exist.

- [ ] **Step 5: Implement the narrow UIKit adapter**

Create `TabAccessibilityIdentifierInstaller.swift`:

```swift
#if os(iOS)
import SwiftUI
import UIKit

struct TabAccessibilityIdentifierInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController()
    }

    func updateUIViewController(
        _ uiViewController: InstallerViewController,
        context: Context
    ) {
        uiViewController.installIfPossible()
    }

    @discardableResult
    @MainActor
    static func install(
        in tabBarController: UITabBarController
    ) -> Set<AppSection> {
        var unresolved = Set<AppSection>()

        for section in AppSection.allCases {
            guard let tab = tabBarController.tab(
                forIdentifier: section.presentationIdentifier
            ) else {
                unresolved.insert(section)
                continue
            }
            tab.accessibilityIdentifier = section.accessibilityIdentifier
            tab.viewController?.tabBarItem.accessibilityIdentifier =
                section.accessibilityIdentifier
        }
        return unresolved
    }
}

extension TabAccessibilityIdentifierInstaller {
    final class InstallerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIfPossible()
        }

        func installIfPossible() {
            guard let tabBarController else {
                return
            }
            TabAccessibilityIdentifierInstaller.install(
                in: tabBarController
            )
        }
    }
}
#endif
```

- [ ] **Step 6: Attach the adapter without changing tab behavior**

Wrap each Task 2 tab content in `AdaptiveTabAppShellView`:

```swift
AppSectionContentView(
    section: section,
    router: router,
    settings: settings
)
.background {
    TabAccessibilityIdentifierInstaller()
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
}
```

Do not add tap gestures, bindings, selection callbacks, titles, indices, or test-only branches to the adapter.

- [ ] **Step 7: Run UIKit unit GREEN**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateTests/TabAccessibilityIdentifierInstallerTests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-unit-green.xcresult
```

Expected: both tests pass twice-idempotent installation, identifier lookup, missing-tab reporting, and selection preservation.

- [ ] **Step 8: Rerun the ordered-relaunch UI regression GREEN**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateUITests/AppTemplateUITests/testTabIdentifiersSurviveIndependentRelaunches -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-ui-green.xcresult
```

Expected: both launches expose stable tab identifiers and the second launch selects Browse successfully. If SwiftUI does not expose Task 2's `customizationID` values through `UITab.identifier`, preserve the failed hierarchy/result bundle and stop; do not introduce index/title/private lookup.

- [ ] **Step 9: Make macOS launch readiness root-specific**

Replace the current any-window condition in the UI-test launch helper:

```swift
#if os(macOS)
app.activate()
let expectedRootIdentifier = root == "main"
    ? "screen.home"
    : "screen.\(root)"
let expectedRoot = app.descendants(matching: .any)[
    expectedRootIdentifier
]
if !expectedRoot.waitForExistence(timeout: 5) {
    app.typeKey("n", modifierFlags: .command)
}
#endif
```

Keep every test's final screen assertion; the launch helper opens a missing main window but does not replace behavioral assertions.

- [ ] **Step 10: Audit and finish the UI target wiring**

Verify `project.pbxproj` contains one native `AppTemplateUITests` target with:

```text
PRODUCT_BUNDLE_IDENTIFIER = $(APP_BUNDLE_IDENTIFIER).uitests
TEST_TARGET_NAME = AppTemplate
SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx
SWIFT_VERSION = 6.0
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

Verify it has one target dependency/proxy to `AppTemplate`, filesystem-synchronized source root `AppTemplateUITests`, Sources/Frameworks/Resources phases, Debug/Release configurations, and a product reference.

Verify the shared scheme BuildAction contains the UI-test target and TestAction contains exactly one unit-test and one parallelizable UI-test `TestableReference`.

Run:

```bash
plutil -lint AppTemplate.xcodeproj/project.pbxproj
```

Run:

```bash
xmllint --noout AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme
```

Run:

```bash
xcodebuild -project AppTemplate.xcodeproj -target AppTemplateUITests -configuration Debug -showBuildSettings
```

Expected: valid project/scheme files and the exact settings above for the UI-test target.

- [ ] **Step 11: Audit semantic identifiers and focused platform behavior**

Run:

```bash
rg -n '"(screen|tab|action)\.[^"]+"' AppTemplate AppTemplateUITests
```

Expected: the exact 16 identifiers from Global Constraints, with screen/action identifiers only at semantic roots/actions and tab identifiers centralized in `AppSectionPresentation` plus UI-test queries. No localized-label selector appears in `AppTemplateUITests`.

Run the five iPad UI scenarios:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateUITests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-ipad-ui-green.xcresult
```

Run the five macOS UI scenarios:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:AppTemplateUITests -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-3-macos-ui-green.xcresult
```

Expected: five UI tests pass on each platform; macOS opens the main window conditionally and opens the native Settings window without changing main-window navigation.

- [ ] **Step 12: Commit all remaining Task 11 implementation files**

Run:

```bash
git add AppTemplate.xcodeproj/project.pbxproj AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme AppTemplate/App/Navigation/Containers/Platforms/iOS/AdaptiveTabAppShellView.swift AppTemplate/App/Navigation/Containers/Platforms/iOS/TabAccessibilityIdentifierInstaller.swift AppTemplateTests/App/Navigation/Containers/TabAccessibilityIdentifierInstallerTests.swift AppTemplateUITests AppTemplate/Features/Authentication/Screens/Authentication/View/AuthenticationView.swift AppTemplate/Features/Browse/Screens/Browse/View/BrowseView.swift AppTemplate/Features/Browse/Screens/BrowseOptions/View/BrowseOptionsView.swift AppTemplate/Features/Home/Screens/Home/View/HomeView.swift AppTemplate/Features/Home/Screens/NavigationGuide/View/NavigationGuideView.swift AppTemplate/Features/Onboarding/Screens/Onboarding/View/OnboardingView.swift AppTemplate/Features/Settings/Screens/AppSettings/View/AppSettingsView.swift AppTemplate/Features/Settings/Screens/Settings/View/SettingsView.swift
git commit -m "test: add cross-platform ui coverage"
```

Expected: the commit contains the UI target/scheme, exact screen/action identifiers, iOS metadata adapter/tests, and cross-platform UI tests. It contains no Task 12 CI/docs changes.

---

### Task 4: Full Three-Platform Verification and Task 11 Report

**Files:**

- Verify: every committed file from Tasks 1–3.
- Update ignored evidence report: `.superpowers/sdd/2026-07-31-template-hardening/task-11-report.md`
- Update ignored progress ledger: `.superpowers/sdd/2026-07-31-template-hardening/progress.md`

**Interfaces:**

- Consumes: complete shared scheme with unit and UI-test targets.
- Produces: passing macOS/iPhone/iPad full-matrix evidence and a complete Task 11 implementation report; no product code.

- [ ] **Step 1: Run the complete macOS matrix**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-4-macos-full.xcresult
```

Expected: `** TEST SUCCEEDED **`, all unit tests and five macOS UI tests pass, and no compiler warnings are emitted.

- [ ] **Step 2: Run the complete iPhone matrix**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-4-iphone-full.xcresult
```

Expected: `** TEST SUCCEEDED **`, all unit tests and five iPhone UI tests pass, including independent relaunch, with no warnings.

- [ ] **Step 3: Run the complete iPad matrix**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -resultBundlePath .superpowers/sdd/2026-07-31-template-hardening/artifacts/platform-shell/task-4-ipad-full.xcresult
```

Expected: `** TEST SUCCEEDED **`, all unit tests and five iPad UI tests pass through the adaptive tab presentation, with no warnings.

- [ ] **Step 4: Perform final structural and hygiene checks**

Run:

```bash
git diff --check
```

Run:

```bash
git status --short
```

Run:

```bash
plutil -lint AppTemplate.xcodeproj/project.pbxproj
```

Run:

```bash
xmllint --noout AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme
```

Expected: no whitespace errors, a clean tracked worktree, and valid project/scheme syntax. Ignored `.xcresult` artifacts and SDD reports may exist without appearing in `git status`.

- [ ] **Step 5: Write the Task 11 evidence report**

Create or complete `.superpowers/sdd/2026-07-31-template-hardening/task-11-report.md` with these exact sections:

```markdown
# Task 11 Implementation Report

## Commits
## UI-Test Target and Shared Scheme
## Existing macOS and iPhone RED Evidence
## Platform-Shell Design Amendment
## Scene-Persistence RED/GREEN
## UIKit Identifier RED/GREEN
## macOS Full Matrix
## iPhone Full Matrix
## iPad Full Matrix
## Exact Identifier Audit
## Project and Scheme Validation
## Self-Review
## Concerns
```

Record every command, `.xcresult` path, executed/passed/failed count, relevant commit hash, exact identifier list, and whether any concern remains. Do not claim a pass from a build-only result or a failure that did not reach the intended assertion.

- [ ] **Step 6: Update the SDD progress ledger and request review**

Append Task 11 completion, commit range, matrix result, and report path to `.superpowers/sdd/2026-07-31-template-hardening/progress.md`.

Then request a fresh two-stage review under `superpowers:subagent-driven-development`: first verify plan/spec compliance, then review code quality and regression risk. Address every Critical or Important finding with a focused RED/GREEN fix round before marking Task 11 complete.

After Task 11 is review-clean, return to the existing `2026-07-31-template-hardening.md` plan at Task 12. Do not implement Task 12 as part of this plan.
