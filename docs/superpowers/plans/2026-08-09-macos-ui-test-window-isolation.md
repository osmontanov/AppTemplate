# macOS UI-Test Window Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make macOS UI-test launches independent of persisted zero-window AppKit state and guarantee one reachable initial window while preserving ordinary app restoration and existing iOS/iPadOS behavior.

**Architecture:** Keep persistence isolation at the XCUITest process boundary by passing one exact AppKit launch-argument pair and teaching `AppLaunchConfiguration` to recognize only that complete macOS form. After a bounded initial-window readiness check, use the standard macOS menu hierarchy to invoke the sole `menuAction:` in the File menu only when no window exists, without depending on localized titles. Keep product scenes unchanged, require exactly one initial content window, and make shared UI-test prerequisites throwing so a missing menu, root, or actionable element stops the test before secondary interactions.

**Tech Stack:** Swift 6, Swift Testing, XCTest/XCUITest, SwiftUI application lifecycle, Xcode 26.6; no AppKit bridge or third-party dependency.

## Global Constraints

- Modify only `AppLaunchConfiguration.swift`, its unit tests, and `AppTemplateUITests.swift`.
- Do not modify `AppTemplateApp`, `WindowGroup`, Settings scenes, production restoration, accessibility identifiers, entitlements, preferences, Saved Application State, or user data.
- On macOS, `AppTemplateUITests` launches with exactly `-ApplePersistenceIgnoreState YES --ui-testing --ui-test-root <root>`.
- Preserve the existing exact four-element process-argument form on every platform; accept the six-element persistence-isolated form only on macOS.
- Any wrong value, missing value, reordered or duplicated persistence pair, unknown root, or additional argument resolves to `.live`.
- Do not add general retries, Command-N recovery, localized-label selectors, product-selector changes, or production window creation.
- On macOS only, give the initial window one bounded second to appear; if none appears, allow one targeted accessibility invocation through the standard File-menu position and its sole scoped `menuAction:`. Skip it when any window already exists.
- After the requested root appears on macOS, require exactly one application window before returning from the fixture.
- Every element required by a later test step must pass through `try requireExistence(...)` or the stricter `try requireSingleElement(...)`, as appropriate, before that step.
- This plan runs after Network Tasks 1–6 and before Network Task 7, whose full-scheme gate verifies the combined branch.

---

## File Map

### Modify

- `AppTemplate/App/Entry/AppLaunchConfiguration.swift` — normalize the one exact macOS persistence-isolated UI-test argument form into the existing strict parser.
- `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift` — cover all four roots through the new form and reject malformed persistence arguments.
- `AppTemplateUITests/AppTemplateUITests.swift` — pass the macOS argument pair, replace Command-N with a locale-independent zero-window menu bootstrap, require one initial window, and stop on missing prerequisites.

No new source file or Xcode project reference is required.

---

### Task 1: Recognize Only Canonical Persistence-Isolated macOS Launches

**Files:**

