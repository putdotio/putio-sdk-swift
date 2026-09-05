#!/usr/bin/env bash
# Guards the #52 contract in PutioSDK/Classes/PutioSDK.swift: `request` stays
# caller-isolated and snapshots `config`/`delegate` on the caller's actor, while
# `perform` and `execute` are `@concurrent` and never read `self.` members or bare
# `config`/`delegate`. The library target compiles in Swift 5 mode, so the compiler
# would not catch an off-actor read. Fixtures under scripts/fixtures/transport-isolation
# keep the parser honest about comments, strings, and attribute layout.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

audit="python3 scripts/lib/check-transport-isolation.py"
failures=0

for fixture in scripts/fixtures/transport-isolation/pass/*.swift.txt; do
  if $audit "$fixture" >/dev/null; then
    echo "ok   fixture passes: ${fixture##*/}"
  else
    echo "FAIL fixture should pass: ${fixture##*/}"
    failures=$((failures + 1))
  fi
done

for fixture in scripts/fixtures/transport-isolation/fail/*.swift.txt; do
  if $audit "$fixture" >/dev/null; then
    echo "FAIL fixture should be rejected: ${fixture##*/}"
    failures=$((failures + 1))
  else
    echo "ok   fixture rejected: ${fixture##*/}"
  fi
done

if [ "${failures}" -ne 0 ]; then
  echo "${failures} transport isolation fixture check(s) failed" >&2
  exit 1
fi

$audit PutioSDK/Classes/PutioSDK.swift
