# iPad UI Gate Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the pre-existing iPad Browse-tab UI-test interaction without changing production behavior, then rerun the complete Keychain Task 7 evidence matrix from fresh roots.

**Architecture:** Keep the app untouched. Centralize Browse-tab activation inside the UI-test target: tap once, wait on the semantic destination screen, retry the same freshly resolved tab exactly once only when that postcondition is absent, and require the destination before querying Browse-only controls.

**Tech Stack:** Swift 6.3, XCTest/XCUIAutomation, Xcode 26.6, iPadOS/iOS Simulator 26.5, macOS 26, Bash/Zsh, `xcresulttool`, `jq`.

## Normative Evidence and Constraints

- Work only in `/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database` on `codex/userdefaults-service`.
- Treat `docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md` at commit `fa0f80b8510cbb82f4ba36e172a0f90cfc9b1f88` as normative.
- The accepted RED is `/tmp/AppTemplate-Keychain-final.EQBmBF/ui-iPadA16.xcresult`: 4/5 passed; `testBrowseOptionsCanBePresentedAndDismissed()` failed because `tab.home` and `screen.home` remained selected/present after a synthesized tap inside the Browse bounds.
- The Keychain change set did not modify the UI test, router, tabs, navigation, or Browse screen. This round is a separately authorized test-stability fix, not a Keychain production change.
- Authorized tracked paths are exactly `AppTemplateUITests/AppTemplateUITests.swift`, the normative design, this plan, and `docs/superpowers/plans/2026-08-12-keychain-service.md` for the matching scope authorization.
- Do not edit production Swift, the Xcode project, entitlements, privacy metadata, signing, Keychain code/tests, or ordinary unit tests.
- The helper may make at most two activations. It waits on `screen.browse`; it must not use `sleep`, unbounded polling, unconditional retries, force taps, coordinate taps, or suppress the final failure.
- The retained failure is the TDD RED. Because it is timing-dependent, a temporary no-fallback characterization is evidence only and cannot replace or invalidate the retained RED.
- Every accepted test/build uses a fresh validated `/tmp` root and warnings-as-errors. Do not retry a failed final gate in place.
- Local completion still requires all nine Keychain Task 7 gates and independent review. The separately signed-and-provisioned adopter runtime gate remains `NOT SATISFIED / RELEASE BLOCKER`.

---

### Task 1: Commit the Reviewed Scope Amendment

**Files:**

- Create: `docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md`
- Modify: `docs/superpowers/plans/2026-08-12-keychain-service.md`
- Preserve: `docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md`

- [ ] **Step 1: Verify the exact base and design commit**

```bash
set -euo pipefail
test "$(pwd -P)" = '/Users/aurora/Documents/AppTemplate/.worktrees/generic-local-database'
test "$(git branch --show-current)" = 'codex/userdefaults-service'
test "$(git rev-parse HEAD)" = fa0f80b8510cbb82f4ba36e172a0f90cfc9b1f88
test "$(git diff --name-only)" = docs/superpowers/plans/2026-08-12-keychain-service.md
test "$(git ls-files --others --exclude-standard)" = docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md
test "$(git show --format= --name-only fa0f80b8510cbb82f4ba36e172a0f90cfc9b1f88 | sed '/^$/d')" = docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md
```

- [ ] **Step 2: Verify the scope amendment is exact**

The Keychain plan's final changed-path `case` must admit exactly these three newly authorized paths in addition to its prior allowlist:

```text
docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md
docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md
AppTemplateUITests/AppTemplateUITests.swift
```

It must also record the retained Gate 7 RED and require a new final root. Do not broaden any wildcard to all specs, plans, or UI tests.