- Modify: `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
- Modify: `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`

**Interfaces:**

- Consumes: process arguments whose element zero is the executable path.
- Preserves: `AppLaunchConfiguration.init(arguments:)`, `UITestRoot`, and the existing four-element `--ui-testing --ui-test-root <root>` contract.
- Produces on macOS: the additional exact six-element form `[executable, "-ApplePersistenceIgnoreState", "YES", "--ui-testing", "--ui-test-root", root]`.

- [ ] **Step 1: Add the canonical-form RED test for every root**

Inside `AppLaunchConfigurationTests`, add this macOS-only parameterized test:

```swift
#if os(macOS)
@Test(arguments: [
    "onboarding",
    "authentication",
    "main",
    "maintenance"
])
func persistenceIsolatedUITestRootMapsToState(_ root: String) throws {
    let uiTestRoot = try #require(UITestRoot(rawValue: root))

    #expect(
        AppLaunchConfiguration(arguments: [
            "AppTemplate",
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-root", root
        ]) == .uiTesting(initialState: uiTestRoot.initialState)
    )
}
#endif
```

- [ ] **Step 2: Add the malformed persistence-argument table**

In the same test suite, add this separate macOS-only negative test. Keep the existing generic malformed-argument table unchanged.

```swift
#if os(macOS)
@Test(arguments: [
    [
        "AppTemplate",
        "-ApplePersistenceIgnoreState", "NO",
        "--ui-testing", "--ui-test-root", "main"
    ],
    [
        "AppTemplate",
        "-ApplePersistenceIgnoreState",
        "--ui-testing", "--ui-test-root", "main"
    ],
    [
        "AppTemplate",
        "--ui-testing", "--ui-test-root", "main",
        "-ApplePersistenceIgnoreState", "YES"
    ],
    [
        "AppTemplate",
        "-ApplePersistenceIgnoreState", "YES",
        "-ApplePersistenceIgnoreState", "YES",
        "--ui-testing", "--ui-test-root", "main"
    ],
    [
        "AppTemplate",
        "-ApplePersistenceIgnoreState", "YES",
        "--unexpected",
        "--ui-testing", "--ui-test-root", "main"
    ],
    [
        "AppTemplate",
        "-ApplePersistenceIgnoreState", "YES",
        "--ui-testing", "--ui-test-root", "unknown"
    ]
])
func malformedPersistenceIsolationArgumentsRemainLive(
    _ arguments: [String]
) {
    #expect(AppLaunchConfiguration(arguments: arguments) == .live)
}
#endif
```

- [ ] **Step 3: Run the parser RED gate**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-UIWindowParser-Red \
  -only-testing:AppTemplateTests/AppLaunchConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: the four new canonical-form cases fail because the current parser requires `arguments.count == 4`; existing four-element and malformed cases continue to pass.

- [ ] **Step 4: Normalize only the exact macOS prefix**

Replace the body of `AppLaunchConfiguration.init(arguments:)` with this implementation:

```swift
init(arguments: [String]) {
    let uiTestingMarker = "--ui-testing"
    let uiTestRootOption = "--ui-test-root"
    var uiTestingArguments = Array(arguments.dropFirst())

    #if os(macOS)
    let persistenceIsolationArguments = [
        "-ApplePersistenceIgnoreState",
        "YES"
    ]
    if uiTestingArguments.count == 5,
       Array(uiTestingArguments.prefix(2)) == persistenceIsolationArguments {
        uiTestingArguments.removeFirst(2)
    }
    #endif

    guard uiTestingArguments.count == 3,
          uiTestingArguments[0] == uiTestingMarker,
          uiTestingArguments[1] == uiTestRootOption,
          let root = UITestRoot(rawValue: uiTestingArguments[2])
    else {
        self = .live
        return
    }

    self = .uiTesting(initialState: root.initialState)
}
```

The `count == 5` condition is part of the contract: it prevents the parser from stripping the recognized pair when any duplicate or additional argument is present.

- [ ] **Step 5: Run parser GREEN and platform compile gates**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-UIWindowParser-Green \
  -only-testing:AppTemplateTests/AppLaunchConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -derivedDataPath /tmp/AppTemplate-UIWindowParser-iPhone \
  -only-testing:AppTemplateTests/AppLaunchConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -derivedDataPath /tmp/AppTemplate-UIWindowParser-iPad \
  -only-testing:AppTemplateTests/AppLaunchConfigurationTests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: all three commands exit zero. macOS accepts both exact forms, while iPhone and iPad retain only the original four-element form.

- [ ] **Step 6: Commit the strict parser contract**

```bash
git add AppTemplate/App/Entry/AppLaunchConfiguration.swift \
  AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift
git commit -m "fix: recognize isolated macOS UI test launches"
```

---

### Task 2: Isolate, Open a Missing Window, and Fail Fast in the Shared UI-Test Fixture

**Files:**

- Modify: `AppTemplateUITests/AppTemplateUITests.swift`

**Interfaces:**

- Produces:

```swift
@MainActor
private func launch(
    root: String,
    expectedRootIdentifier: String
) throws -> XCUIApplication

