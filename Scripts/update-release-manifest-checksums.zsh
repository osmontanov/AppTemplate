#!/bin/zsh

emulate -LR zsh
set -euo pipefail

[[ $# -eq 0 ]] || {
  print -u2 -- "usage: Scripts/update-release-manifest-checksums.zsh"
  exit 64
}

repo_root="$(git rev-parse --show-toplevel)" || exit 64
[[ -n "$repo_root" && "$(pwd -P)" == "$repo_root" ]] || exit 64

checksums="Scripts/release-manifest-checksums.tsv"
manifests=(
  Scripts/release-required-unit-tests.tsv
  Scripts/release-required-ui-tests.tsv
)

staged="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-release-checksums.XXXXXX")"
printf 'sha256\tpath\n' > "$staged"
required_header=$'platform\tidentifier'
for manifest in "${manifests[@]}"; do
  [[ -f "$manifest" && ! -L "$manifest" ]] || exit 65
  # Refuse to bless a manifest the gate would reject anyway.
  [[ "$(sed -n '1p' "$manifest")" == "$required_header" ]] || exit 66
  [[ "$(tail -c 1 "$manifest" | od -An -t x1 | tr -d ' ')" == 0a ]] || exit 66
  rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-release-rows.XXXXXX")"
  sorted_rows="$(mktemp "${TMPDIR:-/tmp}/AppTemplate-release-rows-sorted.XXXXXX")"
  tail -n +2 "$manifest" > "$rows"
  LC_ALL=C sort -u "$rows" > "$sorted_rows"
  cmp "$rows" "$sorted_rows"
  [[ -s "$rows" ]] || exit 66
  awk -F '\t' 'NF != 2 || $1 == "" || $2 == "" { exit 1 }' "$rows" || exit 66
  rm -f -- "$rows" "$sorted_rows"
  manifest_hash="$(shasum -a 256 "$manifest")"
  printf '%s\t%s\n' "${manifest_hash%% *}" "$manifest" >> "$staged"
done
mv -- "$staged" "$checksums"

print -- "Updated $checksums"
