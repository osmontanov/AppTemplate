# iPad UI Gate Stabilization Design

## Context

Keychain Task 7 Gate 7 failed on iPad (A16), iOS 26.5, in
`testBrowseOptionsCanBePresentedAndDismissed()`. XCTest synthesized a tap at
the center of the visible Browse tab, but the retained hierarchy still showed
`tab.home` selected and `screen.home`; `action.openBrowseOptions` never became
available. The same bundle passed `testBrowseTabShowsBrowseScreen()`, and the
complete iPhone UI and macOS scheme gates passed.

The Keychain change set does not modify navigation, views, the router, or UI
tests. `AppDependencies.uiTesting` only retains a fresh, unused
`InMemoryKeychainService`. The immutable-base and current UI-test files are
byte-identical. This is therefore a pre-existing, timing-dependent synthesized
input failure rather than a Keychain regression.

## Considered Approaches

1. **Repeat the failed gate unchanged.** Rejected because a green retry would
   provide no regression protection or explanation.
2. **Remove duplicate tab accessibility identifiers in production.** Rejected
   because the retained tap coordinate was correct and the evidence does not
   establish identifier duplication as the root cause. This would broaden the
   production UI surface unnecessarily.
3. **Bounded, postcondition-driven tab activation in the UI test.** Selected.
   The test activates the tab, waits for the destination screen, and only when
   that semantic postcondition is absent re-resolves and activates the same tab
   once more. It then requires the destination screen before interacting with
   Browse-only controls.

## Design

Add one private `activateTab` helper to `AppTemplateUITests`:

- Inputs: application, stable tab identifier, expected destination-screen
  identifier.
- Resolve the current tab element and require it to exist.
- Tap once.
- Poll the real destination condition with `waitForExistence`; do not sleep.
- If the destination is still absent, re-resolve the tab and tap exactly once
  more.
- Require the destination with the existing five-second failure boundary.
- Never retry more than once and never suppress the final assertion.

Use it for every test transition to `tab.browse`, including the simple Browse
screen test and the independent-relaunch case. This keeps one consistent
activation contract and prevents Browse-only actions from being queried before
navigation completes. Other tab paths remain unchanged.

No production file, Feature, router, dependency graph, accessibility installer,
entitlement, build setting, or Keychain source changes.

## Failure and Test Contract

The retained Gate 7 bundle is the accepted RED:

- `testBrowseOptionsCanBePresentedAndDismissed()` failed 1/5.
- The synthesized tap was inside the Browse bounds.
- The final hierarchy remained on Home for the full subsequent wait.

Focused GREEN must run the exact failed test on iPad (A16), iOS 26.5, with a
fresh derived-data/result root and strict warnings-as-errors. A mutation that
removes the second bounded activation must be checked against repeated focused
runs; the retained original failure remains the primary proof that the fallback
is meaningful. After restoration, run the complete iPad UI suite.

Finally, rerun all of Keychain Task 7 from a new root: compiler-negative proof,
macOS UI authorization, Gates 1–9, suite/case presence, Release artifact
inspection, all static/scope/hash guards, and independent review. No artifact
from the failed root may be substituted into the new matrix.

## Scope and Completion

Authorized tracked paths for this fix round:

- `AppTemplateUITests/AppTemplateUITests.swift`
- this design specification
- `docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md`
- `docs/superpowers/plans/2026-08-12-keychain-service.md` only to authorize the
  three new paths in the final changed-path guard and record this bounded round.

Local completion still does not satisfy the mandatory signed-and-provisioned
adopter runtime gate. That gate remains `NOT SATISFIED / RELEASE BLOCKER` until
the separate physical-device and signed-macOS procedure is performed.
