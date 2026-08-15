#!/bin/zsh

emulate -LR zsh
set -euo pipefail

[[ $# -eq 0 ]] || {
  print -u2 -- "usage: Scripts/verify-connected-mini-store-release.zsh"
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
release_lock="/private/var/tmp/AppTemplate-connected-mini-store-release.$release_account_uid.$release_bundle_id.lock"
[[ "$release_lock" == "/private/var/tmp/AppTemplate-connected-mini-store-release.$release_account_uid.$release_bundle_id.lock" ]] || exit 64
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
  print -u2 -- "Another connected mini-store release gate owns $release_lock"
  exit 73
fi

legacy_manifest="Scripts/connected-mini-store-legacy-paths.txt"
final_manifest="Scripts/connected-mini-store-final-change-paths.txt"
predelete_required="Scripts/connected-mini-store-required-unit-tests-predelete.tsv"
final_required="Scripts/connected-mini-store-required-unit-tests-final.tsv"
ui_required="Scripts/connected-mini-store-required-ui-tests.tsv"

for required_file in \
  "$legacy_manifest" \
  "$final_manifest" \
  "$predelete_required" \
  "$final_required" \
  "$ui_required" \
  Scripts/xcresult-required-tests-fixture-runner.swift \
  Scripts/verify-xcresult-required-tests.swift; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || exit 65
done

sorted_legacy="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-legacy-sorted.XXXXXX")"
sorted_final="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-final-sorted.XXXXXX")"
LC_ALL=C sort -u "$legacy_manifest" > "$sorted_legacy"
LC_ALL=C sort -u "$final_manifest" > "$sorted_final"
cmp "$legacy_manifest" "$sorted_legacy"
cmp "$final_manifest" "$sorted_final"
[[ "$(wc -l < "$legacy_manifest" | tr -d ' ')" == 152 ]] || exit 66
legacy_hash="$(shasum -a 256 "$legacy_manifest")"
[[ "${legacy_hash%% *}" == f93e89b71482728228705ff70678450b32fc3a179dee371de45a6857c933a9e8 ]] || exit 66
[[ "$(tail -c 1 "$final_manifest" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
[[ "$(wc -l < "$final_manifest" | tr -d ' ')" == 227 ]] || exit 66
final_manifest_hash="$(shasum -a 256 "$final_manifest")"
[[ "${final_manifest_hash%% *}" == ded52afd2152598f2b20bf7fba5b125758c760ed41bb2b31abd039a32d13b4a4 ]] || exit 66
missing_legacy="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-missing-legacy.XXXXXX")"
LC_ALL=C comm -23 "$legacy_manifest" "$final_manifest" > "$missing_legacy"
[[ ! -s "$missing_legacy" ]] || exit 66

required_header=$'platform\tidentifier'
predelete_required_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-predelete-required.XXXXXX")"
final_required_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-final-required.XXXXXX")"
[[ "$(sed -n '1p' "$predelete_required")" == "$required_header" ]] || exit 66
[[ "$(sed -n '1p' "$final_required")" == "$required_header" ]] || exit 66
[[ "$(tail -c 1 "$predelete_required" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
[[ "$(tail -c 1 "$final_required" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
tail -n +2 "$predelete_required" > "$predelete_required_rows"
tail -n +2 "$final_required" > "$final_required_rows"
predelete_required_sorted="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-predelete-required-sorted.XXXXXX")"
final_required_sorted="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-final-required-sorted.XXXXXX")"
LC_ALL=C sort -u "$predelete_required_rows" > "$predelete_required_sorted"
LC_ALL=C sort -u "$final_required_rows" > "$final_required_sorted"
cmp "$predelete_required_rows" "$predelete_required_sorted"
cmp "$final_required_rows" "$final_required_sorted"
[[ "$(wc -l < "$predelete_required_rows" | tr -d ' ')" == 33 ]] || exit 66
[[ "$(wc -l < "$final_required_rows" | tr -d ' ')" == 34 ]] || exit 66
awk -F '\t' 'NF != 2 || $1 == "" || $2 == "" { exit 1 }' "$predelete_required_rows" || exit 66
awk -F '\t' 'NF != 2 || $1 == "" || $2 == "" { exit 1 }' "$final_required_rows" || exit 66
predelete_required_hash="$(shasum -a 256 "$predelete_required")"
final_required_hash="$(shasum -a 256 "$final_required")"
[[ "${predelete_required_hash%% *}" == 24a58469b053431beff914adc227605d50c9d5227c57e0a175938699b38b306f ]] || exit 66
[[ "${final_required_hash%% *}" == 9c2ed088e0f39eac824c1a34e79f41013f7cdb0f5f617a938eb5ff076b483709 ]] || exit 66
ui_required_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-ui-required.XXXXXX")"
ui_required_sorted="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-ui-required-sorted.XXXXXX")"
[[ "$(sed -n '1p' "$ui_required")" == "$required_header" ]] || exit 66
[[ "$(tail -c 1 "$ui_required" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
tail -n +2 "$ui_required" > "$ui_required_rows"
LC_ALL=C sort -u "$ui_required_rows" > "$ui_required_sorted"
[[ "$(wc -l < "$ui_required_rows" | tr -d ' ')" == 11 ]] || exit 66
[[ "$(wc -l < "$ui_required_sorted" | tr -d ' ')" == 11 ]] || exit 66
awk -F '\t' 'NF != 2 || $1 == "" || $2 == "" { exit 1 }' "$ui_required_rows" || exit 66
ui_required_hash="$(shasum -a 256 "$ui_required")"
[[ "${ui_required_hash%% *}" == 263d944b6275632c909cfa48ea823907dcd8f08a74475c148717a5f87863d375 ]] || exit 66

if rg -n '^(AppTemplate\.xcodeproj/project\.pbxproj|AppTemplate/Resources/Localizable\.xcstrings|graphify-out(/|$))' "$final_manifest"; then
  exit 67
else
  protected_rg_code=$?
  [[ $protected_rg_code -eq 1 ]] || exit $protected_rg_code
fi

legacy_files=("${(@f)$(command cat -- "$legacy_manifest")}")
[[ ${#legacy_files[@]} -eq 152 ]] || exit 67
for target in "${legacy_files[@]}"; do
  [[ -n "$target" && ( "$target" == AppTemplate/* || "$target" == AppTemplateTests/* ) ]] || exit 67
  [[ ! -e "$target" && ! -L "$target" ]] || exit 67
done

for legacy_root in \
  AppTemplate/Features/Home \
  AppTemplate/Features/Browse \
  AppTemplate/Features/Projects \
  AppTemplate/Features/Settings \
  AppTemplateTests/Features/Home \
  AppTemplateTests/Features/Browse \
  AppTemplateTests/Features/Projects \
  AppTemplateTests/Features/Settings; do
  [[ ! -e "$legacy_root" && ! -L "$legacy_root" ]] || exit 68
done

if rg -n -g '*.swift' '(fetchExample|ExampleRequest|ExampleResponse|ExampleTarget)' AppTemplate AppTemplateTests AppTemplateUITests; then
  exit 69
else
  symbol_rg_code=$?
  [[ $symbol_rg_code -eq 1 ]] || exit $symbol_rg_code
fi

if rg -n '(Home|Browse|Projects|Settings|CreateProject|fetchExample|ExampleRequest|ExampleResponse|ExampleTarget)' \
  README.md docs/ARCHITECTURE.md docs/CUSTOMIZATION.md docs/RELEASE_CHECKLIST.md docs/README.md; then
  exit 70
else
  docs_rg_code=$?
  [[ $docs_rg_code -eq 1 ]] || exit $docs_rg_code
fi

predelete_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-predelete-rows.XXXXXX")"
final_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-final-rows.XXXXXX")"
LC_ALL=C tail -n +2 "$predelete_required" | LC_ALL=C sort -u > "$predelete_rows"
LC_ALL=C tail -n +2 "$final_required" | LC_ALL=C sort -u > "$final_rows"
missing_predelete="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-missing-predelete.XXXXXX")"
LC_ALL=C comm -23 "$predelete_rows" "$final_rows" > "$missing_predelete"
[[ ! -s "$missing_predelete" ]] || exit 71
[[ "$(wc -l < "$final_rows" | tr -d ' ')" -eq "$(( $(wc -l < "$predelete_rows" | tr -d ' ') + 1 ))" ]] || exit 71
rg -Fx $'all\tLegacySourceRemovalTests/everyAuditedLegacyPathIsAbsent()' "$final_required" >/dev/null

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
app_bundle_id="$(sed -n 's/^[[:space:]]*APP_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*//p' Config/Template.xcconfig)"
[[ -n "$app_bundle_id" && "$app_bundle_id" != *[^A-Za-z0-9.-]* ]] || exit 72
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
helper_run_root="$(mktemp -d "$container_tmp/AppTemplate-XCResultRequiredTestsVerifier.XXXXXX")"
helper_run_root="$(cd "$helper_run_root" && pwd -P)"
[[ -d "$helper_run_root" && ! -L "$helper_run_root" ]] || exit 72
[[ "$helper_run_root" == "$container_tmp/"AppTemplate-XCResultRequiredTestsVerifier.* ]] || exit 72
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
  INFOPLIST_KEY_XCResultVerifierRoot="$helper_run_root" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  -resultBundlePath "$result_root/unit-final.xcresult"
env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift \
  --result "$result_root/unit-final.xcresult" \
  --required "$final_required" \
  --platform macos --reject-any-skips

destinations=(
  'platform=macOS,arch=arm64'
  'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
  'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5'
)
platforms=(macos iphone ipad)
for index in {1..3}; do
  destination="${destinations[$index]}"
  platform_name="${platforms[$index]}"
  ui_derived_data="$result_root/DerivedData-ui-$platform_name"
  build_derived_data="$result_root/DerivedData-build-$platform_name"
  mkdir "$ui_derived_data" "$build_derived_data"
  [[ -d "$ui_derived_data" && ! -L "$ui_derived_data" ]] || exit 72
  [[ -d "$build_derived_data" && ! -L "$build_derived_data" ]] || exit 72
  xcodebuild test -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -parallel-testing-enabled NO \
    -only-testing:AppTemplateUITests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -derivedDataPath "$ui_derived_data" \
    -resultBundlePath "$result_root/ui-$platform_name.xcresult"
  env -u XCRESULT_REQUIRED_TESTS_RUNNER swift Scripts/verify-xcresult-required-tests.swift \
    --result "$result_root/ui-$platform_name.xcresult" \
    --required "$ui_required" \
    --platform "$platform_name" --reject-any-skips
  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate \
    -destination "$destination" -derivedDataPath "$build_derived_data" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
done

[[ -d "$helper_run_root" && ! -L "$helper_run_root" ]] || exit 72
[[ "$helper_run_root" == "$container_tmp/"AppTemplate-XCResultRequiredTestsVerifier.* ]] || exit 72
[[ -f "$verifier_executable" && ! -L "$verifier_executable" ]] || exit 72
[[ -f "$fixture_runner_executable" && ! -L "$fixture_runner_executable" ]] || exit 72
chmod 700 "$helper_run_root" "$verifier_executable" "$fixture_runner_executable"
rm -- "$verifier_executable" "$fixture_runner_executable"
rmdir "$helper_run_root"

print -- "Connected mini-store release gate passed. Results: $result_root"
