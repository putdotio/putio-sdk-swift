#!/bin/sh

set -eu

version="${1:-}"

if [ -z "$version" ]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

if [ -z "${COCOAPODS_TRUNK_TOKEN:-}" ]; then
  echo "COCOAPODS_TRUNK_TOKEN is not set; skipping CocoaPods publish for $version"
  exit 0
fi

# Returns 0 when the requested version is already registered on CocoaPods trunk.
version_on_trunk() {
  curl --silent --show-error --fail --max-time 30 --retry 3 --retry-delay 5 \
    "https://trunk.cocoapods.org/api/v1/pods/PutioSDK" \
    | ruby -rjson -e 'exit(JSON.parse($stdin.read).fetch("versions", []).any? { |v| v["name"] == ARGV[0] } ? 0 : 1)' "$version"
}

if bundle exec pod trunk push PutioSDK.podspec --allow-warnings; then
  exit 0
fi

# v3.2.1 failure mode: trunk registered the version, then its post-publish API
# call timed out and the CLI exited non-zero, aborting semantic-release before
# the GitHub release existed. Trust trunk state over the CLI exit code.
echo "pod trunk push exited non-zero; checking trunk for $version before failing" >&2

if version_on_trunk; then
  echo "PutioSDK $version is registered on trunk; treating the failure as a post-publish flake" >&2
  exit 0
fi

echo "PutioSDK $version is not registered on trunk; publish failed" >&2
exit 1
