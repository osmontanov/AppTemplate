#!/bin/zsh

emulate -LR zsh
set -euo pipefail

[[ $# -eq 0 ]] || {
  print -u2 -- "usage: Scripts/verify-release.zsh"
  exit 64
}

repo_root="$(git rev-parse --show-toplevel)" || exit 64
[[ -n "$repo_root" && "$(pwd -P)" == "$repo_root" ]] || exit 64
if [[ -n "${XCRESULT_REQUIRED_TESTS_RUNNER+x}" ]]; then
  print -u2 -- "XCRESULT_REQUIRED_TESTS_RUNNER is reserved for verifier fixture tests."
  exit 64
fi
unset XCRESULT_REQUIRED_TESTS_RUNNER

release_account_uid="$(id -u)"
[[ "$release_account_uid" == <0-> ]] || exit 64
release_bundle_id="$(sed -n 's/^[[:space:]]*APP_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*//p' Config/Template.xcconfig)"
[[ -n "$release_bundle_id" && "$release_bundle_id" != *[^A-Za-z0-9.-]* ]] || exit 64
release_lock="/private/var/tmp/AppTemplate-release-gate.$release_account_uid.$release_bundle_id.lock"
[[ "$release_lock" == "/private/var/tmp/AppTemplate-release-gate.$release_account_uid.$release_bundle_id.lock" ]] || exit 64
[[ ! -L "$release_lock" ]] || exit 73
if [[ ! -e "$release_lock" ]]; then
  old_umask="$(umask)"
  umask 077
  : >> "$release_lock"
  umask "$old_umask"
fi
[[ -f "$release_lock" && ! -L "$release_lock" ]] || exit 73
exec {release_lock_fd}>> "$release_lock"
[[ -f "$release_lock" && ! -L "$release_lock" ]] || exit 73
if ! /usr/bin/lockf -s -t 0 "$release_lock_fd"; then
  print -u2 -- "Another release gate owns $release_lock"
  exit 73
fi

checksums="Scripts/release-manifest-checksums.tsv"
unit_required="Scripts/release-required-unit-tests.tsv"
ui_required="Scripts/release-required-ui-tests.tsv"

for required_file in \
  "$checksums" \
  "$unit_required" \
  "$ui_required" \
  Scripts/xcresult-required-tests-fixture-runner.swift \
  Scripts/verify-xcresult-required-tests.swift; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || exit 65
done

# Manifest hashes live only in $checksums; regenerate it with
# Scripts/update-release-manifest-checksums.zsh after editing a manifest.
[[ "$(sed -n '1p' "$checksums")" == $'sha256\tpath' ]] || exit 66
[[ "$(tail -c 1 "$checksums" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
checksum_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-release-checksum-rows.XXXXXX")"
tail -n +2 "$checksums" > "$checksum_rows"
awk -F '\t' 'NF != 2 || $1 !~ /^[0-9a-f]{64}$/ || $2 !~ /^Scripts\// { exit 1 }' "$checksum_rows" || exit 66
verified_manifests=0
while IFS=$'\t' read -r expected_hash manifest_path; do
  [[ -f "$manifest_path" && ! -L "$manifest_path" ]] || exit 65
  manifest_hash="$(shasum -a 256 "$manifest_path")"
  [[ "${manifest_hash%% *}" == "$expected_hash" ]] || exit 66
  verified_manifests=$((verified_manifests + 1))
done < "$checksum_rows"
[[ "$verified_manifests" -eq 2 ]] || exit 66
for covered in "$unit_required" "$ui_required"; do
  awk -F '\t' -v manifest="$covered" '$2 == manifest { found = 1 } END { exit found ? 0 : 1 }' \
    "$checksum_rows" || exit 66
done
rm -f -- "$checksum_rows"

required_header=$'platform\tidentifier'
for required_manifest in "$unit_required" "$ui_required"; do
  [[ "$(sed -n '1p' "$required_manifest")" == "$required_header" ]] || exit 66
  [[ "$(tail -c 1 "$required_manifest" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
  rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-required-rows.XXXXXX")"
  sorted_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-required-sorted.XXXXXX")"
  tail -n +2 "$required_manifest" > "$rows"
  LC_ALL=C sort -u "$rows" > "$sorted_rows"
  cmp "$rows" "$sorted_rows"
  [[ -s "$rows" ]] || exit 66
  awk -F '\t' 'NF != 2 || $1 == "" || $2 == "" { exit 1 }' "$rows" || exit 66
  awk -F '\t' '$1 != "all" && $1 != "macos" && $1 != "iphone" && $1 != "ipad" { exit 1 }' "$rows" || exit 66
  rm -f -- "$rows" "$sorted_rows"
done

# The gate must require the test that keeps this manifest honest.
LC_ALL=C grep -Fqx $'all\tProjectConfigurationTests/releaseGateFreezesRequiredManifestsThroughOneChecksumSource()' "$unit_required" || exit 66

result_root="$(mktemp -d "${TMPDIR:-/tmp}/AppTemplate-release-results.XXXXXX")"
[[ -d "$result_root" && ! -L "$result_root" ]] || exit 72
unit_derived_data="$result_root/DerivedData-unit"
mkdir "$unit_derived_data"
[[ -d "$unit_derived_data" && ! -L "$unit_derived_data" ]] || exit 72

account_name="$(id -un)"
[[ -n "$account_name" && "$account_name" != */* ]] || exit 72
account_record="$(dscl . -read "/Users/$account_name" NFSHomeDirectory)"
account_home="${account_record#NFSHomeDirectory: }"
[[ -n "$account_home" && "$account_home" == /Users/* && -d "$account_home" && ! -L "$account_home" ]] || exit 72
app_bundle_id="$release_bundle_id"
container_tmp="$account_home/Library/Containers/$app_bundle_id/Data/tmp"
containers_root="$account_home/Library/Containers"
app_container="$containers_root/$app_bundle_id"
container_data="$app_container/Data"
[[ -d "$containers_root" && ! -L "$containers_root" ]] || exit 72
[[ "$app_container" == "$containers_root/"* && ! -L "$app_container" ]] || exit 72
if [[ ! -e "$app_container" ]]; then
  mkdir "$app_container"
fi
[[ -d "$app_container" && ! -L "$app_container" ]] || exit 72
[[ "$container_data" == "$app_container/Data" && ! -L "$container_data" ]] || exit 72
if [[ ! -e "$container_data" ]]; then
  mkdir "$container_data"
fi
[[ -d "$container_data" && ! -L "$container_data" ]] || exit 72
[[ "$container_tmp" == "$container_data/tmp" && ! -L "$container_tmp" ]] || exit 72
if [[ ! -e "$container_tmp" ]]; then
  mkdir "$container_tmp"
fi
[[ -d "$container_tmp" && ! -L "$container_tmp" ]] || exit 72
# The hosted suite resolves these binaries itself, and neither an environment
# variable nor INFOPLIST_KEY_ survives the test-host launch, so both sides have
# to agree on one path: this fixed name inside the app container's temporary
# directory, which is what FileManager.temporaryDirectory maps to in the sandbox.
# The lock above keeps the fixed name single-writer.
helper_run_root="$container_tmp/AppTemplate-XCResultRequiredTestsVerifier"
[[ ! -L "$helper_run_root" ]] || exit 72
if [[ -e "$helper_run_root" ]]; then
  # A run that died before its cleanup leaves this tree read-only, so restore
  # write permission before removing it or the next run cannot start.
  chmod -R u+rwX "$helper_run_root"
  rm -rf -- "$helper_run_root"
fi
mkdir "$helper_run_root"
[[ -d "$helper_run_root" && ! -L "$helper_run_root" ]] || exit 72
[[ "${helper_run_root:t}" == AppTemplate-XCResultRequiredTestsVerifier ]] || exit 72
verifier_executable="$helper_run_root/verifier"
fixture_runner_executable="$helper_run_root/fixture-runner"
[[ ! -L "$verifier_executable" && ! -L "$fixture_runner_executable" ]] || exit 72
swiftc Scripts/verify-xcresult-required-tests.swift -o "$verifier_executable"
swiftc Scripts/xcresult-required-tests-fixture-runner.swift -o "$fixture_runner_executable"
for executable_name in verifier fixture-runner; do
  helper_executable="$helper_run_root/$executable_name"
  [[ -f "$helper_executable" && ! -L "$helper_executable" && -x "$helper_executable" ]] || exit 72
  /usr/bin/codesign --force --sign - --timestamp=none "$helper_executable"
  /usr/bin/codesign --verify --strict "$helper_executable"
  chmod 500 "$helper_executable"
done
chmod 500 "$helper_run_root"
[[ -f "$verifier_executable" && ! -L "$verifier_executable" && -x "$verifier_executable" ]] || exit 72
[[ -f "$fixture_runner_executable" && ! -L "$fixture_runner_executable" && -x "$fixture_runner_executable" ]] || exit 72

XCRESULT_VERIFIER_TEST_EXECUTABLE="$verifier_executable" \
XCRESULT_FIXTURE_RUNNER_TEST_EXECUTABLE="$fixture_runner_executable" xcodebuild test \
  -project AppTemplate.xcodeproj -scheme AppTemplate \
  -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO \
  -only-testing:AppTemplateTests \
  -derivedDataPath "$unit_derived_data" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  -resultBundlePath "$result_root/unit.xcresult"
env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift \
  --result "$result_root/unit.xcresult" \
  --required "$unit_required" \
  --platform macos --reject-any-skips

destinations=(
  'platform=macOS,arch=arm64'
  'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
)
platforms=(macos iphone ipad)
skipped_macos_ui=0
for index in {1..3}; do
  destination="${destinations[$index]}"
  platform_name="${platforms[$index]}"
  ui_derived_data="$result_root/DerivedData-ui-$platform_name"
  build_derived_data="$result_root/DerivedData-build-$platform_name"
  mkdir "$ui_derived_data" "$build_derived_data"
  [[ -d "$ui_derived_data" && ! -L "$ui_derived_data" ]] || exit 72
  [[ -d "$build_derived_data" && ! -L "$build_derived_data" ]] || exit 72
  ui_log="$result_root/ui-$platform_name.log"
  if xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -parallel-testing-enabled NO \
    -only-testing:AppTemplateUITests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -derivedDataPath "$ui_derived_data" \
    -resultBundlePath "$result_root/ui-$platform_name.xcresult" 2>&1 | tee "$ui_log"; then
    ui_tests_ran=1
  else
    ui_tests_ran=0
  fi

  if (( ! ui_tests_ran )); then
    # Driving the macOS UI needs a machine-level automation grant that a fresh
    # checkout has no way to give itself. Tolerate exactly that condition — any
    # other failure is a real one and still stops the gate — and say out loud
    # which coverage the run is missing.
    if [[ "$platform_name" == macos ]] \
      && grep -q "Timed out while enabling automation mode" "$ui_log"; then
      skipped_macos_ui=1
      print -u2 -- "warning: macOS UI tests skipped — this machine has not granted UI automation to the test runner, so their coverage is missing from this run."
      xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
        -destination "$destination" -derivedDataPath "$build_derived_data" \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
      continue
    fi
    exit 74
  fi

  env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift \
    --result "$result_root/ui-$platform_name.xcresult" \
    --required "$ui_required" \
    --platform "$platform_name" --reject-any-skips
  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -derivedDataPath "$build_derived_data" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
done

[[ -d "$helper_run_root" && ! -L "$helper_run_root" ]] || exit 72
[[ "${helper_run_root:t}" == AppTemplate-XCResultRequiredTestsVerifier ]] || exit 72
[[ -f "$verifier_executable" && ! -L "$verifier_executable" ]] || exit 72
[[ -f "$fixture_runner_executable" && ! -L "$fixture_runner_executable" ]] || exit 72
chmod 700 "$helper_run_root" "$verifier_executable" "$fixture_runner_executable"
rm -- "$verifier_executable" "$fixture_runner_executable"
rmdir "$helper_run_root"

if (( skipped_macos_ui )); then
  print -- "Release gate passed WITHOUT macOS UI coverage. Results: $result_root"
else
  print -- "Release gate passed. Results: $result_root"
fi
