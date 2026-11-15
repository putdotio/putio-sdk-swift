#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
script="./scripts/platform-simulator-destination.swift"
fixtures="scripts/fixtures/simctl"
failures=0

run() {
  local fixture="$1"
  shift
  PUTIO_SIMCTL_DEVICES_JSON="${fixtures}/${fixture}" swift "${script}" "$@"
}

expect_output() {
  local fixture="$1" platform="$2" expected="$3"
  local actual
  if actual="$(run "${fixture}" "${platform}" 2>/dev/null)" && [ "${actual}" = "${expected}" ]; then
    echo "ok   ${fixture} ${platform} -> ${actual}"
  else
    echo "FAIL ${fixture} ${platform}: expected '${expected}', got '${actual:-<none>}'"
    failures=$((failures + 1))
  fi
}

expect_exit() {
  local fixture="$1" expected_status="$2"
  shift 2
  local status=0
  run "${fixture}" "$@" >/dev/null 2>&1 || status=$?
  if [ "${status}" -eq "${expected_status}" ]; then
    echo "ok   ${fixture} $* -> exit ${status}"
  else
    echo "FAIL ${fixture} $*: expected exit ${expected_status}, got ${status}"
    failures=$((failures + 1))
  fi
}

expect_output mixed-runtimes.json tvOS "id=2928C038-AC87-42A0-91FC-6C3A64B56BBB"
expect_output mixed-runtimes.json watchOS "id=682e79f2-3a18-4072-822b-5f8a3ac46c23"
expect_output no-watch-runtime.json tvOS "id=0E4E6DAD-33E6-46CA-ABAD-DFC1FEE3F9B0"
expect_exit no-watch-runtime.json 69 watchOS
expect_exit empty.json 69 tvOS
expect_exit malformed.json 65 tvOS
expect_exit mixed-runtimes.json 64 iOS
expect_exit mixed-runtimes.json 64

if [ "${failures}" -ne 0 ]; then
  echo "${failures} destination check(s) failed" >&2
  exit 1
fi