@MainActor
private func requireExistence(
    _ element: XCUIElement,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> XCUIElement

@MainActor
private func requireSingleElement(
    _ query: XCUIElementQuery,
    description: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> XCUIElement

@MainActor
private func activate(_ element: XCUIElement) throws
```

- Guarantees: macOS launch arguments contain the persistence-isolation pair; a missing macOS window is created through one locale-independent, structurally scoped standard-menu action at most once; exactly one initial macOS window and every platform's initial root are required; no click, tap, dismiss, termination, or relaunch proceeds after a missing prerequisite.

- [ ] **Step 1: Reconfirm or reference the recorded macOS RED baseline**

```bash
set -euo pipefail

red_root="$(mktemp -d /tmp/AppTemplate-UIWindowFixture-Red.XXXXXX)"
test -d "$red_root"
test ! -L "$red_root"
case "$red_root" in
  /tmp/AppTemplate-UIWindowFixture-Red.*) ;;
  *) exit 1 ;;
esac

set +e
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$red_root/DerivedData" \
  -resultBundlePath "$red_root/five-tests.xcresult" \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseOptionsCanBePresentedAndDismissed \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseTabShowsBrowseScreen \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testNavigationGuideCanBeOpened \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testOnboardingRootIsVisible \
  -only-testing:AppTemplateUITests/AppTemplateUITests/testSettingsWindowCanBeOpened \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
red_status=$?
set -e

test -d "$red_root/five-tests.xcresult"
xcrun xcresulttool get test-results summary \
  --path "$red_root/five-tests.xcresult" \
  | jq -r '.testFailures[]? | "\(.targetName)/\(.testName)"' \
  | sort -u > "$red_root/failing-tests.txt"

if test "$red_status" -eq 0; then
  test ! -s "$red_root/failing-tests.txt"
else
  printf '%s\n' \
    'AppTemplateUITests/testBrowseOptionsCanBePresentedAndDismissed()' \
    'AppTemplateUITests/testBrowseTabShowsBrowseScreen()' \
    'AppTemplateUITests/testNavigationGuideCanBeOpened()' \
    'AppTemplateUITests/testOnboardingRootIsVisible()' \
    'AppTemplateUITests/testSettingsWindowCanBeOpened()' \
    | sort -u > "$red_root/expected-tests.txt"
  diff -u "$red_root/expected-tests.txt" "$red_root/failing-tests.txt"
fi
```

Expected in the confirmed persisted zero-window environment: the command exits nonzero with exactly the five allowlisted fixture failures. If AppKit state happens to be clean during this rerun, the command may exit zero with no failures; the previously captured baseline bundle remains the RED evidence. Do not manufacture RED by writing or deleting persisted state, and reject any nonzero result containing a different test identifier.

- [ ] **Step 2: Replace the UI-test fixture with the exact fail-fast implementation**

Replace `AppTemplateUITests.swift` with this complete content:

```swift
import XCTest

nonisolated
final class AppTemplateUITests: XCTestCase {
    @MainActor
    func testOnboardingRootIsVisible() throws {
        let app = try launch(
            root: "onboarding",
            expectedRootIdentifier: "screen.onboarding"
        )

        XCTAssertTrue(element(in: app, identifier: "screen.onboarding").exists)
    }

    @MainActor
    func testBrowseTabShowsBrowseScreen() throws {
        let app = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )

        try activate(element(in: app, identifier: "tab.browse"))

