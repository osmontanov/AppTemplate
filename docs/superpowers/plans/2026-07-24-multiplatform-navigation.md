# Multiplatform Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, typed, restorable SwiftUI navigation foundation that adapts across iOS 26, iPadOS 26, and macOS 26.

**Architecture:** A scene-scoped `AppRouter` coordinates root flow and the adaptive `TabView`, while Home, Browse, and Settings own independent typed routes and observable routers. Pure deep-link and snapshot components translate external input into router state, and SwiftUI views remain responsible for destination construction.

**Tech Stack:** Swift 6.3 toolchain, SwiftUI, Observation, Swift Testing, OSLog, Xcode 26.6, iOS/iPadOS/macOS 26 SDKs; no third-party packages.

## Global Constraints

- Minimum deployment targets are iOS 26.0, iPadOS 26.0, and macOS 26.0.
- Supported device families are iPhone, iPad, and Mac; visionOS is excluded.
- Navigation uses native `TabView`, `NavigationStack`, and feature-level `NavigationSplitView` where a hierarchy requires it.
- Navigation paths are typed `Hashable & Codable` route arrays containing stable identifiers rather than model snapshots.
- Every window scene owns an independent `AppRouter`; no process-wide router singleton is allowed.
- Home, Browse, and Settings preserve independent histories.
- Deep-link parsing, authentication gating, and restoration are deterministic and unit tested.
- Restoration persists selected section and typed paths, but not alerts, sheets, authentication forms, or pending intents.
- The implementation adds no third-party navigation or application-architecture dependency.
- Production networking, database, and authentication implementations remain outside this milestone.

## Final Review Clarifications

- A rejected deep link opens the nearest valid section root and clears only that
  section's path. Malformed Home, Browse, and Settings URLs use their respective
  roots; unknown hosts and unsupported schemes use Home. Other feature histories
  remain intact. The fallback is a typed intent, so authentication gating keeps
  last-URL-wins ordering across valid and rejected URLs.
- An unavailable Browse item returns its rejection outcome while selecting the
  Browse root and preserving Home and Settings histories.
- Deep-link path segments are split while still percent encoded and decoded
  exactly once. Empty and trailing segments are rejected rather than collapsed.
- Snapshot restoration reports when unavailable records were pruned so the
  sanitized snapshot is persisted even when it equals the router's initial
  default. Equivalent stored snapshots are not encoded or written again.
- Router and resolver dependencies use nonoptional designated APIs. Convenience
  overloads construct sample defaults inside the main-actor context.

---

## File Map

### Project and entry point

- `AppTemplate.xcodeproj/project.pbxproj`: version floors, supported platforms, test target, target dependency.
- `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`: shared build/test scheme.
- `AppTemplate/Info.plist`: `apptemplate` URL scheme.
- `AppTemplate/AppTemplateApp.swift`: creates one scene host per window.
- `AppTemplate/ContentView.swift`: preview-friendly wrapper around the new root.

### Application navigation

- `AppTemplate/App/Navigation/AppFlow.swift`: root flow values.
- `AppTemplate/App/Navigation/AppSection.swift`: top-level section values and labels.
- `AppTemplate/App/Navigation/NavigationIntent.swift`: typed external navigation requests and outcomes.
- `AppTemplate/App/Navigation/DeepLinkParser.swift`: pure URL-to-intent parser.
- `AppTemplate/App/Navigation/AppRouter.swift`: root flow, selected section, intent application, authentication gating.
- `AppTemplate/App/Navigation/NavigationSnapshot.swift`: versioned Codable state and codec.
- `AppTemplate/App/Navigation/NavigationLogger.swift`: navigation-specific `Logger`.
- `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`: restoration-first
  URL ordering and shared warm/cold handling.
- `AppTemplate/App/Navigation/AppSceneView.swift`: scene storage, URL handling, and per-scene router lifetime.
- `AppTemplate/App/Navigation/AppRootView.swift`: root-flow switch.
- `AppTemplate/App/Navigation/AppShellView.swift`: adaptive tab/sidebar shell.

### Shared navigation primitive

- `AppTemplate/Core/Navigation/StackRouting.swift`: shared typed push/pop operations.

### Example features

- `AppTemplate/Features/Home/HomeRoute.swift`: Home stack and presentation routes.
- `AppTemplate/Features/Home/HomeRouter.swift`: Home path, sheet, and alert state.
- `AppTemplate/Features/Home/HomeView.swift`: Home navigation container and destinations.
- `AppTemplate/Features/Browse/BrowseItem.swift`: stable sample item and resolver interface.
- `AppTemplate/Features/Browse/BrowseRoute.swift`: Browse stack routes.
- `AppTemplate/Features/Browse/BrowseRouter.swift`: Browse path state.
- `AppTemplate/Features/Browse/BrowseView.swift`: Browse list and item destination.
- `AppTemplate/Features/Settings/SettingsRoute.swift`: Settings stack routes.
- `AppTemplate/Features/Settings/SettingsRouter.swift`: Settings path state.
- `AppTemplate/Features/Settings/SettingsView.swift`: Settings root and About destination.

### Tests and documentation

- `AppTemplateTests/StackRoutingTests.swift`: typed stack operations and independent feature history.
- `AppTemplateTests/DeepLinkParserTests.swift`: supported and rejected URL grammar.
- `AppTemplateTests/AppRouterTests.swift`: intent application and root-flow gating.
- `AppTemplateTests/NavigationSnapshotTests.swift`: encoding, restoration, schema rejection, and record pruning.
- `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`: cold/warm URL
  ordering, contextual fallback, and sanitized persistence decisions.
- `README.md`: supported platforms, architecture, deep-link grammar, and replacement guide.

---

### Task 1: Correct platform settings and establish the test harness

**Files:**
- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Create: `AppTemplate.xcodeproj/xcshareddata/xcschemes/AppTemplate.xcscheme`
- Create: `AppTemplateTests/ProjectConfigurationTests.swift`

**Interfaces:**
- Consumes: Existing application target `D05680123013314400D3C89C`.
- Produces: Shared `AppTemplate` scheme and host-based `AppTemplateTests` unit-test target.

- [ ] **Step 1: Capture the failing configuration checks**

Run:

```bash
xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate -showBuildSettings |
  rg 'IPHONEOS_DEPLOYMENT_TARGET = 26.0|MACOSX_DEPLOYMENT_TARGET = 26.0|SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"'
test -d AppTemplateTests
```

Expected: failure because the project still uses 26.5, includes `xros`, and has no test directory.

- [ ] **Step 2: Update the application target settings**

In both target build configurations, set:

