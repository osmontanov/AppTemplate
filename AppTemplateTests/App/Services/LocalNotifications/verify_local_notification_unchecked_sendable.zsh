#!/bin/zsh

set -eu

if (( $# != 1 )); then
    print -u2 -- "usage: $0 <repository-root>"
    exit 64
fi

repository_root="$1"
production_root="$repository_root/AppTemplate/App/Services/LocalNotifications"
bridge_path="$production_root/Internal/NotificationCenterDelegateBridge.swift"

if [[ ! -d "$production_root" || ! -f "$bridge_path" ]]; then
    print -u2 -- "local notification production sources were not found"
    exit 66
fi

matches="$(rg -n --glob '*.swift' '@unchecked Sendable' "$production_root" || true)"
count="$(print -r -- "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ "$count" != 1 ]]; then
    print -u2 -- "expected exactly one local-notification production unchecked conformance; found $count"
    print -u2 -- "$matches"
    exit 1
fi

if [[ "$matches" != "$bridge_path:"* ]] || \
   ! rg -q 'final class NotificationCenterDelegateBridge:' "$bridge_path"; then
    print -u2 -- "the sole unchecked conformance must belong to NotificationCenterDelegateBridge"
    print -u2 -- "$matches"
    exit 1
fi

print -r -- "$matches"