        XCTAssertTrue(
            element(in: app, identifier: "screen.browse")
                .waitForExistence(timeout: 5)
        )
    }

    #if os(iOS)
    @MainActor
    func testTabIdentifiersSurviveIndependentRelaunches() throws {
        let identifiers = [
            "tab.home",
            "tab.browse",
            "tab.projects",
            "tab.settings"
        ]
        let first = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )

        for identifier in identifiers {
            _ = try requireExistence(
                element(in: first, identifier: identifier)
            )
        }
        first.terminate()

        let second = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )
        try activate(element(in: second, identifier: "tab.browse"))

        XCTAssertTrue(
            element(in: second, identifier: "screen.browse")
                .waitForExistence(timeout: 5)
        )
    }
    #endif

    @MainActor
    func testNavigationGuideCanBeOpened() throws {
        let app = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )

        try activate(
            element(
                in: app,
                identifier: "action.openNavigationGuide"
            )
        )

        XCTAssertTrue(
            element(in: app, identifier: "screen.navigationGuide")
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testBrowseOptionsCanBePresentedAndDismissed() throws {
        let app = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )

        try activate(element(in: app, identifier: "tab.browse"))
        try activate(
            element(in: app, identifier: "action.openBrowseOptions")
        )

        let browseOptions = try requireExistence(
            element(in: app, identifier: "screen.browseOptions")
        )

        try activate(
            element(in: app, identifier: "action.dismissBrowseOptions")
        )

        XCTAssertTrue(browseOptions.waitForNonExistence(timeout: 5))
    }

    #if os(macOS)
    @MainActor
    func testSettingsWindowCanBeOpened() throws {
        let app = try launch(
            root: "main",
            expectedRootIdentifier: "screen.home"
        )

        try activate(element(in: app, identifier: "tab.settings"))
        try activate(
            element(in: app, identifier: "action.openSettingsWindow")
        )

        XCTAssertTrue(
            element(in: app, identifier: "screen.appSettings")
                .waitForExistence(timeout: 5)
        )
    }
    #endif

    @MainActor
    private func launch(
        root: String,
        expectedRootIdentifier: String
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        #if os(macOS)
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "--ui-testing", "--ui-test-root", root
        ]
        #else
        app.launchArguments = ["--ui-testing", "--ui-test-root", root]
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        #endif

        let expectedRoot = element(
            in: app,
            identifier: expectedRootIdentifier
        )
        #if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 1) {
            let menuBar = try requireExistence(app.menuBars.firstMatch)
            let fileMenuBarItem = try requireExistence(
                menuBar.menuBarItems.element(boundBy: 2)
            )
            if !app.windows.firstMatch.exists {
                fileMenuBarItem.click()

                let fileMenu = try requireExistence(
                    fileMenuBarItem.menus.firstMatch
                )
                let newWindowActions = fileMenu.menuItems.matching(
                    identifier: "menuAction:"
                )
                let newWindowAction = try requireSingleElement(
                    newWindowActions,
                    description: "File-menu window action"
                )
                let actionToInvoke = try XCTUnwrap(
                    app.windows.firstMatch.exists ? nil : newWindowAction,
                    "Initial window appeared while resolving the "
                        + "File-menu bootstrap action"
                )
                actionToInvoke.click()
            }
        }
        #endif

        _ = try requireExistence(expectedRoot)
        #if os(macOS)
        _ = try requireSingleElement(
            app.windows,
            description: "initial application window"
        )
        #endif
        return app
    }

    @MainActor
    private func element(
        in app: XCUIApplication,
        identifier: String
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func requireExistence(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        try XCTUnwrap(
            element.waitForExistence(timeout: timeout) ? element : nil,
            "Expected UI element to exist",
            file: file,
            line: line
        )
    }

    @MainActor
    private func requireSingleElement(
        _ query: XCUIElementQuery,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> XCUIElement {
        let count = query.count
        return try XCTUnwrap(
            count == 1 ? query.firstMatch : nil,
            "Expected exactly one \(description), found \(count)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func activate(_ element: XCUIElement) throws {
        let element = try requireExistence(element)
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }
}
```

This removes the ineffective Command-N fallback. The replacement is a
deterministic fixture bootstrap, not a retry. It first gives the normal scene a
bounded one-second readiness opportunity. Only if the application still has no
window does it target the standard menu bar's structural File position (Apple,
application, then File). It rechecks before opening the menu and again directly
before invoking the sole scoped `menuAction:`. If a window is observed at that
second snapshot while the menu is open, it fails fast without invoking the
action; teardown owns the open menu and process. This is an explicit future-SDK
compatibility tripwire, not a retry or a flaky green path. The final exact-one
check catches the residual non-atomic gap between snapshot and click. It does
not query localized menu titles. After the
caller-specified root appears, the fixture requires exactly one application
window, so a shifted menu structure, ambiguous action, or residual
duplicate-window race fails explicitly. Every soft existence assertion that
previously allowed a dependent interaction to continue is also removed.

- [ ] **Step 3: Run the five macOS UI regressions twice**

```bash
set -euo pipefail

repeat_root="$(mktemp -d /tmp/AppTemplate-UIWindowFixture-Green.XXXXXX)"
test -d "$repeat_root"
test ! -L "$repeat_root"
case "$repeat_root" in
  /tmp/AppTemplate-UIWindowFixture-Green.*) ;;
  *) exit 1 ;;