```text
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
MACOSX_DEPLOYMENT_TARGET = 26.0;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
TARGETED_DEVICE_FAMILY = "1,2";
```

Remove both `XROS_DEPLOYMENT_TARGET = 26.5;` entries.

- [ ] **Step 3: Add the unit-test target to the project**

Use these stable object identifiers:

```text
A10000013013314400D3C89C  AppTemplateTests.xctest product
A10000023013314400D3C89C  AppTemplateTests synchronized group
A10000033013314400D3C89C  Test frameworks phase
A10000043013314400D3C89C  Test resources phase
A10000053013314400D3C89C  Test sources phase
A10000063013314400D3C89C  AppTemplateTests native target
A10000073013314400D3C89C  Test configuration list
A10000083013314400D3C89C  Test Debug configuration
A10000093013314400D3C89C  Test Release configuration
A100000A3013314400D3C89C  Test-host container proxy
A100000B3013314400D3C89C  Test target dependency
```

The test target must use:

```text
productType = "com.apple.product-type.bundle.unit-test";
fileSystemSynchronizedGroups = (A10000023013314400D3C89C);
dependencies = (A100000B3013314400D3C89C);
productReference = A10000013013314400D3C89C;
```

Both test configurations must contain:

```text
BUNDLE_LOADER = "$(TEST_HOST)";
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = 33W8WHD42N;
GENERATE_INFOPLIST_FILE = YES;
IPHONEOS_DEPLOYMENT_TARGET = 26.0;
LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
MACOSX_DEPLOYMENT_TARGET = 26.0;
PRODUCT_BUNDLE_IDENTIFIER = com.oneday.AppTemplateTests;
PRODUCT_NAME = "$(TARGET_NAME)";
SDKROOT = auto;
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
SWIFT_APPROACHABLE_CONCURRENCY = YES;
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
SWIFT_VERSION = 5.0;
TARGETED_DEVICE_FAMILY = "1,2";
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AppTemplate.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AppTemplate";
TEST_TARGET_NAME = AppTemplate;
```

Add the synchronized group to the root group, the test bundle to Products, the test target to the project targets array, and `TestTargetID = D05680123013314400D3C89C` to the test target attributes.

- [ ] **Step 4: Create the shared scheme**

Create the scheme with these build and test references:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting="YES"
            buildForRunning="YES"
            buildForProfiling="YES"
            buildForArchiving="YES"
            buildForAnalyzing="YES">
            <BuildableReference
               BuildableIdentifier="primary"
               BlueprintIdentifier="D05680123013314400D3C89C"
               BuildableName="AppTemplate.app"
               BlueprintName="AppTemplate"
               ReferencedContainer="container:AppTemplate.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting="YES"
            buildForRunning="NO"
            buildForProfiling="NO"
            buildForArchiving="NO"
            buildForAnalyzing="NO">
            <BuildableReference
               BuildableIdentifier="primary"
               BlueprintIdentifier="A10000063013314400D3C89C"
               BuildableName="AppTemplateTests.xctest"
               BlueprintName="AppTemplateTests"
               ReferencedContainer="container:AppTemplate.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference skipped="NO" parallelizable="YES">
            <BuildableReference
               BuildableIdentifier="primary"
               BlueprintIdentifier="A10000063013314400D3C89C"
               BuildableName="AppTemplateTests.xctest"
               BlueprintName="AppTemplateTests"
               ReferencedContainer="container:AppTemplate.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration="Debug"
      selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle="0"
      useCustomWorkingDirectory="NO"
      ignoresPersistentStateOnLaunch="NO"
      debugDocumentVersioning="YES"
      debugServiceExtension="internal"
      allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference
            BuildableIdentifier="primary"
            BlueprintIdentifier="D05680123013314400D3C89C"
            BuildableName="AppTemplate.app"
            BlueprintName="AppTemplate"
            ReferencedContainer="container:AppTemplate.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration="Release"
      shouldUseLaunchSchemeArgsEnv="YES"
      savedToolIdentifier=""
      useCustomWorkingDirectory="NO"
      debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference
            BuildableIdentifier="primary"
            BlueprintIdentifier="D05680123013314400D3C89C"
            BuildableName="AppTemplate.app"
            BlueprintName="AppTemplate"
            ReferencedContainer="container:AppTemplate.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 5: Add a test-discovery smoke test**

```swift
import Testing
@testable import AppTemplate

struct ProjectConfigurationTests {
    @Test
    func testTargetLoadsApplicationModule() {
        #expect(true)
    }
}
```

- [ ] **Step 6: Run the configuration tests**

Run:

```bash
xcodebuild test \
  -project AppTemplate.xcodeproj \
  -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `ProjectConfigurationTests.testTargetLoadsApplicationModule()` passes and the test action reports zero failures.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate.xcodeproj AppTemplateTests
git commit -m "build: configure supported platforms and tests"
```

---

### Task 2: Add typed feature routers and shared stack operations

**Files:**
- Create: `AppTemplate/Core/Navigation/StackRouting.swift`
- Create: `AppTemplate/App/Navigation/AppSection.swift`
- Create: `AppTemplate/Features/Home/HomeRoute.swift`
- Create: `AppTemplate/Features/Home/HomeRouter.swift`
- Create: `AppTemplate/Features/Browse/BrowseItem.swift`
- Create: `AppTemplate/Features/Browse/BrowseRoute.swift`
- Create: `AppTemplate/Features/Browse/BrowseRouter.swift`
- Create: `AppTemplate/Features/Settings/SettingsRoute.swift`
- Create: `AppTemplate/Features/Settings/SettingsRouter.swift`
- Create: `AppTemplateTests/StackRoutingTests.swift`

**Interfaces:**
- Consumes: Swift Observation and Foundation Codable support.
- Produces: `StackRouting`, `AppSection`, `HomeRouter`, `BrowseRouter`, `SettingsRouter`, and their route types.

- [ ] **Step 1: Write failing stack tests**

```swift
import Testing
@testable import AppTemplate

@MainActor
struct StackRoutingTests {
    @Test
    func pushPopReplaceAndPopToRoot() {
        let router = BrowseRouter()

        router.push(.item(id: "swiftui"))
        router.push(.item(id: "observation"))
        #expect(router.path == [.item(id: "swiftui"), .item(id: "observation")])

        #expect(router.pop() == .item(id: "observation"))
        router.replacePath(with: [.item(id: "routing")])
        #expect(router.path == [.item(id: "routing")])

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test
    func featureRoutersKeepIndependentHistories() {
        let home = HomeRouter()
        let browse = BrowseRouter()
        let settings = SettingsRouter()

        home.push(.details)
        browse.push(.item(id: "swiftui"))
        settings.push(.about)

        #expect(home.path == [.details])
        #expect(browse.path == [.item(id: "swiftui")])
        #expect(settings.path == [.about])
    }
}
```

