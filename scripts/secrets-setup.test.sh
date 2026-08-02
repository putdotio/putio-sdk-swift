#!/usr/bin/env bash

set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/putio-sdk-swift-secrets-test.XXXXXX")"
output=".env.local.sops-test.$$"
cleanup() {
  rm -rf "$tmp_dir"
  rm -f "$output"
}
trap cleanup EXIT

mkdir -p "$tmp_dir/bin"
fake_sops="$tmp_dir/bin/sops"
cat >"$fake_sops" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  filestatus)
    [ "${2:-}" = "--input-type" ]
    [ "${3:-}" = "dotenv" ]
    printf '{"encrypted":%s}\n' "${FAKE_SOPS_ENCRYPTED:-true}"
    ;;
  decrypt)
    output=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --output)
          shift
          output="$1"
          ;;
      esac
      shift
    done
    [ -n "$output" ]
    install -m 600 "$FAKE_SOPS_PAYLOAD" "$output"
    ;;
  *)
    exit 2
    ;;
esac
SH
chmod 700 "$fake_sops"

ciphertext="$tmp_dir/payload.sops.env"
payload="$tmp_dir/payload.json"
printf 'ciphertext fixture\n' >"$ciphertext"

write_payload() {
  printf '%s\n' "$1" >"$payload"
}

write_valid_payload() {
  write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"token with spaces = yes","PUTIO_TOKEN_THIRD_PARTY":"token with \"double\" quotes"}'
}

run_setup() {
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$ciphertext" \
  SECRETS_OUTPUT="$output" \
    bash ./scripts/secrets-setup.sh
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    printf 'FAILED: command unexpectedly succeeded\n' >&2
    exit 1
  fi
}

write_valid_payload
run_setup >/dev/null
if output_mode="$(stat -c '%a' "$output" 2>/dev/null)"; then
  :
else
  output_mode="$(stat -f '%Lp' "$output")"
fi
[ "$output_mode" = 600 ]
grep -Fx 'PUTIO_CLIENT_ID="123"' "$output" >/dev/null
grep -Fx 'PUTIO_TOKEN_FIRST_PARTY="token with spaces = yes"' "$output" >/dev/null
grep -Fx 'PUTIO_TOKEN_THIRD_PARTY='"'"'token with "double" quotes'"'"'' "$output" >/dev/null
rm -f "$output"

write_payload '{"PUTIO_TOKEN_FIRST_PARTY":"first","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"first","PUTIO_TOKEN_THIRD_PARTY":"third","UNEXPECTED":"value"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"not-numeric","PUTIO_TOKEN_FIRST_PARTY":"first","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"\"quoted\"","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"'"'"'quoted'"'"'","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"single'"'"' and \"double\"","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"line one\nline two","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"before\u0000after","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_payload '{"PUTIO_CLIENT_ID":"123","PUTIO_TOKEN_FIRST_PARTY":"before\tafter","PUTIO_TOKEN_THIRD_PARTY":"third"}'
expect_failure run_setup
[ ! -e "$output" ]

write_valid_payload
expect_failure env \
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_ENCRYPTED=false \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$ciphertext" \
  SECRETS_OUTPUT="$output" \
  bash ./scripts/secrets-setup.sh
[ ! -e "$output" ]

expect_failure env \
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$ciphertext" \
  SECRETS_OUTPUT=README.md \
  bash ./scripts/secrets-setup.sh

expect_failure env \
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$ciphertext" \
  SECRETS_OUTPUT= \
  bash ./scripts/secrets-setup.sh

symlinked_ciphertext="$tmp_dir/symlinked.sops.env"
ln -s "$ciphertext" "$symlinked_ciphertext"
expect_failure env \
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$symlinked_ciphertext" \
  SECRETS_OUTPUT="$output" \
  bash ./scripts/secrets-setup.sh

ln -s "$tmp_dir/redirected.env" "$output"
expect_failure run_setup
rm -f "$output"

symlinked_parent=".env.local.sops-parent.$$"
mkdir -p "$tmp_dir/outside"
ln -s "$tmp_dir/outside" "$symlinked_parent"
expect_failure env \
  PATH="$tmp_dir/bin:$PATH" \
  FAKE_SOPS_PAYLOAD="$payload" \
  PUTIO_SDK_SWIFT_SOPS_FILE="$ciphertext" \
  SECRETS_OUTPUT="$symlinked_parent/rendered.env" \
  bash ./scripts/secrets-setup.sh
rm -f "$symlinked_parent"

printf 'ok SOPS setup renders validated ignored output and fails closed\n'
