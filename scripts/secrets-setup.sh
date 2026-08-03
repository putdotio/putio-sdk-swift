#!/usr/bin/env bash

set -euo pipefail
umask 077

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ciphertext="${PUTIO_SDK_SWIFT_SOPS_FILE:?Set PUTIO_SDK_SWIFT_SOPS_FILE to the SDK ciphertext file}"
output=".env.local"

command -v sops >/dev/null 2>&1 || fail "sops is required"
command -v swift >/dev/null 2>&1 || fail "swift is required"

[ -f "$ciphertext" ] || fail "ciphertext input must be one regular file"
[ ! -L "$ciphertext" ] || fail "ciphertext input must not be a symlink"
git check-ignore -q -- "$output" || fail "output path is not gitignored: $output"
[ ! -L "$output" ] || fail "output path must not be a symlink: $output"
[ ! -e "$output" ] || [ -f "$output" ] || fail "output path must be a regular file: $output"

status="$(sops filestatus --input-type dotenv "$ciphertext" 2>/dev/null)" \
  || fail "SOPS 3.10 or newer could not inspect the dotenv ciphertext input"
printf '%s\n' "$status" | grep -Eq '"encrypted"[[:space:]]*:[[:space:]]*true' \
  || fail "ciphertext input is not encrypted"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/putio-sdk-swift-secrets.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

payload_json="$tmp_dir/payload.json"
rendered_env="$tmp_dir/rendered.env"
module_cache="$tmp_dir/swift-module-cache"
mkdir -p "$module_cache"
sops decrypt --output-type json --output "$payload_json" "$ciphertext" \
  || fail "could not decrypt ciphertext input"
chmod 600 "$payload_json"

SWIFT_MODULECACHE_PATH="$module_cache" CLANG_MODULE_CACHE_PATH="$module_cache" \
  swift ./scripts/secrets-render.swift "$payload_json" "$rendered_env" \
  || fail "decrypted payload failed validation or safe dotenv rendering"
install -m 600 "$rendered_env" "$output"
printf 'ok wrote %s\n' "$output"
