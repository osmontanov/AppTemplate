# Remove Hosted CI Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every active hosted CI/CD configuration while preserving the project's local macOS, iPhone, iPad, signing, and entitlement verification contracts.

**Architecture:** Delete the repository's only active automation artifact instead of disabling or relocating it. Update only current user-facing guidance and the active Networking hardening documents; historical records, application sources, Xcode settings, schemes, and tests remain unchanged.

**Tech Stack:** GitHub Actions removal, Markdown documentation, shell verification with Git and ripgrep; no replacement automation provider.

## Global Constraints

- Delete `.github/workflows/ci.yml`; do not rename it, retain a disabled copy, or add another trigger or provider.
- Do not add hosted or local replacement automation.
- Preserve local `xcodebuild`, `codesign`, `plutil`, and `jq` checks.
- Preserve the macOS Debug/Release sandbox-client entitlement contract and the absence of server networking.
- Preserve local unit-test destinations for macOS, iPhone 17 / iOS 26.5, and iPad (A16) / iOS 26.5.
- Preserve the zero-exit complete macOS scheme gate after the approved UI-test isolation work.
- Do not change application source, Xcode project settings, schemes, unit tests, UI tests, or historical specifications and plans.
- The implementation commit may touch exactly six paths: the deleted workflow and the five current documents listed below.

---

## File Map

### Delete

- `.github/workflows/ci.yml` — the only active hosted CI/CD configuration.

### Modify

- `README.md` — replace the CI-matrix product claim with local three-platform verification guidance.
- `docs/CUSTOMIZATION.md` — replace CI-specific rename and clean-runner guidance with local commands and a clean verification machine.
- `docs/RELEASE_CHECKLIST.md` — replace the CI-pass item with explicit local macOS, iPhone, and iPad gates.
- `docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md` — remove hosted-job requirements while retaining the local signed-product and platform acceptance contract.
- `docs/superpowers/plans/2026-08-09-network-layer-hardening.md` — remove GitHub Actions from the implementation scope and make Task 1 and Task 7 local-only.

---

### Task 1: Remove Hosted Automation and Preserve Local Gates

**Files:**

- Delete: `.github/workflows/ci.yml`
- Modify: `README.md:3-7`
- Modify: `docs/CUSTOMIZATION.md:31-40,110-114`
- Modify: `docs/RELEASE_CHECKLIST.md:33-40`
- Modify: `docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md:54-120,296-365`
- Modify: `docs/superpowers/plans/2026-08-09-network-layer-hardening.md:9,36-265,1513-1532`

**Interfaces:**

- Consumes: the tracked GitHub Actions workflow and current documentation claims about hosted verification.
- Produces: a repository with no active CI/CD provider configuration and an entirely local verification contract.

- [ ] **Step 1: Capture the RED automation inventory and stale claims**

Run:

```bash
set -euo pipefail

test -f .github/workflows/ci.yml

provider_files="$({
  git ls-files -co --exclude-standard \
    | while IFS= read -r path; do
        if test -e "$path"; then
          printf '%s\n' "$path"
        fi
      done \
    | rg -i '(^|/)(\.github/workflows/.*|\.circleci/.*|fastlane/.*|ci_scripts/.*|\.buildkite/.*|\.gitlab/ci/.*|\.travis\.ya?ml|azure-pipelines\.ya?ml|\.drone\.ya?ml|bitrise\.ya?ml|codemagic\.ya?ml|\.gitlab-ci\.ya?ml|Jenkinsfile)$'
} || true)"
test "$provider_files" = '.github/workflows/ci.yml'

rg -n -i \
  '(^|[^[:alnum:]_])CI([^[:alnum:]_]|$)|GitHub Actions|macos-entitlements|RUNNER_TEMP|\.github/workflows' \
  README.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md \
  docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md \
  docs/superpowers/plans/2026-08-09-network-layer-hardening.md
```

Expected: the provider inventory contains exactly `.github/workflows/ci.yml`, and the scoped text scan reports the hosted-CI claims that this task removes. This is the RED configuration evidence.

- [ ] **Step 2: Delete the workflow and update current user-facing guidance**

Delete `.github/workflows/ci.yml` completely. Do not leave `.github/workflows` placeholder content.

In `README.md`, replace the CI clause in the opening paragraph so it reads:

```markdown
It provides typed, scene-local navigation; persisted demo app policy; explicit
dependency injection; deep links; previews; unit tests; UI tests; and documented
local verification for macOS, iPhone, and iPad. Authentication, local storage,
remote access, and feature data are intentionally non-production examples.
```

In `docs/CUSTOMIZATION.md`, replace the rename sentence with:

```markdown
them, use Xcode's rename operation, update matching paths/references and local
build/test commands, and run all destinations before deleting the old names.
```

Replace the Release-signing instruction with:

```markdown
4. Configure Release signing and archive the Release configuration on a clean
   verification machine.
```

