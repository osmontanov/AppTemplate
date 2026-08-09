# macOS UI-Test Window Isolation Design

**Date:** 2026-08-09

**Status:** Approved; execution correction validated on 2026-08-09

## Context

The recorded pre-fix full macOS scheme passed 233 tests and failed these five UI tests:

- `testBrowseOptionsCanBePresentedAndDismissed`;
- `testBrowseTabShowsBrowseScreen`;
- `testNavigationGuideCanBeOpened`;
- `testOnboardingRootIsVisible`;
- `testSettingsWindowCanBeOpened`.

All five failures have one fixture-level symptom. During
`XCUIApplication.launch()`, the launched process remains alive, but its
accessibility hierarchy contains no content `Window` and therefore none of the
expected screen, tab, or action identifiers.

The evidence distinguishes this from a product-navigation, selector, timing, or
Networking regression:

- the recorded baseline logs `hasPersistentStateToRestore=1` and creates no
  content window;
- a clean control launch logs `hasPersistentStateToRestore=0` and immediately
  creates the expected Onboarding window;
- the existing Command-N recovery is delivered to the correct process but does
  not recover a window in the UI-test bootstrap;
- the product's accessibility identifiers and `WindowGroup` remain valid.

Execution of the first approved fix refined the diagnosis. With
`-ApplePersistenceIgnoreState YES`, every AUT logs
`hasPersistentStateToRestore=0`, proving that the old state is excluded, but
XCTest still observes no content window. Temporary probes using
`.defaultLaunchBehavior(.presented)`, `.restorationBehavior(.disabled)`, and a
single-instance `Window` produce the same zero-content-window result. The
missing boundary is therefore default scene instantiation under this macOS
XCUI launch, not argument parsing, root selection, activation, or persisted
state alone.

A targeted accessibility invocation of the application's standard new-window
command creates the expected SwiftUI window. A focused XCUITest probe proved a
locale-independent query: menu-bar element 2 is File in the standard macOS
ordering (Apple, application, File), and its opened menu contains exactly one
`menuAction:` in this application. Invoking that scoped action makes
`screen.onboarding` reachable. SwiftUI does not propagate a custom Button
accessibility identifier to the underlying `NSMenuItem`, so a test-only custom
command cannot improve the selector without adding another title or index.

`AppLaunchConfiguration.uiTesting` already makes application navigation state
ephemeral, but that policy does not control AppKit's restoration of the window
set. The fix therefore belongs at the macOS UI-test launch boundary.

## Goals

- Make every macOS UI-test launch independent of persisted AppKit window state.
- Ensure a macOS UI-test launch has exactly one reachable initial content
  window when AppKit/SwiftUI does not create one automatically.
- Preserve normal application window restoration and launch behavior.
- Keep the existing strict UI-test argument contract and reject unknown extras.
- Stop a UI test at the first missing fixture root or actionable element.
- Make the five existing failures pass without localized-label selectors or
  product accessibility-identifier changes.
- Preserve existing iOS and iPadOS UI-test behavior.

## Non-goals

- Changing production `WindowGroup`, Settings-window, or restoration behavior.
- Adding an AppKit application delegate or imperative production window opener.
- Clearing preferences, Saved Application State, containers, or user data.
- Increasing the existing five-second UI-test bounds, changing accessibility
  identifiers, or adding a general interaction retry.
- Changing Networking production code or the Networking hardening design.

## Chosen approach

macOS UI tests launch the application with AppKit persistence disabled for that
process only:

```text
-ApplePersistenceIgnoreState YES
```

The complete macOS UI-test argument sequence is:

```text
-ApplePersistenceIgnoreState YES --ui-testing --ui-test-root <root>
```

This prevents AppKit from consuming the persisted zero-window fixture while
leaving ordinary application launches untouched. Because the current macOS
XCUI launch still does not instantiate the default SwiftUI scene, the fixture
gives the application's actual window query one bounded second to become ready.
If no window exists, it resolves the structurally identified File menu slot,
rechecks the window query before opening that menu, and rechecks once more
directly before invoking its sole scoped `menuAction:`. If a window is observed
at that second snapshot while the menu is open, the fixture fails fast without
invoking the action; test teardown owns the open menu and process. The final
exact-one check catches the residual non-atomic gap between that snapshot and
the click. This deliberately exposes a future SDK behavior change instead of
allowing a duplicate or flaky green.
After the expected root is ready, the
fixture requires exactly one application window, turning a shifted menu layout,
ambiguous standard action, or residual duplicate-window race into an explicit
fixture failure.

