#!/usr/bin/env bash
# Prints an xcodebuild destination (id=<udid>) for the first available
# simulator in the requested platform family.
set -euo pipefail

platform="${1:?usage: platform-simulator-destination.sh <tvOS|watchOS>}"
case "${platform}" in
  tvOS) family="Apple TV" ;;
  watchOS) family="Apple Watch" ;;
  *)
    echo "unsupported platform: ${platform}" >&2
    exit 64
    ;;
esac

udid="$(
  xcrun simctl list devices available \
    | grep -F "${family}" \
    | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
    | head -n 1
)"

if [ -z "${udid}" ]; then
  echo "no available ${family} simulator; install the ${platform} runtime" >&2
  exit 69
fi

printf 'id=%s\n' "${udid}"
