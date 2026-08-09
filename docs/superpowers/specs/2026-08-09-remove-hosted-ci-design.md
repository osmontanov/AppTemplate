# Remove Hosted CI Automation Design

**Date:** 2026-08-09

**Status:** Approved

## Context

The repository has one active CI/CD artifact:

```text
.github/workflows/ci.yml
```

It defines a GitHub Actions test matrix for macOS, iPhone, and iPad plus a
macOS signed-entitlement job. The repository has no Fastlane, Xcode Cloud,
Jenkins, GitLab CI, CircleCI, Bitrise, Codemagic, Buildkite, deployment, or
release-upload configuration.

The user has chosen to remove hosted CI/CD rather than disable it. Local Xcode
build, test, signing, and entitlement verification remain part of the project.

## Goals

- Remove the active GitHub Actions workflow completely.
- Leave no active hosted CI/CD configuration in the repository.
- Keep all local macOS, iPhone, iPad, signing, and entitlement gates usable.
- Update current project documentation so it does not claim hosted CI exists.
- Update the active Networking hardening spec and plan so implementation no
  longer creates or verifies GitHub Actions jobs.

## Non-goals

- Replacing GitHub Actions with another hosted or local automation system.
- Removing local `xcodebuild`, `codesign`, `plutil`, or `jq` verification.
- Reverting the macOS outgoing-network entitlement or its local signed-product
  checks.
- Changing application, Networking, UI-test, Xcode target, or scheme behavior.
- Rewriting old completed design and implementation documents merely because
  they describe CI decisions that existed at the time.
- Adding deployment, packaging, notarization, or release-upload automation.

## Chosen scope

Delete:

- `.github/workflows/ci.yml`

Update current user-facing documentation:

- `README.md` — remove the claim that the template includes a
  three-destination CI matrix; describe platform verification as local.
- `docs/CUSTOMIZATION.md` — replace instructions that require updating CI or a
  CI runner with local build/test documentation and a clean verification
  machine.
- `docs/RELEASE_CHECKLIST.md` — replace “Confirm CI passes” with explicit local
  macOS, iPhone 17, and iPad (A16) test gates.

Update the active Networking documents:

- `docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md` — remove
  the GitHub Actions entitlement job and CI-matrix acceptance requirements;
  preserve the exact local Debug/Release signed-entitlement contract.
- `docs/superpowers/plans/2026-08-09-network-layer-hardening.md` — remove
  `.github/workflows/ci.yml` from the file map and Task 1, keep local effective-
  setting and signed-product gates, and make Task 7 end with local platform and
  full-scheme verification only.

Historical documents outside those two active Networking files remain
unchanged. They are records of earlier approved work, not executable automation.

## Resulting verification model

After removal, verification is explicitly local:

1. Networking tasks run focused macOS tests during RED/GREEN cycles.
2. Debug and Release macOS products are built locally and inspected for:
   - `com.apple.security.app-sandbox == true`;
   - `com.apple.security.network.client == true`;
   - absence of `com.apple.security.network.server`.
3. Effective settings locally prove the app alone has outgoing networking and
   neither test target gains client or server networking.
4. Final unit tests run locally for macOS, iPhone 17 / iOS 26.5, and
   iPad (A16) / iOS 26.5.
5. The complete macOS scheme runs locally with a zero exit status.

No check is configured to run automatically or on hosted infrastructure. The
project has no required-status or deployment automation.

## Deletion and documentation behavior

Deleting the only tracked file under `.github/workflows` removes the active
workflow from the repository. Git does not track empty directories, so no empty
placeholder is added.

The implementation does not rename the workflow, move it to another directory,
comment out triggers, add `workflow_dispatch`, or retain a disabled copy. Those
approaches would preserve automation configuration contrary to the request.

Current documentation is edited narrowly. Generic deployment-target language,
request/response “workflow” terminology, and historical CI references in old
`docs/superpowers` records are not automation and are not globally purged.

## Verification

The removal gate checks that the active artifact is absent:

```bash
test ! -e .github/workflows/ci.yml
if test -d .github/workflows; then
  ! rg --files .github/workflows | rg -q .
fi
```

An automation inventory checks explicitly for GitHub workflows, Fastlane,
Jenkins, CircleCI, GitLab CI, Xcode Cloud `ci_scripts`, Bitrise, Codemagic,
Buildkite, Travis CI, Azure Pipelines, and Drone configuration. None may remain
active.

A scoped text scan checks the current user-facing and active Networking files
for stale claims about a CI matrix, GitHub Actions, CI runners, or a CI
entitlement job. The scan intentionally excludes historical specs/plans.

Positive checks also confirm that the active Networking documents still name
all retained local gates: Debug and Release macOS signed products, `codesign`,
the sandbox/client/server entitlement contract, macOS/iPhone/iPad unit-test
destinations, and the complete macOS scheme gate.

The implementation commit is restricted to exactly six paths: the deleted
workflow plus `README.md`, `docs/CUSTOMIZATION.md`,
`docs/RELEASE_CHECKLIST.md`, and the two active Networking documents named
above. A changed-path allow-list must fail if application source, Xcode project
settings, schemes, tests, UI-test files, or historical documents are touched.

Because production code and Xcode build settings do not change in this removal,
the already completed local signed-product gate remains valid evidence. The
next Networking behavior task runs its own focused tests, and the final
Networking task repeats all local acceptance gates.

## Delivery

The removal is one independently reviewable commit containing the workflow
deletion and current-document updates. It precedes further Networking
implementation so later task reports and final acceptance evidence no longer
refer to hosted CI.

## Success criteria

- `.github/workflows/ci.yml` is absent.
- No other active CI/CD configuration exists in the repository.
- No replacement or disabled hosted automation is added.
- Current project documentation describes local verification accurately.
- The active Networking design and plan require only local gates.
- Local client-network entitlement and platform test requirements are
  preserved.
- Application and Xcode target behavior are unchanged by this removal.