```bash
set -euo pipefail
plan='docs/superpowers/plans/2026-08-12-keychain-service.md'
rg -Fq 'docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md' "$plan"
rg -Fq 'docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md' "$plan"
rg -Fq 'AppTemplateUITests/AppTemplateUITests.swift' "$plan"
test "$(rg -F 'AppTemplateUITests/AppTemplateUITests.swift' "$plan" | wc -l | tr -d ' ')" = 3
test -z "$(rg 'AppTemplateUITests/\*|docs/superpowers/specs/\*|docs/superpowers/plans/\*' "$plan" || true)"
test "$(git diff --numstat fa0f80b8510cbb82f4ba36e172a0f90cfc9b1f88 -- "$plan")" = $'6\t1\tdocs/superpowers/plans/2026-08-12-keychain-service.md'
git diff --check
```

- [ ] **Step 3: Parse every shell fence under both supported shells**

Extract each fenced `bash` body from both plan documents into a fresh temporary directory, require at least one fence, and run `bash -n` and `zsh -n` over every extracted file. Do not execute gate bodies in this documentation task.

- [ ] **Step 4: Commit only the two plan files**

```bash
set -euo pipefail
git add \
  docs/superpowers/plans/2026-08-12-keychain-service.md \
  docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md
git diff --cached --check
test "$(git diff --cached --name-only | LC_ALL=C sort)" = "$(printf '%s\n' \
  docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md \
  docs/superpowers/plans/2026-08-12-keychain-service.md | LC_ALL=C sort)"
git commit -m 'docs: plan iPad UI gate stabilization'
test -z "$(git status --porcelain)"
```

---

### Task 2: Add Bounded Semantic Tab Activation

**Files:**

- Modify: `AppTemplateUITests/AppTemplateUITests.swift`
- Evidence: `.superpowers/sdd/2026-08-12-ipad-ui-gate-stabilization/task-2-report.md` (ignored)

- [ ] **Step 1: Revalidate the retained RED without rerunning it**

```bash
set -euo pipefail
red='/tmp/AppTemplate-Keychain-final.EQBmBF/ui-iPadA16.xcresult'
test -d "$red"
test "$(shasum -a 256 AppTemplateUITests/AppTemplateUITests.swift | awk '{print $1}')" = 7664b764cdb14e599084bd788508f04da450fc24c9dae58756166f770a3d687a
xcrun xcresulttool get test-results summary --path "$red" --compact \
| jq -e '.result == "Failed" and .totalTestCount == 5 and .passedTests == 4 and .failedTests == 1 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get test-results tests --path "$red" --compact \
| jq -e '
  def descendants: recurse(.children[]?);
  [.testNodes[] | descendants
    | select(.nodeType == "Test Case" and .result == "Failed") | .name]
  == ["testBrowseOptionsCanBePresentedAndDismissed()"]
'
```

The executable equality assertion above proves the immutable pre-fix UI-test SHA-256 is `7664b764cdb14e599084bd788508f04da450fc24c9dae58756166f770a3d687a` before editing.

- [ ] **Step 2: Add the minimum helper and route all Browse transitions through it**

Add this helper next to `activate(_:)`:

```swift
@MainActor
private func activateTab(
    in app: XCUIApplication,
    identifier: String,
    destinationIdentifier: String
) throws {
    try activate(element(in: app, identifier: identifier))

    let destination = element(
        in: app,
        identifier: destinationIdentifier
    )
    if !destination.waitForExistence(timeout: 2) {
        try activate(element(in: app, identifier: identifier))
    }

    _ = try requireExistence(
        element(in: app, identifier: destinationIdentifier)
    )
}
```

Replace each direct Browse-tab activation in these three tests with the helper: `testBrowseTabShowsBrowseScreen`, `testTabIdentifiersSurviveIndependentRelaunches`, and `testBrowseOptionsCanBePresentedAndDismissed`. Use `second` in the relaunch test. Remove the two now-redundant standalone `screen.browse.waitForExistence` assertions. The Browse-only action must occur only after `activateTab` returns.

- [ ] **Step 3: Run the exact failed test on a fresh iPad root**

