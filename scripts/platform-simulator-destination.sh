#!/usr/bin/env bash
# Prints an xcodebuild destination (id=<udid>) for the first available
# simulator under the requested platform's runtime section in
# `xcrun simctl list devices available`.
#
# Set PUTIO_SIMCTL_DEVICE_LIST to a file to parse a captured listing instead of
# querying simctl (used by scripts/check-platform-simulator-destination.sh).
set -euo pipefail

platform="${1:?usage: platform-simulator-destination.sh <tvOS|watchOS>}"
case "${platform}" in
  tvOS | watchOS) ;;
  *)
    echo "unsupported platform: ${platform}" >&2
    exit 64
    ;;
esac

list_devices() {
  if [ -n "${PUTIO_SIMCTL_DEVICE_LIST:-}" ]; then
    cat "${PUTIO_SIMCTL_DEVICE_LIST}"
  else
    xcrun simctl list devices available
  fi
}

# Runtime sections look like `-- watchOS 26.4 --`; device rows carry the UDID in
# parentheses. Only rows inside a matching section count, so an iOS device
# named after a watch (or a renamed verify device) can't be picked by mistake.
udid="$(
  list_devices | awk -v platform="${platform}" '
    /^-- .* --$/ {
      in_section = ($2 == platform)
      next
    }
    in_section && match($0, /\([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\)/) {
      print substr($0, RSTART + 1, RLENGTH - 2)
      exit
    }
  '
)"

if [ -z "${udid}" ]; then
  echo "no available ${platform} simulator; install the ${platform} runtime" >&2
  exit 69
fi

printf 'id=%s\n' "${udid}"