In `docs/RELEASE_CHECKLIST.md`, replace the CI item with:

```markdown
- [ ] Run the unit-test gates locally on macOS, iPhone 17 / iOS 26.5, and
  iPad (A16) / iOS 26.5 with warnings treated as errors.
```

Keep the adjacent general complete-unit-and-UI-suite item and the existing exact signed-entitlement checklist item.

- [ ] **Step 3: Convert the active Networking design to local-only verification**

In `docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md`, replace the hosted entitlement paragraph, shell block, and following ad-hoc-signing paragraph with this complete local contract:

````markdown
Local verification uses Xcode 26.6 and this executable contract. It checks
effective settings for the app and both test targets before creating separate,
signed Debug and Release products:

```bash
set -euo pipefail

entitlement_root="$(mktemp -d /tmp/AppTemplate-entitlements.XXXXXX)"
test -d "$entitlement_root"
test ! -L "$entitlement_root"
case "$entitlement_root" in
  /tmp/AppTemplate-entitlements.*) ;;
  *) exit 1 ;;
esac

assert_effective_settings() {
  local configuration="$1"
  local app_settings
  local test_settings

  app_settings="$(xcodebuild -project AppTemplate.xcodeproj -target AppTemplate \
    -configuration "$configuration" -sdk macosx -showBuildSettings)"
  printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_APP_SANDBOX = YES$'
  printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES$'
  if printf '%s\n' "$app_settings" \
    | rg -q '^[[:space:]]*ENABLE_INCOMING_NETWORK_CONNECTIONS = YES$'; then
    return 1
  fi

  for target in AppTemplateTests AppTemplateUITests; do
    test_settings="$(xcodebuild -project AppTemplate.xcodeproj -target "$target" \
      -configuration "$configuration" -sdk macosx -showBuildSettings)"
    if printf '%s\n' "$test_settings" \
      | rg -q '^[[:space:]]*ENABLE_(OUTGOING|INCOMING)_NETWORK_CONNECTIONS = YES$'; then
      return 1
    fi
  done
}

for configuration in Debug Release; do
  assert_effective_settings "$configuration"

  derived_data="$entitlement_root/DerivedData-$configuration"
  xcodebuild build \
    -project AppTemplate.xcodeproj \
    -scheme AppTemplate \
    -configuration "$configuration" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES

  app="$derived_data/Build/Products/$configuration/AppTemplate.app"
  codesign --verify --deep --strict --verbose=2 "$app"
  codesign --display --entitlements - --xml "$app" 2>/dev/null \
    | plutil -convert json -o - - \
    | jq -e '."com.apple.security.app-sandbox" == true
        and ."com.apple.security.network.client" == true
        and (has("com.apple.security.network.server") | not)'
done
```

The command leaves its uniquely created root available for inspection. A
locally ad-hoc-signed Release product proves the embedded entitlements for this
change; it is not evidence of distribution signing, notarization, or Gatekeeper
acceptance.
````

In Delivery order, replace item 1 with:

```markdown
1. macOS entitlement and local signed-product assertions;
```

Replace the entire Verification section body with:

```markdown
Targeted Networking tests will run after every step. Required local acceptance
gates use separate Derived Data locations, select only `AppTemplateTests`, and
treat Swift and Clang warnings as errors for this platform set:

- macOS;
- iPhone 17 simulator with iOS 26.5;
- iPad (A16) simulator with iOS 26.5.

All three `xcodebuild test` commands must exit zero. Debug and Release macOS
builds plus the local effective-setting and embedded-entitlement assertions are
additional zero-exit gates.

After the separately approved macOS UI-test window-isolation plan is
implemented, the complete local macOS scheme is an additional zero-exit gate.
It runs unit and UI tests with warnings treated as errors; no former UI failure
is allowlisted or reclassified as diagnostic.
```

Replace the final Success criteria bullet with:

```markdown
- The three local unit-test gates, Debug/Release local entitlement gates, and
  complete local macOS scheme pass under warnings-as-errors, with no UI-test
  failure allow-list.
```

- [ ] **Step 4: Convert the active Networking plan to local-only execution**

In `docs/superpowers/plans/2026-08-09-network-layer-hardening.md`:

1. Remove `GitHub Actions` from Tech Stack.
2. Remove `.github/workflows/ci.yml` from File Map.
3. Rename Task 1 to `Enable macOS Client Networking and Verify It Locally`.
4. Remove the workflow from Task 1 Files, delete the entire hosted-job YAML from Step 2, and rename the step to `Add the application capability`.
5. Keep Task 1 Step 3's complete local effective-settings and signed-product script unchanged.
6. Rename Task 1 Step 5 to `Commit the entitlement and local gate`; stage only `AppTemplate.xcodeproj/project.pbxproj` and `docs/RELEASE_CHECKLIST.md` in its command.
7. Rename Task 7 Step 6 to `Confirm local verification scope and commit documentation`; remove its workflow inspection sentence while retaining the documentation commit.
8. Update Self-Review so entitlement and verification coverage name only local effective-setting, signed-product, three-platform unit, and complete macOS scheme gates.