esac

for round in 1 2; do
  result_bundle="$repeat_root/round-$round.xcresult"
  test ! -e "$result_bundle"
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$repeat_root/DerivedData" \
    -resultBundlePath "$result_bundle" \
    -only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseOptionsCanBePresentedAndDismissed \
    -only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseTabShowsBrowseScreen \
    -only-testing:AppTemplateUITests/AppTemplateUITests/testNavigationGuideCanBeOpened \
    -only-testing:AppTemplateUITests/AppTemplateUITests/testOnboardingRootIsVisible \
    -only-testing:AppTemplateUITests/AppTemplateUITests/testSettingsWindowCanBeOpened \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
  test -d "$result_bundle"
done
```

Expected: both rounds exit zero and each result bundle contains the five passing tests. Every launch also proves that the initial-window query contains exactly one element after root readiness.

- [ ] **Step 4: Run the full macOS and iPhone/iPad UI gates**

```bash
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/AppTemplate-UIWindowFixture-full-macOS \
  -only-testing:AppTemplateUITests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' \
  -derivedDataPath /tmp/AppTemplate-UIWindowFixture-iPhone \
  -only-testing:AppTemplateUITests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -derivedDataPath /tmp/AppTemplate-UIWindowFixture-iPad \
  -only-testing:AppTemplateUITests \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
```

Expected: all three UI-test targets exit zero. Network Task 7 later runs the complete macOS scheme, including `AppTemplateTests`, as the final combined gate.

- [ ] **Step 5: Run static scope checks**

```bash
git diff --check
git diff --name-only HEAD -- \
  AppTemplate/App/Entry \
  AppTemplateTests/App/Entry \
  AppTemplateUITests \
  docs/superpowers/plans/2026-08-09-macos-ui-test-window-isolation.md \
  docs/superpowers/specs/2026-08-09-macos-ui-test-window-isolation-design.md \
  | sort
```

Expected after Task 1 has already been committed: the implementation diff is limited to this file, while the execution-correction documentation is limited to the active plan and design:

```text
AppTemplateUITests/AppTemplateUITests.swift
docs/superpowers/plans/2026-08-09-macos-ui-test-window-isolation.md
docs/superpowers/specs/2026-08-09-macos-ui-test-window-isolation-design.md
```

- [ ] **Step 6: Commit the isolated fail-fast fixture**

```bash
git add AppTemplateUITests/AppTemplateUITests.swift \
  docs/superpowers/plans/2026-08-09-macos-ui-test-window-isolation.md \
  docs/superpowers/specs/2026-08-09-macos-ui-test-window-isolation-design.md
git commit -m "fix: isolate macOS UI test window state"
```

---

## Self-Review

- Parser coverage: all four roots pass through the exact macOS six-element form; six malformed persistence forms remain `.live`; existing four-element tests remain intact on every platform.
- Product scope: no application scene, production restoration, entitlement, preference, accessibility, or AppKit bridge changes.
- Fixture coverage: macOS passes the persistence-isolation arguments; a zero-window launch uses the locale-independent standard-menu hierarchy and requires one scoped `menuAction:`; exactly one initial window, initial roots, and every dependent element are required before later steps; Command-N recovery is removed.
- Platform coverage: the five formerly failing macOS tests pass twice, and the macOS, iPhone 17, and iPad (A16) UI targets pass with warnings as errors.
- Combined order: Network Tasks 1–6 precede this plan, and Network Task 7 follows it with the final complete macOS scheme and cross-platform unit gates.