```bash
set -euo pipefail
green_root="$(mktemp -d /tmp/AppTemplate-iPadUIFix-Focused.XXXXXX)"
test -d "$green_root"; test ! -L "$green_root"
case "$green_root" in /tmp/AppTemplate-iPadUIFix-Focused.*) ;; *) exit 1 ;; esac
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  '-only-testing:AppTemplateUITests/AppTemplateUITests/testBrowseOptionsCanBePresentedAndDismissed' \
  -derivedDataPath "$green_root/DerivedData" \
  -resultBundlePath "$green_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$green_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount == 1 and .passedTests == 1 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$green_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

- [ ] **Step 4: Characterize the no-fallback mutation, then restore**

Temporarily replace only the conditional fallback with `_ = destination.waitForExistence(timeout: 2)`. Run the exact focused command three times, each with a fresh root. Retain every bundle and record whether any run reproduces the missed activation. This is timing characterization only: all-green mutation runs do not invalidate the retained RED and are not a blocker. Restore the bounded branch byte-for-byte.

- [ ] **Step 5: Require repeated focused GREEN and the full iPad UI suite**

Run the exact focused command three times after restoration, each under a fresh root; all three must pass 1/1 with strict build zeroes. Then run:

```bash
set -euo pipefail
suite_root="$(mktemp -d /tmp/AppTemplate-iPadUIFix-Suite.XXXXXX)"
test -d "$suite_root"; test ! -L "$suite_root"
case "$suite_root" in /tmp/AppTemplate-iPadUIFix-Suite.*) ;; *) exit 1 ;; esac
xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
  -configuration Debug \
  -destination 'platform=iOS Simulator,OS=26.5,name=iPad (A16)' \
  -only-testing:AppTemplateUITests \
  -derivedDataPath "$suite_root/DerivedData" \
  -resultBundlePath "$suite_root/Tests.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