`-ApplePersistenceIgnoreState YES` and the conditional menu command are a
UI-test bootstrap contract, not a production recovery mechanism. A future
macOS or SDK behavior change is detected by the two consecutive focused UI-test
rounds and the full-scheme gate. There is no application delegate, AppKit
bridge, or production fallback that imperatively creates a window.

Three alternatives are rejected:

1. Forcing a window from product code would add AppKit or scene-opening behavior
   to the application solely for tests. It risks duplicate windows, focus races,
   and conflicts with Settings or normal restoration.
2. Deleting persisted state from the test harness would mutate external data,
   depend on sandbox and bundle paths, conflict with parallel execution, and
   risk deleting a real user's window layout.
3. SwiftUI scene launch/restoration modifiers and a single-instance `Window`
   were tested in isolated builds and did not create a content window under the
   same XCUI launch. They would also expand production-scene scope without
   solving the fixture failure.

## Argument contract

`AppLaunchConfiguration.init(arguments:)` continues to treat the executable as
element zero and accepts only explicit complete forms.

On macOS it accepts either:

```swift
[
    executable,
    "--ui-testing", "--ui-test-root", root
]
```

or the persistence-isolated form used by `AppTemplateUITests`:

```swift
[
    executable,
    "-ApplePersistenceIgnoreState", "YES",
    "--ui-testing", "--ui-test-root", root
]
```

On iOS and iPadOS only the existing four-element form is accepted. In every
form, `root` must map to `UITestRoot`.

The parser does not generally strip Apple-style arguments. It recognizes only
the exact `-ApplePersistenceIgnoreState`, `YES` pair in the exact position above.
Wrong values, missing values, reordered or duplicated pairs, unknown roots, and
any additional arguments resolve to `.live`, preserving the current strict
fallback behavior.

## UI-test bootstrap and interaction flow

`AppTemplateUITests.launch(root:expectedRootIdentifier:)` becomes a throwing
helper. Call sites provide the expected accessibility identifier explicitly;
the helper never derives a selector from the fixture name. Existing calls use
`screen.home` for `main` and `screen.onboarding` for `onboarding`.

1. It builds the existing UI-test arguments.
2. On macOS only, it prefixes the persistence-isolation pair.
3. It launches the app and retains the existing macOS activation step.
4. It resolves the caller-provided expected initial accessibility root.
5. On macOS only, it waits at most one second for an initial application window.
6. If none appears, it requires menu-bar element 2 and rechecks the window query.
7. If the window is still absent, it opens that menu and requires exactly one
   scoped `menuAction:`. It rechecks immediately before invocation. If a window
   appeared, it throws without invoking the action; otherwise it invokes the
   action. No localized title participates in the query.
8. It requires the expected root within the existing five-second bound.
9. On macOS, it requires exactly one application window before returning.
   Any failure throws out of the test immediately.

The ineffective Command-N recovery is removed. The targeted menu command is not
an interaction retry: it is a one-time macOS fixture bootstrap after a bounded
normal-readiness opportunity and is gated by the absence of every application
window. If a window exists but the expected root does not, the helper does not
open another window and fails normally.

Both launch readiness and interaction readiness use one exact throwing helper:

```swift
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
```

The conditional expression is required: `waitForExistence` returns a nonoptional
`Bool`, and `XCTUnwrap(false)` would not assert truth. `activate(_:)` calls
`requireExistence` before `click()` on macOS or `tap()` elsewhere. Test methods
become throwing and call `launch` and `activate` with `try`, so a missing
prerequisite produces one focused failure and no secondary interaction error.

Queries that must be unambiguous use a second throwing helper. It snapshots the
query count and unwraps `firstMatch` only when that count is exactly one. The
helper guards both the scoped File-menu `menuAction:` and the final macOS window
query; it never silently chooses among multiple elements.

The root precondition and throwing interaction helper intentionally apply to all
UI-test platforms. This changes only failure reporting and short-circuiting;
iOS and iPadOS launch arguments, successful interactions, and product behavior
remain unchanged.

Every element whose presence is a prerequisite for a later interaction or test
step is obtained with `try requireExistence(...)` or the stricter
`try requireSingleElement(...)`, as appropriate. `activate(_:)` provides the
existence guarantee for ordinary clicked or tapped elements; the bootstrap
directly clicks only elements already proven unique to avoid reopening the
TOCTOU window with another wait. Tests also call the existence helper directly
when an element itself gates a later step: in particular,
`screen.browseOptions` must exist before the dismiss action is resolved and
activated, and every tab identifier in the iOS independent-relaunch loop must
exist before termination and relaunch continue. Assertions that are terminal
observations, with no later step depending on their result, may remain ordinary
`XCTAssertTrue` existence or nonexistence assertions.