- [ ] **Step 2: Run tests to verify missing-type failures**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:AppTemplateTests/StackRoutingTests CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure for missing `BrowseRouter`, `HomeRouter`, and `SettingsRouter`.

- [ ] **Step 3: Implement shared stack behavior**

```swift
import Foundation

@MainActor
protocol StackRouting: AnyObject {
    associatedtype Route: Hashable & Codable
    var path: [Route] { get set }
}

extension StackRouting {
    func push(_ route: Route) {
        path.append(route)
    }

    @discardableResult
    func pop() -> Route? {
        path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func replacePath(with routes: [Route]) {
        path = routes
    }
}
```

- [ ] **Step 4: Implement section and feature route types**

Use these exact cases:

```swift
enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case home
    case browse
    case settings

    var id: Self { self }
}

enum HomeRoute: String, Codable, Hashable, Sendable {
    case details
}

enum HomeSheetRoute: String, Codable, Hashable, Identifiable, Sendable {
    case navigationGuide
    var id: Self { self }
}

enum HomeAlertRoute: String, Codable, Hashable, Sendable {
    case resetNavigation
}

enum BrowseRoute: Codable, Hashable, Sendable {
    case item(id: BrowseItem.ID)
}

enum SettingsRoute: String, Codable, Hashable, Sendable {
    case about
}
```

- [ ] **Step 5: Implement stable Browse records and resolver**

```swift
struct BrowseItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
}

protocol BrowseItemResolving: Sendable {
    func item(id: BrowseItem.ID) -> BrowseItem?
}

struct SampleBrowseCatalog: BrowseItemResolving {
    static let items = [
        BrowseItem(id: "swiftui", title: "SwiftUI", summary: "Adaptive native interfaces."),
        BrowseItem(id: "observation", title: "Observation", summary: "Focused state tracking."),
        BrowseItem(id: "routing", title: "Typed Routing", summary: "Navigation represented as data.")
    ]

    func item(id: BrowseItem.ID) -> BrowseItem? {
        Self.items.first { $0.id == id }
    }
}
```

- [ ] **Step 6: Implement observable feature routers**

Create `HomeRouter.swift`:

```swift
import Observation

@MainActor
@Observable
final class HomeRouter: StackRouting {
    var path: [HomeRoute]
    var sheet: HomeSheetRoute?
    var alert: HomeAlertRoute?

    init(
        path: [HomeRoute] = [],
        sheet: HomeSheetRoute? = nil,
        alert: HomeAlertRoute? = nil
    ) {
        self.path = path
        self.sheet = sheet
        self.alert = alert
    }
}
```

Create `BrowseRouter.swift`:

```swift
import Observation

@MainActor
@Observable
final class BrowseRouter: StackRouting {
    var path: [BrowseRoute]

    init(path: [BrowseRoute] = []) {
        self.path = path
    }
}
```

Create `SettingsRouter.swift`:

```swift
import Observation

@MainActor
@Observable
final class SettingsRouter: StackRouting {
    var path: [SettingsRoute]

    init(path: [SettingsRoute] = []) {
        self.path = path
    }
}
```

- [ ] **Step 7: Run typed-router tests**

Run the Task 2 test command again.

Expected: both `StackRoutingTests` pass.

- [ ] **Step 8: Commit**

```bash
git add AppTemplate/Core AppTemplate/App/Navigation/AppSection.swift \
  AppTemplate/Features AppTemplateTests/StackRoutingTests.swift
git commit -m "feat: add typed feature routers"
```

---

### Task 3: Parse custom URLs into typed navigation intents

**Files:**
- Create: `AppTemplate/App/Navigation/NavigationIntent.swift`
- Create: `AppTemplate/App/Navigation/DeepLinkParser.swift`
- Create: `AppTemplateTests/DeepLinkParserTests.swift`

**Interfaces:**
- Consumes: `AppSection` and `BrowseItem.ID`.
- Produces: `NavigationIntent`, `DeepLinkError`, and `DeepLinkParser.parse(_:)`.

- [ ] **Step 1: Write failing parser tests**

```swift
import Foundation
import Testing
@testable import AppTemplate

struct DeepLinkParserTests {
    private let parser = DeepLinkParser()

    @Test(arguments: [
        ("apptemplate://home", NavigationIntent.selectSection(.home)),
        ("apptemplate://browse", NavigationIntent.selectSection(.browse)),
        ("apptemplate://settings", NavigationIntent.selectSection(.settings)),
        ("apptemplate://browse/item/swiftui", NavigationIntent.browseItem(id: "swiftui"))
    ])
    func parsesSupportedURLs(rawURL: String, expected: NavigationIntent) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .success(expected))
    }

    @Test
    func rejectsUnsupportedScheme() throws {
        let url = try #require(URL(string: "https://example.com/browse"))
        #expect(parser.parse(url) == .failure(.unsupportedScheme))
    }

    @Test(arguments: ["apptemplate://unknown", "apptemplate://browse/other/swiftui"])
    func rejectsUnknownDestinations(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))
        #expect(parser.parse(url) == .failure(.unknownDestination))
    }
}
```

- [ ] **Step 2: Run tests to verify missing parser failures**

Run the iOS test command with `-only-testing:AppTemplateTests/DeepLinkParserTests`.

Expected: compile failure for missing `DeepLinkParser`.

- [ ] **Step 3: Implement intent and error values**

```swift
enum NavigationIntent: Equatable, Sendable {
    case selectSection(AppSection)
    case openSectionRoot(AppSection)
    case browseItem(id: BrowseItem.ID)
}

enum DeepLinkError: Error, Equatable, Sendable {
    case unsupportedScheme
    case unknownDestination
}
```

- [ ] **Step 4: Implement the pure parser**