No Networking behavior task, source path, test path, destination, entitlement predicate, or combined Network → UI → final-gate execution order changes.

- [ ] **Step 5: Run the GREEN removal, scope, and retention gates**

Run from the repository root:

```bash
set -euo pipefail

test ! -e .github/workflows/ci.yml
if test -d .github/workflows; then
  ! rg --files .github/workflows | rg -q .
fi

if git ls-files -co --exclude-standard \
| while IFS= read -r path; do
    if test -e "$path"; then
      printf '%s\n' "$path"
    fi
  done \
| rg -i '(^|/)(\.github/workflows/.*|\.circleci/.*|fastlane/.*|ci_scripts/.*|\.buildkite/.*|\.gitlab/ci/.*|\.travis\.ya?ml|azure-pipelines\.ya?ml|\.drone\.ya?ml|bitrise\.ya?ml|codemagic\.ya?ml|\.gitlab-ci\.ya?ml|Jenkinsfile)$'; then
  exit 1
fi

if rg -n -i \
  '(^|[^[:alnum:]_])CI([^[:alnum:]_]|$)|GitHub Actions|macos-entitlements|RUNNER_TEMP|\.github/workflows' \
  README.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md \
  docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md \
  docs/superpowers/plans/2026-08-09-network-layer-hardening.md; then
  exit 1
fi

network_spec=docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md
network_plan=docs/superpowers/plans/2026-08-09-network-layer-hardening.md

for document in "$network_spec" "$network_plan"; do
  rg -q 'Debug and Release' "$document"
  rg -q 'codesign --verify --deep --strict' "$document"
  rg -q 'com\.apple\.security\.app-sandbox' "$document"
  rg -q 'com\.apple\.security\.network\.client' "$document"
  rg -q 'com\.apple\.security\.network\.server' "$document"
  rg -q 'complete macOS scheme|full macOS scheme' "$document"
done
rg -q "destination 'platform=macOS'|destination 'generic/platform=macOS'" "$network_plan"
rg -q 'name=iPhone 17' "$network_plan"
rg -Fq 'name=iPad (A16)' "$network_plan"

expected_paths="$({
  printf '%s\n' \
    .github/workflows/ci.yml \
    README.md \
    docs/CUSTOMIZATION.md \
    docs/RELEASE_CHECKLIST.md \
    docs/superpowers/plans/2026-08-09-network-layer-hardening.md \
    docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md
} | LC_ALL=C sort)"
test -z "$(git ls-files --others --exclude-standard)"
actual_paths="$(git diff HEAD --name-only --diff-filter=ACDMRTUXB | LC_ALL=C sort)"
test "$actual_paths" = "$expected_paths"
git diff HEAD --name-status -- .github/workflows/ci.yml \
  | rg -q '^D[[:space:]]+\.github/workflows/ci\.yml$'

git diff HEAD --exit-code -- \
  AppTemplate.xcodeproj \
  AppTemplate \
  AppTemplateTests \
  AppTemplateUITests
git diff --check
```

Expected: the workflow and every other recognized provider file are absent; stale current-document claims are absent; all local platform, signed-product, entitlement, and full-scheme contracts remain present; exactly the six approved paths differ; source, project, scheme, and test paths are unchanged; formatting checks exit zero.

- [ ] **Step 6: Review and commit the removal**

Review the six-path diff, then commit it atomically:

```bash
git diff --stat
git diff -- \
  .github/workflows/ci.yml \
  README.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md \
  docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md \
  docs/superpowers/plans/2026-08-09-network-layer-hardening.md

git add \
  .github/workflows/ci.yml \
  README.md \
  docs/CUSTOMIZATION.md \
  docs/RELEASE_CHECKLIST.md \
  docs/superpowers/specs/2026-08-09-network-layer-hardening-design.md \
  docs/superpowers/plans/2026-08-09-network-layer-hardening.md
git commit -m "chore: remove hosted CI automation"
```

Expected: one independently reviewable commit deletes the workflow and updates exactly five current documents. Immediately after review approval, resume Network Layer Hardening at Task 2; Task 1's local entitlement implementation and evidence remain valid.

---

## Self-Review

- Spec coverage: deletion, no replacement automation, current-doc updates, historical-record preservation, local entitlement/platform/full-scheme retention, and six-path scope enforcement are all implemented by Task 1.
- Scope coverage: the changed-path allow-list and explicit clean diffs for project/source/test paths prevent unrelated behavior changes.
- Verification coverage: RED proves the one active provider and stale claims exist; GREEN proves provider absence and positively reasserts every retained local gate.
- Sequencing coverage: the removal commit precedes Networking Task 2 and explicitly preserves completed Task 1's project setting and local evidence.
- Placeholder scan: the plan contains no deferred implementation or unnamed test step.
