#!/bin/sh

set -eu

version="${1:-}"

if [ -z "$version" ]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

printf '%s\n' "$version" > VERSION