```swift
import Foundation

struct DeepLinkParser: Sendable {
    func fallbackSection(for url: URL) -> AppSection {
        guard url.scheme?.lowercased() == "apptemplate",
              let host = url.host?.lowercased(),
              let section = AppSection(rawValue: host) else {
            return .home
        }
        return section
    }

    func parse(_ url: URL) -> Result<NavigationIntent, DeepLinkError> {
        guard url.scheme?.lowercased() == "apptemplate" else {
            return .failure(.unsupportedScheme)
        }

        guard let host = url.host?.lowercased() else {
            return .failure(.unknownDestination)
        }
        let encodedPath = url.path(percentEncoded: true)
        let encodedSegments: [Substring]
        if encodedPath.isEmpty {
            encodedSegments = []
        } else {
            guard encodedPath.first == "/" else {
                return .failure(.unknownDestination)
            }
            encodedSegments = encodedPath
                .dropFirst()
                .split(separator: "/", omittingEmptySubsequences: false)
            guard encodedSegments.allSatisfy({ !$0.isEmpty }) else {
                return .failure(.unknownDestination)
            }
        }

        var segments: [String] = []
        for encodedSegment in encodedSegments {
            guard let segment = String(encodedSegment).removingPercentEncoding else {
                return .failure(.unknownDestination)
            }
            segments.append(segment)
        }

        switch host {
        case "home" where segments.isEmpty:
            return .success(.selectSection(.home))
        case "browse" where segments.isEmpty:
            return .success(.selectSection(.browse))
        case "settings" where segments.isEmpty:
            return .success(.selectSection(.settings))
        case "browse" where segments.count == 2 && segments[0] == "item":
            let id = segments[1]
            guard !id.isEmpty else {
                return .failure(.unknownDestination)
            }
            return .success(.browseItem(id: id))
        default:
            return .failure(.unknownDestination)
        }
    }
}
```

- [ ] **Step 5: Run parser tests**

Run the Task 3 test command again.

Expected: all parser cases pass.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Navigation/NavigationIntent.swift \
  AppTemplate/App/Navigation/DeepLinkParser.swift \
  AppTemplateTests/DeepLinkParserTests.swift
git commit -m "feat: add typed deep-link parser"
```

---

### Task 4: Coordinate root flow, tabs, and protected intents

**Files:**
- Create: `AppTemplate/App/Navigation/AppFlow.swift`
- Create: `AppTemplate/App/Navigation/AppRouter.swift`
- Create: `AppTemplate/App/Navigation/NavigationLogger.swift`
- Create: `AppTemplateTests/AppRouterTests.swift`

**Interfaces:**
- Consumes: feature routers, `NavigationIntent`, and `BrowseItemResolving`.
- Produces: `AppRouter.handle(_:resolver:)`, launch/authentication transitions, and `NavigationOutcome`.

- [ ] **Step 1: Write failing router tests**

Test these exact behaviors:

```swift
import Testing
@testable import AppTemplate

@MainActor
struct AppRouterTests {
    @Test
    func browseIntentSelectsBrowseAndBuildsPath() {
        let router = AppRouter()
        let outcome = router.handle(.browseItem(id: "swiftui"))

        #expect(outcome == .applied)
        #expect(router.selectedSection == .browse)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func missingBrowseRecordFallsBackToBrowseRootAndPreservesOtherHistories() {
        let router = AppRouter(selectedSection: .settings)
        router.home.push(.details)
        router.browse.push(.item(id: "swiftui"))
        router.settings.push(.about)

        let outcome = router.handle(.browseItem(id: "missing"))

        #expect(outcome == .rejected(.missingBrowseItem("missing")))
        #expect(router.selectedSection == .browse)
        #expect(router.home.path == [.details])
        #expect(router.browse.path.isEmpty)
        #expect(router.settings.path == [.about])
    }

    @Test
    func intentWaitsForAuthenticationAndReplaysAfterSuccess() {
        let router = AppRouter(flow: .authentication)

        #expect(router.handle(.browseItem(id: "swiftui")) == .deferred)
        #expect(router.pendingIntent == .browseItem(id: "swiftui"))

        #expect(router.completeAuthentication(succeeded: true) == .applied)
        #expect(router.flow == .main)
        #expect(router.pendingIntent == nil)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func cancelledAuthenticationClearsPendingIntent() {
        let router = AppRouter(flow: .authentication)
        _ = router.handle(.selectSection(.settings))

        #expect(router.completeAuthentication(succeeded: false) == nil)
        #expect(router.pendingIntent == nil)
        #expect(router.flow == .authentication)
    }

