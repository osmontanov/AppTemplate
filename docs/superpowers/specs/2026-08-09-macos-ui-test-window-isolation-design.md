# macOS UI-Test Window Isolation Design

**Date:** 2026-08-09

**Status:** Proposed

## Context

The full macOS scheme currently passes 233 tests and fails these five UI tests:

- `testBrowseOptionsCanBePresentedAndDismissed`;
- `testBrowseTabShowsBrowseScreen`;
- `testNavigationGuideCanBeOpened`;
- `testOnboardingRootIsVisible`;
- `testSettingsWindowCanBeOpened`.

All five failures have one fixture-level cause. During `XCUIApplication.launch()`,
AppKit restores persisted state representing zero content windows. The launched
process remains alive, but its accessibility hierarchy contains no `Window` and
therefore none of the expected screen, tab, or action identifiers.

The evidence distinguishes this from a product-navigation, selector, timing, or
Networking regression:

- each failing process logs `hasPersistentStateToRestore=1` and creates no
  content window;
- a clean control launch logs `hasPersistentStateToRestore=0` and immediately
  creates the expected Onboarding window;
- the existing Command-N recovery is delivered to the correct process but does
  not recover a window in the UI-test bootstrap;
- the product's accessibility identifiers and `WindowGroup` remain valid.

`AppLaunchConfiguration.uiTesting` already makes application navigation state
ephemeral, but that policy does not control AppKit's restoration of the window
set. The fix therefore belongs at the macOS UI-test launch boundary.

## Goals

- Make every macOS UI-test launch independent of persisted AppKit window state.
- Preserve normal application window restoration and launch behavior.
- Keep the existing strict UI-test argument contract and reject unknown extras.
- Stop a UI test at the first missing fixture root or actionable element.
- Make the five existing failures pass without longer waits or selector changes.
- Preserve existing iOS and iPadOS UI-test behavior.

## Non-goals

- Changing production `WindowGroup`, Settings-window, or restoration behavior.
- Adding an AppKit application delegate or imperative production window opener.
- Clearing preferences, Saved Application State, containers, or user data.
- Increasing UI-test timeouts, changing accessibility identifiers, or retrying
  failed interactions.
- Changing Networking production code or the Networking hardening design.

## Chosen approach

macOS UI tests will launch the application with AppKit persistence disabled for
that process only:

```text
-ApplePersistenceIgnoreState YES
```

The complete macOS UI-test argument sequence is:

```text
-ApplePersistenceIgnoreState YES --ui-testing --ui-test-root <root>
```

This is the smallest change at the boundary that owns the failure. It prevents
AppKit from consuming the persisted zero-window fixture while leaving ordinary
application launches untouched.

Two alternatives are rejected:

1. Forcing a window from product code would add AppKit or scene-opening behavior
   to the application solely for tests. It risks duplicate windows, focus races,
   and conflicts with Settings or normal restoration.
2. Deleting persisted state from the test harness would mutate external data,
   depend on sandbox and bundle paths, conflict with parallel execution, and
   risk deleting a real user's window layout.

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
5. It requires that root within the existing five-second bound. Failure throws
   out of the test immediately.

The ineffective Command-N recovery is removed. A launch without its expected
root is a fixture failure, not a recoverable navigation state.

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

The root precondition and throwing interaction helper intentionally apply to all
UI-test platforms. This changes only failure reporting and short-circuiting;
iOS and iPadOS launch arguments, successful interactions, and product behavior
remain unchanged.

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

Inside `#if os(macOS)`, the first RED test passes the exact six-element process-
argument array and expects
`.uiTesting(initialState: UITestRoot.main.initialState)`. It fails under the
current `arguments.count == 4` parser and is not compiled for iOS or iPadOS.

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

The five existing macOS UI tests are the behavioral regression suite; no new
selectors or longer waits are introduced. Run the same five tests twice in
sequence with separate result bundles. Both rounds must pass, demonstrating
that the fixture result does not depend on the prior window state.

After the focused rounds, the entire macOS scheme must pass. Run the UI-test
target on the configured iPhone 17 and iPad (A16) simulators to verify that the
conditional macOS launch arguments and throwing helpers do not change their
behavior. All gates treat Swift and Clang warnings as errors.

The test suite does not delete or seed persisted application state. The process
argument is the isolation mechanism under test, and avoiding state mutation
keeps the suite safe for parallel execution.

## Error handling

- Malformed process arguments retain the existing `.live` fallback.
- A missing caller-specified initial root throws from
  `launch(root:expectedRootIdentifier:)` and stops that test.
- A missing interactive element throws from `activate(_:)`; no click or tap is
  attempted afterward.
- There is no retry, keyboard shortcut, preference cleanup, or production
  window-opening fallback.

## Delivery order

1. Add the parser RED tests and the exact macOS parser branch.
2. Run the parser tests to GREEN.
3. Update the UI-test launch and interaction helpers.
4. Run the five macOS UI tests twice.
5. Run the complete macOS scheme and configured iPhone/iPad UI-test gates.
6. Commit the fixture correction independently from Networking production
   changes.

## Success criteria

- The canonical macOS persistence-isolated arguments select the requested
  deterministic UI-test state.
- Malformed or additional arguments remain `.live`.
- macOS UI-test launches expose the requested root without Command-N recovery.
- Missing elements stop their tests before interaction.
- The five formerly failing macOS UI tests pass twice consecutively.
- The full macOS scheme and configured iPhone/iPad UI-test gates pass with
  warnings treated as errors.
- Ordinary application launch and restoration behavior remain unchanged.