xcrun xcresulttool get test-results summary --path "$suite_root/Tests.xcresult" --compact \
| jq -e '.result == "Passed" and .totalTestCount == 5 and .passedTests == 5 and .failedTests == 0 and .skippedTests == 0 and .expectedFailures == 0'
xcrun xcresulttool get build-results --path "$suite_root/Tests.xcresult" --compact \
| jq -e '(.status | ascii_downcase) == "succeeded" and (.errorCount // 0) == 0 and (.warningCount // 0) == 0 and (.analyzerWarningCount // 0) == 0'
```

- [ ] **Step 6: Enforce scope and commit**

```bash
set -euo pipefail
test "$(git diff --name-only)" = AppTemplateUITests/AppTemplateUITests.swift
# Skip Swift comments and string literals, then reject line-start loop statements
# and the prohibited call expressions. This must not treat diagnostic prose as code.
source_oracle='(?xs)""".*?"""(*SKIP)(*F)|"(?:\\.|[^"\\])*"(*SKIP)(*F)|//[^\r\n]*(*SKIP)(*F)|/\*.*?\*/(*SKIP)(*F)|^[\t ]*(?:while|repeat)\b|\b(?:sleep|usleep|forceTap|coordinate)[\t ]*\('
test -z "$(rg -U -P "$source_oracle" AppTemplateUITests/AppTemplateUITests.swift || true)"
test "$(rg -F 'private func activateTab(' AppTemplateUITests/AppTemplateUITests.swift | wc -l | tr -d ' ')" = 1
test "$(rg -F 'try activateTab(' AppTemplateUITests/AppTemplateUITests.swift | wc -l | tr -d ' ')" = 3
test "$(rg -U -P 'try activateTab\(\s*in: (app|second),\s*identifier: "tab\\.browse",\s*destinationIdentifier: "screen\\.browse"\s*\)' AppTemplateUITests/AppTemplateUITests.swift | wc -l | tr -d ' ')" = 3
test "$(rg -F 'if !destination.waitForExistence(timeout: 2) {' AppTemplateUITests/AppTemplateUITests.swift | wc -l | tr -d ' ')" = 1
test "$(rg -U -P 'try requireExistence\(\s*element\(\s*in: app,\s*identifier: destinationIdentifier\s*\)\s*\)' AppTemplateUITests/AppTemplateUITests.swift | wc -l | tr -d ' ')" = 1
test -z "$(rg -U -P 'try activate\(\s*element\(\s*in: (app|second),\s*identifier: "tab\\.browse"\s*\)\s*\)' AppTemplateUITests/AppTemplateUITests.swift || true)"
git diff --check
git add AppTemplateUITests/AppTemplateUITests.swift
git diff --cached --check
git commit -m 'test: stabilize iPad tab activation'
test -z "$(git status --porcelain)"
```

---

### Task 3: Rerun the Complete Keychain Final Verification

**Files:**

- Verify only.
- Replace ignored evidence: `.superpowers/sdd/2026-08-12-keychain-service/final-verification-report.md`

- [ ] **Step 1: Execute the exact Task 7 contract from the amended Keychain plan**

Read `docs/superpowers/plans/2026-08-12-keychain-service.md` completely and execute Task 7 Steps 1–7 verbatim:

1. New compiler-negative proof with the exact `FirstSecret` to `SecondSecret` diagnostic.
2. New macOS UI-authorization preflight passing 1/1.
3. One new `/tmp/AppTemplate-Keychain-final.XXXXXX` root; do not reuse the old failed or focused-fix artifacts.
4. All nine gates in order, with no retry: focused macOS, all macOS units, iPhone units, iPad units, complete macOS scheme, iPhone UI, iPad UI, Release macOS, unsigned generic Release iOS.
5. Strict test/build zeroes, focused suite presence, and mobile required-case evidence.
6. Actual Gate 8 app inspection and entitlement/gate-scope JSON.
7. Task 6 Step 3 static/hash/scope guards against the final committed tree.
8. Independent whole-branch review using the Keychain spec, both UI stabilization documents, the full diff from `fb683478a36736f5f062ab036bd956cb2faecd17`, all new artifacts, compiler proof, entitlement JSON, and guard output.

If any gate fails, retain the root, stop without retry, and write a truthful BLOCKED report. Never substitute an artifact from the old matrix.

- [ ] **Step 2: Record the final evidence truthfully**

The ignored final report must include exact final HEAD/clean status; compiler and UI-auth roots; nine gate rows and counts; suite/case evidence; Gate 8 JSON and compile/link limitation; final guards; review verdict; and historical context for the old Gate 7 failure plus both bounded-fix commits. It must contain exactly `Mandatory signed-and-provisioned adopter gate: NOT SATISFIED / RELEASE BLOCKER` unless that external procedure was genuinely completed.

- [ ] **Step 3: Final clean and scope audit**

First rerun the full reject-unexpected-path guard from Keychain Task 6 Step 3 exactly; this is the authoritative absence-of-extras proof. Then retain this independent required-path audit:

```bash
set -euo pipefail
test -z "$(git status --porcelain)"
git diff --check
git diff fb683478a36736f5f062ab036bd956cb2faecd17 --name-only \
| LC_ALL=C sort -u > /tmp/AppTemplate-iPadUIFix-final-paths.txt
for required in \
  AppTemplateUITests/AppTemplateUITests.swift \
  docs/superpowers/specs/2026-08-12-ipad-ui-gate-stabilization-design.md \
  docs/superpowers/plans/2026-08-12-ipad-ui-gate-stabilization.md \
  docs/superpowers/plans/2026-08-12-keychain-service.md; do
  rg -Fqx "$required" /tmp/AppTemplate-iPadUIFix-final-paths.txt
done
for immutable in AppTemplate AppTemplateTests AppTemplate.xcodeproj; do
  test -z "$(git diff --name-only 06755b1ae87f877b23cbde0199e72e8163cd869f -- "$immutable")"
done
```

## Completion Conditions

- The only runtime-affecting change is in the UI-test target; production source and project configuration remain byte-identical to `06755b1ae87f877b23cbde0199e72e8163cd869f`.
- Browse-only interaction is preceded by the required `screen.browse` postcondition and at most one conditional retry.
- Three restored focused runs and the complete iPad UI suite pass before the test commit.
- The complete Keychain Task 7 matrix runs under entirely new roots and all nine local gates pass with strict zeroes.
- Independent review reports no P0–P2 finding.
- The worktree is clean, changed paths are authorized, and the mandatory signed-and-provisioned adopter runtime gate remains explicitly blocked until separately executed.