No change is made to `AppTemplateApp`, `WindowGroup`, app dependencies,
navigation persistence, accessibility identifiers, or production scenes.

## Files and responsibilities

- `AppTemplate/App/Entry/AppLaunchConfiguration.swift`
  recognizes the one additional exact macOS argument form.
- `AppTemplateTests/App/Entry/AppLaunchConfigurationTests.swift`
  verifies positive and negative parsing without launching the app.
- `AppTemplateUITests/AppTemplateUITests.swift`
  owns macOS process isolation and fail-fast UI prerequisites.

No new production file, entitlement, preference domain, or AppKit bridge is
introduced.

## Test strategy

### Parser tests

Inside `#if os(macOS)`, the first RED test is parameterized over all four
`UITestRoot` values: `onboarding`, `authentication`, `main`, and `maintenance`.
For each value it passes the exact six-element process-argument array and
expects `.uiTesting(initialState: root.initialState)`. Every case fails under
the current `arguments.count == 4` parser, and the test is not compiled for iOS
or iPadOS.

The existing table proving all four roots map correctly remains unchanged. A
macOS-only negative table covers:

- `NO` instead of `YES`;
- a missing persistence value;
- the persistence pair after the UI-test options;
- a duplicated persistence pair;
- an unknown additional argument;
- an unknown root in the otherwise canonical six-element form.

Each negative case must remain `.live`. Existing iOS and iPadOS parsing remains
on the four-element contract.

### UI regression tests

The five existing macOS UI tests are the behavioral regression suite; no
localized-label or product selectors are introduced. The standard menu query is
structural and guarded: File is menu-bar element 2 in this app's standard menu
layout, and its opened menu must contain exactly one `menuAction:`. Run the same
five tests twice in sequence with separate result bundles. Both rounds must
pass, and every launch must satisfy the one-window postcondition.

After the focused rounds, the complete macOS UI target must pass. Run the UI-test
target on the configured iPhone 17 and iPad (A16) simulators to verify that the
conditional macOS launch arguments and throwing helpers do not change their
behavior. Network Task 7 runs the complete macOS scheme as the final combined
gate. All gates treat Swift and Clang warnings as errors.

The test suite does not delete or seed persisted application state. The process
argument excludes restored state for each AUT process. The suite makes no claim
that AppKit's shared saved-state container is free from writes; macOS UI-test
execution therefore remains subject to the scheme runner's existing process
coordination.

## Error handling

- Malformed process arguments retain the existing `.live` fallback.
- A missing caller-specified initial root throws from
  `launch(root:expectedRootIdentifier:)` and stops that test.
- If no macOS window exists after the one-second readiness bound, a missing
  standard menu-bar slot or menu throws before any later interaction. The
  window query is checked again before opening the menu and immediately before
  invoking its action.
- If the opened File menu has zero or multiple `menuAction:` elements, the
  fixture throws rather than guessing. The command is attempted at most once.
- If a window is observed at the final snapshot while the File menu is open,
  the fixture throws without invoking the action. XCTest teardown owns the menu
  and AUT process. The child
  `Menu` remains in the AX hierarchy while closed, and AppKit's selected state
  proved stale in isolated probes, so the fixture does not invent an unreliable
  close oracle.
- If the requested root appears with zero or multiple application windows, the
  fixture throws before returning.
- A missing interactive element throws from `activate(_:)`; no click or tap is
  attempted afterward.
- A missing prerequisite used by a later step, including the presented Browse
  Options root and each identifier in the iOS tab loop, throws before that later
  step runs.
- There is no general retry, keyboard shortcut, preference cleanup, or
  production window-opening fallback.

## Delivery order

1. Add the parser RED tests and the exact macOS parser branch.
2. Run the parser tests to GREEN.
3. Update the UI-test launch and interaction helpers.
4. Run the five macOS UI tests twice.
5. Run the complete macOS UI target and configured iPhone/iPad UI-test gates.
6. Commit the fixture correction independently from Networking production
   changes; Network Task 7 then runs the complete macOS scheme as the combined
   final gate.

## Success criteria

- The canonical macOS persistence-isolated arguments select the requested
  deterministic UI-test state for all four `UITestRoot` values.
- Malformed or additional arguments remain `.live`.
- macOS UI-test launches expose the requested root and exactly one initial
  application window; when launch produces no window, the fixture opens one
  through a locale-independent, structurally scoped standard-menu action.
- Missing elements stop their tests before interaction.
- The five formerly failing macOS UI tests pass twice consecutively.
- The full macOS scheme and configured iPhone/iPad UI-test gates pass with
  warnings treated as errors.
- Ordinary application launch and restoration behavior remain unchanged.
