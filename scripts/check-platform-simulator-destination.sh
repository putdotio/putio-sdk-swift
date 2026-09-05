#!/usr/bin/env bash
# Exercises scripts/platform-simulator-destination.sh against captured simctl
# listings so the parser is covered without depending on installed runtimes.
set -euo pipefail

cd "$(dirname "$0")/.."
script="./scripts/platform-simulator-destination.sh"
fixtures="scripts/fixtures/simctl"
failures=0

expect_output() {
  local fixture="$1" platform="$2" expected="$3"
  local actual
  if actual="$(PUTIO_SIMCTL_DEVICE_LIST="${fixtures}/${fixture}" "${script}" "${platform}" 2>/dev/null)" \
    && [ "${actual}" = "${expected}" ]; then
    echo "ok   ${fixture} ${platform} -> ${actual}"
  else
    echo "FAIL ${fixture} ${platform}: expected '${expected}', got '${actual:-<none>}'"
    failures=$((failures + 1))
  fi
}

expect_exit() {
  local fixture="$1" platform="$2" expected_status="$3"
  local status=0
  PUTIO_SIMCTL_DEVICE_LIST="${fixtures}/${fixture}" "${script}" "${platform}" >/dev/null 2>&1 || status=$?
  if [ "${status}" -eq "${expected_status}" ]; then
    echo "ok   ${fixture} ${platform} -> exit ${status}"
  else
    echo "FAIL ${fixture} ${platform}: expected exit ${expected_status}, got ${status}"
    failures=$((failures + 1))
  fi
}

# First tvOS device wins even when a renamed device follows.
expect_output mixed-runtimes.txt tvOS "id=047FE19B-EEF9-4497-B6E4-53760D7C176C"
# Lowercase UDIDs are accepted, booted state is irrelevant, and the iOS device
# named after a watch is never selected.
expect_output mixed-runtimes.txt watchOS "id=682e79f2-3a18-4072-822b-5f8a3ac46c23"
expect_output no-watch-runtime.txt tvOS "id=0E4E6DAD-33E6-46CA-ABAD-DFC1FEE3F9B0"
expect_exit no-watch-runtime.txt watchOS 69
expect_exit empty.txt tvOS 69
expect_exit mixed-runtimes.txt iOS 64

if [ "${failures}" -ne 0 ]; then
  echo "${failures} destination parser check(s) failed" >&2
  exit 1
fi
