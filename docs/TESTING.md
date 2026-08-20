# Testing

## Commands

```bash
make verify
make verify-concurrency
make live-test
```

`make verify` is the deterministic repo gate. It lints formatting with the Xcode toolchain's `swift format` (stock rules), runs the Swift package tests with coverage enabled, enforces a `90%` source line coverage floor across `PutioSDK/Classes`, then builds the package and the example-backed CocoaPods workspace.

`make live-test` is opt-in. It runs real API checks against a configured put.io test account and stays separate from the default verify path.

## Verification Shape

- `make verify` first runs `swift format lint --strict` with stock rules over the package, tests, example app, and scripts
- `make verify` runs package-level SwiftPM tests
- `make verify` fails if source line coverage for `PutioSDK/Classes` drops below `90%`
- `make verify` compiles and runs the Swift 6 strict-concurrency consumer proof
- `make verify` exercises the async `URLSession` transport and decoded model slice through `PutioSDKTests`
- `make verify` then builds the Swift package and the example-backed `PutioSDK` CocoaPods scheme
- `make live-test` runs live SwiftPM tests filtered to `PutioSDKLiveTests`
- GitHub Actions currently runs only `make verify`

`make verify-concurrency` is the focused form of the consumer proof. Its test
target uses Swift 6 language mode even though the library preserves its Swift 5
language mode for source compatibility.

## Live Environment

Default example env file:

- `.env.example`

Supported public runtime variables:

- `PUTIO_TOKEN_FIRST_PARTY`
- `PUTIO_ACCESS_TOKEN`
- `PUTIO_TOKEN`
- `PUTIO_CLIENT_ID`
- `PUTIO_BASE_URL`

Run `make secrets-setup` with `PUTIO_SDK_SWIFT_SOPS_FILE` pointing to the
maintainer-supplied SOPS ciphertext. The command requires SOPS 3.10 or newer,
rejects plaintext or malformed payloads, and writes owner-only `.env.local`.
The live harness auto-loads `.env.local` and `.env`; already-exported
environment variables keep highest priority. Run `make secrets-clean` before
removing the worktree.

## Live Scope

Current live targets cover:

- account info against the real API
- disposable folder create, delete, trash restore, and cleanup flows
- transfer list/count/info decode against the real API
- playback-adjacent subtitle decode and reversible start-from roundtrips for owned video fixtures

The disposable flow still proves create, list, and delete when the live account
has trash disabled; restore coverage is reported as skipped instead of changing
the shared account setting.

## Safety Rules

Allowed in `make live-test`:

- read-only account probes
- read-only transfer probes
- reversible playback resume mutations with cleanup
- disposable file and trash flows with cleanup

Excluded from `make live-test`:

- destructive account mutations
- trash emptying
- any mutation without cleanup
