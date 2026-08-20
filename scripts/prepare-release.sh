#!/bin/sh

set -eu

version="${1:-}"

if [ -z "$version" ]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

printf '%s\n' "$version" > VERSION

# Regenerate the example lockfile so the released version is committed with
# VERSION; otherwise the next `pod install` dirties the tree on every machine.
bundle exec pod install --project-directory=Example