    @Test
    func multipleScenesKeepIndependentRouterState() {
        let firstScene = AppRouter()
        let secondScene = AppRouter()

        _ = firstScene.handle(.browseItem(id: "swiftui"))

        #expect(firstScene.selectedSection == .browse)
        #expect(firstScene.browse.path == [.item(id: "swiftui")])
        #expect(secondScene.selectedSection == .home)
        #expect(secondScene.browse.path.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify missing-router failures**

Run the iOS test command with `-only-testing:AppTemplateTests/AppRouterTests`.

Expected: compile failure for missing `AppRouter`.

- [ ] **Step 3: Implement flow, outcomes, and logger**

```swift
import Foundation
import OSLog

enum AppFlow: String, Codable, Equatable, Sendable {
    case launching
    case authentication
    case main
}

enum NavigationRejection: Equatable, Sendable {
    case missingBrowseItem(BrowseItem.ID)
}

enum NavigationOutcome: Equatable, Sendable {
    case applied
    case deferred
    case rejected(NavigationRejection)
}

extension Logger {
    static let navigation = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: "Navigation"
    )
}
```

- [ ] **Step 4: Implement `AppRouter`**

```swift
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppRouter {
    var flow: AppFlow
    var selectedSection: AppSection
    let home: HomeRouter
    let browse: BrowseRouter
    let settings: SettingsRouter
    private(set) var pendingIntent: NavigationIntent?

    init(
        flow: AppFlow,
        selectedSection: AppSection,
        home: HomeRouter,
        browse: BrowseRouter,
        settings: SettingsRouter
    ) {
        self.flow = flow
        self.selectedSection = selectedSection
        self.home = home
        self.browse = browse
        self.settings = settings
    }

    convenience init(
        flow: AppFlow = .main,
        selectedSection: AppSection = .home
    ) {
        self.init(
            flow: flow,
            selectedSection: selectedSection,
            home: HomeRouter(),
            browse: BrowseRouter(),
            settings: SettingsRouter()
        )
    }

    func handle(_ intent: NavigationIntent) -> NavigationOutcome {
        handle(intent, resolver: SampleBrowseCatalog())
    }

    func handle(
        _ intent: NavigationIntent,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome {
        guard flow == .main else {
            pendingIntent = intent
            return .deferred
        }
        return apply(intent, resolver: resolver)
    }

    func finishLaunching(isAuthenticated: Bool) -> NavigationOutcome? {
        finishLaunching(
            isAuthenticated: isAuthenticated,
            resolver: SampleBrowseCatalog()
        )
    }

    func finishLaunching(
        isAuthenticated: Bool,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        flow = isAuthenticated ? .main : .authentication
        guard isAuthenticated else {
            return nil
        }
        return replayPendingIntent(resolver: resolver)
    }

    func completeAuthentication(succeeded: Bool) -> NavigationOutcome? {
        completeAuthentication(
            succeeded: succeeded,
            resolver: SampleBrowseCatalog()
        )
    }

    func completeAuthentication(
        succeeded: Bool,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        guard succeeded else {
            pendingIntent = nil
            flow = .authentication
            return nil
        }

        flow = .main
        return replayPendingIntent(resolver: resolver)
    }

    private func replayPendingIntent(
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome? {
        guard let intent = pendingIntent else {
            return nil
        }
        pendingIntent = nil
        return apply(intent, resolver: resolver)
    }

    private func apply(
        _ intent: NavigationIntent,
        resolver: any BrowseItemResolving
    ) -> NavigationOutcome {
        switch intent {
        case let .selectSection(section):
            selectedSection = section
            return .applied
        case let .openSectionRoot(section):
            openDefaultDestination(for: section)
            return .applied
        case let .browseItem(id):
            guard resolver.item(id: id) != nil else {
                openDefaultDestination(for: .browse)
                Logger.navigation.error(
                    "Rejected unavailable Browse identifier: \(id, privacy: .public)"
                )
                return .rejected(.missingBrowseItem(id))
            }
            selectedSection = .browse
            browse.replacePath(with: [.item(id: id)])
            return .applied
        }
    }

    func openDefaultDestination(for section: AppSection) {
        selectedSection = section
        switch section {
        case .home:
            home.popToRoot()
        case .browse:
            browse.popToRoot()
        case .settings:
            settings.popToRoot()
        }
    }
}
```

- [ ] **Step 5: Run router tests**

Run the Task 4 test command again.

Expected: all root-flow and intent tests pass.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/App/Navigation/AppFlow.swift \
  AppTemplate/App/Navigation/AppRouter.swift \
  AppTemplate/App/Navigation/NavigationLogger.swift \
  AppTemplateTests/AppRouterTests.swift
git commit -m "feat: coordinate application navigation"
```

---

### Task 5: Encode and restore versioned navigation snapshots

**Files:**
- Create: `AppTemplate/App/Navigation/NavigationSnapshot.swift`
- Modify: `AppTemplate/App/Navigation/AppRouter.swift`
- Create: `AppTemplateTests/NavigationSnapshotTests.swift`

**Interfaces:**
- Consumes: `AppRouter`, `AppSection`, and all feature route types.
- Produces: `AppRouter.snapshot`, `AppRouter.restore(from:resolver:)`, and `NavigationSnapshotCodec`.

- [ ] **Step 1: Write failing restoration tests**

```swift
import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct NavigationSnapshotTests {
    @Test
    func snapshotRoundTripsThroughJSON() throws {
        let router = AppRouter(selectedSection: .browse)
        router.home.push(.details)
        router.browse.push(.item(id: "swiftui"))
        router.settings.push(.about)

        let data = try NavigationSnapshotCodec.encode(router.snapshot)
        let decoded = try NavigationSnapshotCodec.decode(data)

        #expect(decoded == router.snapshot)
    }

    @Test
    func restorePrunesUnavailableBrowseRecords() throws {
        let snapshot = NavigationSnapshot(
            selectedSection: .browse,
            homePath: [.details],
            browsePath: [.item(id: "swiftui"), .item(id: "deleted")],
            settingsPath: [.about]
        )
        let router = AppRouter()
        let data = try NavigationSnapshotCodec.encode(snapshot)

        #expect(router.restore(from: data) == .restoredAfterPruning)
        #expect(router.browse.path == [.item(id: "swiftui")])
    }

    @Test
    func corruptDataResetsNavigation() {
        let router = AppRouter(selectedSection: .settings)
        router.settings.push(.about)

        #expect(router.restore(from: Data("not-json".utf8)) == .reset(.corruptData))
        #expect(router.selectedSection == .home)
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func futureSchemaResetsNavigation() throws {
        let snapshot = NavigationSnapshot(
            schemaVersion: 999,
            selectedSection: .settings,
            homePath: [],
            browsePath: [],
            settingsPath: [.about]
        )
        let router = AppRouter()

        #expect(
            router.restore(from: try NavigationSnapshotCodec.encode(snapshot))
                == .reset(.unsupportedSchema(999))
        )
    }

    @Test
    func transientAndAuthenticationStateIsNotRestored() throws {
        let source = AppRouter(flow: .authentication)
        source.home.sheet = .navigationGuide
        source.home.alert = .resetNavigation
        _ = source.handle(.selectSection(.settings))

        let restored = AppRouter()
        let data = try NavigationSnapshotCodec.encode(source.snapshot)
        #expect(restored.restore(from: data) == .restored)

        #expect(restored.flow == .main)
        #expect(restored.home.sheet == nil)
        #expect(restored.home.alert == nil)
        #expect(restored.pendingIntent == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify missing-snapshot failures**

Run the iOS test command with `-only-testing:AppTemplateTests/NavigationSnapshotTests`.

Expected: compile failure for missing `NavigationSnapshot`.

- [ ] **Step 3: Implement snapshot and codec**

```swift
import Foundation

struct NavigationSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var selectedSection: AppSection
    var homePath: [HomeRoute]
    var browsePath: [BrowseRoute]
    var settingsPath: [SettingsRoute]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        selectedSection: AppSection,
        homePath: [HomeRoute],
        browsePath: [BrowseRoute],
        settingsPath: [SettingsRoute]
    ) {
        self.schemaVersion = schemaVersion
        self.selectedSection = selectedSection
        self.homePath = homePath
        self.browsePath = browsePath
        self.settingsPath = settingsPath
    }
}

enum NavigationSnapshotCodec {
    static func encode(_ snapshot: NavigationSnapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    static func decode(_ data: Data) throws -> NavigationSnapshot {
        try JSONDecoder().decode(NavigationSnapshot.self, from: data)
    }

    static func encodingIfChanged(
        _ snapshot: NavigationSnapshot,
        comparedTo existingData: Data?
    ) throws -> Data? {
        if let existingData,
           let existingSnapshot = try? decode(existingData),
           existingSnapshot == snapshot {
            return nil
        }
        return try encode(snapshot)
    }
}

enum NavigationRestorationFailure: Equatable, Sendable {
    case corruptData
    case unsupportedSchema(Int)
}

enum NavigationRestorationResult: Equatable, Sendable {
    case noState
    case restored
    case restoredAfterPruning
    case reset(NavigationRestorationFailure)
}
```

- [ ] **Step 4: Add snapshot and restoration behavior to `AppRouter`**

```swift
extension AppRouter {
    var snapshot: NavigationSnapshot {
        NavigationSnapshot(
            selectedSection: selectedSection,
            homePath: home.path,
            browsePath: browse.path,
            settingsPath: settings.path
        )
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationRestorationResult {
        restore(from: data, resolver: SampleBrowseCatalog())
    }

    @discardableResult
    func restore(
        from data: Data?,
        resolver: any BrowseItemResolving
    ) -> NavigationRestorationResult {
        guard let data else {
            return .noState
        }

        let decoded: NavigationSnapshot
        do {
            decoded = try NavigationSnapshotCodec.decode(data)
        } catch {
            resetNavigation()
            Logger.navigation.error(
                "Reset corrupt navigation snapshot: \(String(describing: error), privacy: .public)"
            )
            return .reset(.corruptData)
        }

        guard decoded.schemaVersion == NavigationSnapshot.currentSchemaVersion else {
            resetNavigation()
            Logger.navigation.error(
                "Reset unsupported navigation schema: \(decoded.schemaVersion)"
            )
            return .reset(.unsupportedSchema(decoded.schemaVersion))
        }

        let validBrowsePath = decoded.browsePath.filter { route in
            switch route {
            case let .item(id):
                resolver.item(id: id) != nil
            }
        }

        selectedSection = decoded.selectedSection
        home.replacePath(with: decoded.homePath)
        browse.replacePath(with: validBrowsePath)
        settings.replacePath(with: decoded.settingsPath)
        return validBrowsePath.count == decoded.browsePath.count
            ? .restored
            : .restoredAfterPruning
    }

    func resetNavigation() {
        selectedSection = .home
        home.popToRoot()
        browse.popToRoot()
        settings.popToRoot()
    }
}
```

- [ ] **Step 5: Run restoration tests**

Run the Task 5 test command again.

Expected: all snapshot and reset cases pass.

- [ ] **Step 6: Run the complete unit-test suite**

Run the Task 1 test command without `-only-testing`.

Expected: all tests pass with zero failures.

- [ ] **Step 7: Commit**

```bash
git add AppTemplate/App/Navigation/AppRouter.swift \
  AppTemplate/App/Navigation/NavigationSnapshot.swift \
  AppTemplateTests/NavigationSnapshotTests.swift
git commit -m "feat: restore versioned navigation state"
```

---

### Task 6: Build the adaptive shell and feature navigation views

**Files:**
- Create: `AppTemplate/App/Navigation/AppRootView.swift`
- Create: `AppTemplate/App/Navigation/AppShellView.swift`
- Create: `AppTemplate/Features/Home/HomeView.swift`
- Create: `AppTemplate/Features/Browse/BrowseView.swift`
- Create: `AppTemplate/Features/Settings/SettingsView.swift`
- Modify: `AppTemplate/ContentView.swift`

**Interfaces:**
- Consumes: `AppRouter`, all feature routers and routes, `SampleBrowseCatalog`.
- Produces: platform-adaptive tab/sidebar UI and exhaustive destination mappings.

- [ ] **Step 1: Add compile-level UI expectations**

Extend `ProjectConfigurationTests`:

```swift
extension ProjectConfigurationTests {
    @MainActor
    @Test
    func navigationRootCanBeConstructed() {
        let router = AppRouter()
        _ = AppRootView(router: router)
        _ = AppShellView(router: router)
    }
}
```

- [ ] **Step 2: Run the test to verify missing-view failures**

Run the Task 1 test command with `-only-testing:AppTemplateTests/ProjectConfigurationTests`.

Expected: compile failure for missing `AppRootView` and `AppShellView`.

- [ ] **Step 3: Implement the root flow switch**

```swift
import SwiftUI

struct AppRootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        switch router.flow {
        case .launching:
            ProgressView("Launching…")
        case .authentication:
            AuthenticationPlaceholderView(
                onContinue: {
                    _ = router.completeAuthentication(succeeded: true)
                },
                onCancel: {
                    _ = router.completeAuthentication(succeeded: false)
                }
            )
        case .main:
            AppShellView(router: router)
        }
    }
}

private struct AuthenticationPlaceholderView: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.largeTitle)
            Text("Authentication")
                .font(.title)
            Text("Connect the project’s session service here.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel", action: onCancel)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 4: Implement the adaptive shell**

```swift
import SwiftUI

struct AppShellView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedSection) {
            Tab("Home", systemImage: "house", value: AppSection.home) {
                HomeNavigationView(router: router.home)
            }
            Tab("Browse", systemImage: "square.grid.2x2", value: AppSection.browse) {
                BrowseNavigationView(router: router.browse)
            }
            Tab("Settings", systemImage: "gearshape", value: AppSection.settings) {
                SettingsNavigationView(router: router.settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
```

- [ ] **Step 5: Implement Home navigation and presentations**

```swift
import SwiftUI

struct HomeNavigationView: View {
    @Bindable var router: HomeRouter

    private var isResetAlertPresented: Binding<Bool> {
        Binding(
            get: { router.alert != nil },
            set: { isPresented in
                if !isPresented {
                    router.alert = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("Navigation details", value: HomeRoute.details)
                Button("Open navigation guide") {
                    router.sheet = .navigationGuide
                }
                Button("Reset Home navigation", role: .destructive) {
                    router.alert = .resetNavigation
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .details:
                    HomeDetailsView()
                }
            }
        }
        .sheet(item: $router.sheet) { route in
            switch route {
            case .navigationGuide:
                NavigationStack {
                    NavigationGuideView()
                }
            }
        }
        .alert("Reset Home navigation?", isPresented: isResetAlertPresented) {
            Button("Reset", role: .destructive) {
                router.popToRoot()
                router.alert = nil
            }
            Button("Cancel", role: .cancel) {
                router.alert = nil
            }
        } message: {
            Text("This clears only the Home navigation history.")
        }
    }
}

private struct HomeDetailsView: View {
    var body: some View {
        ContentUnavailableView(
            "Typed Destination",
            systemImage: "point.topleft.down.to.point.bottomright.curvepath",
            description: Text("HomeRoute.details produced this screen.")
        )
        .navigationTitle("Details")
    }
}

private struct NavigationGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Label("Typed paths", systemImage: "list.bullet.rectangle")
            Label("Independent tabs", systemImage: "square.3.layers.3d")
            Label("Scene restoration", systemImage: "arrow.clockwise")
        }
        .navigationTitle("Navigation Guide")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
```

- [ ] **Step 6: Implement Browse navigation**

```swift
import SwiftUI

struct BrowseNavigationView: View {
    @Bindable var router: BrowseRouter
    private let catalog = SampleBrowseCatalog()

    var body: some View {
        NavigationStack(path: $router.path) {
            List(SampleBrowseCatalog.items) { item in
                NavigationLink(value: BrowseRoute.item(id: item.id)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: BrowseRoute.self) { route in
                switch route {
                case let .item(id):
                    if let item = catalog.item(id: id) {
                        BrowseDetailView(item: item)
                    } else {
                        ContentUnavailableView(
                            "Item Unavailable",
                            systemImage: "questionmark.folder",
                            description: Text("This item no longer exists.")
                        )
                    }
                }
            }
        }
    }
}

private struct BrowseDetailView: View {
    let item: BrowseItem

    var body: some View {
        Form {
            LabeledContent("Identifier", value: item.id)
            Text(item.summary)
        }
        .navigationTitle(item.title)
    }
}
```

- [ ] **Step 7: Implement Settings navigation**

```swift
import SwiftUI

struct SettingsNavigationView: View {
    @Bindable var router: SettingsRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                NavigationLink("About this template", value: SettingsRoute.about)
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .about:
                    AboutTemplateView()
                }
            }
        }
    }
}

private struct AboutTemplateView: View {
    var body: some View {
        List {
            Section("Platforms") {
                Text("iOS 26")
                Text("iPadOS 26")
                Text("macOS 26")
            }
            Section("Examples") {
                Text("Home, Browse, and Settings are replaceable feature examples.")
            }
        }
        .navigationTitle("About")
    }
}
```

- [ ] **Step 8: Replace the placeholder content**

```swift
import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter()

    var body: some View {
        AppRootView(router: router)
    }
}

#Preview {
    ContentView()
}
```

Keep `AppTemplateApp` unchanged until Task 7.

- [ ] **Step 9: Run unit tests and compile both platforms**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: tests pass and both builds finish with `** TEST SUCCEEDED **` or `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add AppTemplate/App/Navigation/AppRootView.swift \
  AppTemplate/App/Navigation/AppShellView.swift \
  AppTemplate/Features AppTemplate/ContentView.swift \
  AppTemplateTests/ProjectConfigurationTests.swift
git commit -m "feat: add adaptive navigation interface"
```

---

### Task 7: Wire scene restoration and external URL handling

**Files:**
- Create: `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`
- Create: `AppTemplate/App/Navigation/AppSceneView.swift`
- Create: `AppTemplate/Info.plist`
- Modify: `AppTemplate/AppTemplateApp.swift`
- Modify: `AppTemplate.xcodeproj/project.pbxproj`
- Modify: `AppTemplateTests/ProjectConfigurationTests.swift`
- Create: `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`

**Interfaces:**
- Consumes: `AppRouter`, `NavigationSnapshotCodec`, `DeepLinkParser`, `AppRootView`.
- Produces: scene-scoped router lifetime, `SceneStorage` restoration, and `apptemplate://` handling.

- [ ] **Step 1: Add a failing URL-registration test**

```swift
import Foundation
import Testing

extension ProjectConfigurationTests {
    @Test
    func applicationRegistersCustomURLScheme() throws {
        let urlTypes = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")
                as? [[String: Any]]
        )
        let schemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        #expect(schemes.contains("apptemplate"))
    }
}
```

- [ ] **Step 2: Run the registration test to verify failure**

Run the Task 1 test command with `-only-testing:AppTemplateTests/ProjectConfigurationTests/applicationRegistersCustomURLScheme`.

Expected: failure because `CFBundleURLTypes` is absent.

- [ ] **Step 3: Register the custom URL scheme**

Create `Info.plist` containing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.oneday.AppTemplate</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>apptemplate</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Set `INFOPLIST_FILE = AppTemplate/Info.plist;` in both application target configurations while retaining generated Info.plist support for the existing platform keys.

- [ ] **Step 4: Add failing lifecycle and URL-ordering tests**

Create `AppTemplateTests/AppSceneNavigationLifecycleTests.swift`:

```swift
import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct AppSceneNavigationLifecycleTests {
    @Test
    func coldLaunchURLAppliesAfterRestoration() throws {
        let router = AppRouter()
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        let storedSnapshot = NavigationSnapshot(
            selectedSection: .home,
            homePath: [.details],
            browsePath: [],
            settingsPath: []
        )

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        let snapshotToPersist = lifecycle.restore(
            from: try NavigationSnapshotCodec.encode(storedSnapshot)
        )

        #expect(router.selectedSection == .browse)
        #expect(router.home.path == [.details])
        #expect(router.browse.path == [.item(id: "swiftui")])
        #expect(snapshotToPersist == router.snapshot)
    }

    @Test
    func invalidURLAfterValidURLWinsAuthenticationQueue() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.browse.push(.item(id: "observation"))
        router.settings.push(.about)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://settings/not-a-route"))
        )
        _ = router.completeAuthentication(succeeded: true)

        #expect(router.selectedSection == .settings)
        #expect(router.browse.path == [.item(id: "observation")])
        #expect(router.settings.path.isEmpty)
    }

    @Test
    func validURLAfterInvalidURLDoesNotApplyOlderFallback() throws {
        let router = AppRouter(flow: .authentication)
        let lifecycle = AppSceneNavigationLifecycle(router: router)
        _ = lifecycle.restore(from: nil)
        router.settings.push(.about)

        lifecycle.receive(
            try #require(URL(string: "apptemplate://settings/not-a-route"))
        )
        lifecycle.receive(
            try #require(URL(string: "apptemplate://browse/item/swiftui"))
        )
        _ = router.completeAuthentication(succeeded: true)

        #expect(router.selectedSection == .browse)
        #expect(router.browse.path == [.item(id: "swiftui")])
        #expect(router.settings.path == [.about])
    }
}
```

- [ ] **Step 5: Run lifecycle tests to verify the missing coordinator**

Run the iOS test command with
`-only-testing:AppTemplateTests/AppSceneNavigationLifecycleTests`.

Expected: compile failure because `AppSceneNavigationLifecycle` is absent.

- [ ] **Step 6: Implement restoration-first URL coordination**

Create `AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift`:

```swift
import Foundation
import OSLog

@MainActor
final class AppSceneNavigationLifecycle {
    let router: AppRouter
    private(set) var hasRestored = false

    private let parser: DeepLinkParser
    private var queuedURLs: [URL] = []

    init() {
        router = AppRouter()
        parser = DeepLinkParser()
    }

    init(router: AppRouter) {
        self.router = router
        parser = DeepLinkParser()
    }

    init(router: AppRouter, parser: DeepLinkParser) {
        self.router = router
        self.parser = parser
    }

    @discardableResult
    func restore(from data: Data?) -> NavigationSnapshot? {
        guard !hasRestored else {
            return nil
        }

        let restorationResult = router.restore(from: data)
        hasRestored = true

        let urls = queuedURLs
        queuedURLs.removeAll()
        urls.forEach(handle)

        if !urls.isEmpty || restorationResult == .restoredAfterPruning {
            return router.snapshot
        }
        if case .reset = restorationResult {
            return router.snapshot
        }
        return nil
    }

    @discardableResult
    func receive(_ url: URL) -> NavigationSnapshot? {
        guard hasRestored else {
            queuedURLs.append(url)
            return nil
        }

        handle(url)
        return router.snapshot
    }

    private func handle(_ url: URL) {
        switch parser.parse(url) {
        case let .success(intent):
            _ = router.handle(intent)
        case let .failure(error):
            _ = router.handle(
                .openSectionRoot(parser.fallbackSection(for: url))
            )
            Logger.navigation.error(
                "Rejected deep link: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
```

- [ ] **Step 7: Run lifecycle tests**

Run the focused lifecycle suite again.

Expected: lifecycle tests pass, including both authentication URL orders.

- [ ] **Step 8: Implement the per-scene host**

```swift
import OSLog
import SwiftUI

struct AppSceneView: View {
    @State private var lifecycle = AppSceneNavigationLifecycle()
    @SceneStorage("AppTemplate.NavigationSnapshot") private var encodedSnapshot: Data?

    var body: some View {
        AppRootView(router: lifecycle.router)
            .task {
                if let snapshot = lifecycle.restore(from: encodedSnapshot) {
                    persist(snapshot)
                }
            }
            .onChange(of: lifecycle.router.snapshot) { _, snapshot in
                guard lifecycle.hasRestored else {
                    return
                }
                persist(snapshot)
            }
            .onOpenURL { url in
                if let snapshot = lifecycle.receive(url) {
                    persist(snapshot)
                }
            }
    }

    private func persist(_ snapshot: NavigationSnapshot) {
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
}
```

- [ ] **Step 9: Update the app entry point**

```swift
import SwiftUI

@main
struct AppTemplateApp: App {
    var body: some Scene {
        WindowGroup {
            AppSceneView()
        }
    }
}
```

- [ ] **Step 10: Run URL and full unit tests**

Run the Task 1 test command.

Expected: URL registration and every navigation test pass.

- [ ] **Step 11: Exercise the registered URL in Simulator**

Build and launch on iPhone 17 Pro, then run:

```bash
xcrun simctl openurl booted 'apptemplate://browse/item/swiftui'
```

Expected: the Browse tab becomes selected and the SwiftUI detail screen is visible.

- [ ] **Step 12: Commit**

```bash
git add AppTemplate/Info.plist \
  AppTemplate/App/Navigation/AppSceneNavigationLifecycle.swift \
  AppTemplate/App/Navigation/AppSceneView.swift AppTemplate/AppTemplateApp.swift \
  AppTemplate.xcodeproj AppTemplateTests/AppSceneNavigationLifecycleTests.swift \
  AppTemplateTests/ProjectConfigurationTests.swift
git commit -m "feat: restore navigation per scene"
```

---

### Task 8: Document, validate, and visually smoke-test every platform

**Files:**
- Create: `README.md`
- Modify only if verification exposes a defect: files introduced by Tasks 1–7.

**Interfaces:**
- Consumes: Completed navigation subsystem.
- Produces: User-facing boilerplate documentation and fresh verification evidence.

- [ ] **Step 1: Write the project README**

Document:

```markdown
# AppTemplate

SwiftUI boilerplate for iOS 26, iPadOS 26, and macOS 26.

## Navigation

- `TabView(.sidebarAdaptable)` provides the platform shell.
- Home, Browse, and Settings own independent typed route arrays.
- `AppRouter` is created per window scene.
- `NavigationSnapshot` restores stable identifiers through `SceneStorage`.
- `DeepLinkParser` accepts:
  - `apptemplate://home`
  - `apptemplate://browse`
  - `apptemplate://browse/item/<id>`
  - `apptemplate://settings`

Example features are removable. A replacement feature owns its route enum,
observable router, navigation container, and destination mappings.
```

Also link the design spec and implementation plan.

- [ ] **Step 2: Run formatting and placeholder checks**

Run:

```bash
git diff --check
placeholder_pattern='T''BD|T''ODO|FIX''ME'
if rg -n "$placeholder_pattern|fatalError\\(|print\\(" AppTemplate AppTemplateTests README.md; then
  exit 1
fi
```

Expected: no whitespace errors, placeholders, fatal errors, or debug prints.

- [ ] **Step 3: Run all iPhone tests**

Use XcodeBuildMCP with project `AppTemplate.xcodeproj`, scheme `AppTemplate`, and simulator `iPhone 17 Pro` on the latest installed iOS runtime.

Expected: every test passes with zero failures.

- [ ] **Step 4: Build and launch on iPhone**

Use XcodeBuildMCP `build_run_sim` with the iPhone defaults, then capture a screenshot.

Expected: bottom tab bar with Home, Browse, and Settings; Home is selected.

- [ ] **Step 5: Build and launch on iPad**

Switch the XcodeBuildMCP simulator default to `iPad Pro 13-inch (M5)`, use `build_run_sim`, and capture a screenshot.

Expected: the adaptive tab/sidebar presentation is visible and content is not clipped.

- [ ] **Step 6: Run Mac tests and build**

Run:

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: both commands succeed; the Mac app compiles with the sidebar-adaptable shell.

- [ ] **Step 7: Verify project settings**

Run:

```bash
xcodebuild -project AppTemplate.xcodeproj -scheme AppTemplate -showBuildSettings |
  rg 'IPHONEOS_DEPLOYMENT_TARGET = 26.0|MACOSX_DEPLOYMENT_TARGET = 26.0|SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"|TARGETED_DEVICE_FAMILY = "1,2"'
if rg -n 'XROS_DEPLOYMENT_TARGET|xros|xrsimulator' AppTemplate.xcodeproj/project.pbxproj; then
  exit 1
fi
```

Expected: all four required settings are present and no visionOS setting remains.

- [ ] **Step 8: Commit documentation and verification fixes**

```bash
git add README.md AppTemplate AppTemplateTests AppTemplate.xcodeproj
git commit -m "docs: explain navigation architecture"
```

- [ ] **Step 9: Review the final history and worktree**

Run:

```bash
git log --oneline --decorate -10
git status --short
```

Expected: task commits are visible and the worktree is clean.
