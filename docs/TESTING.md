# Testing

## Commands

```bash
make verify
make verify-platforms
make verify-concurrency
make live-test
```

`make verify` is the deterministic repo gate. It lints formatting with the Xcode toolchain's `swift format` (stock rules), verifies that CocoaPods package pruning keeps the podspec's support files and that temporary podspec evaluation cannot replace the active helper, runs the Swift package tests (including the strict-concurrency consumer proof) with coverage enabled, enforces a `90%` source line coverage floor across `PutioSDK/Classes`, then builds the package and the example-backed CocoaPods workspace.

`make verify-platforms` runs the deterministic suite on tvOS and watchOS simulators through the `PlatformVerify.xcworkspace` wrapper (the tracked CocoaPods `_Pods.xcodeproj` symlink breaks xcodebuild package discovery at the repository root). Tests that install a mock request handler through `installMockRequestHandler` skip on watchOS with a documented reason: watchOS proxies `URLSession` loads out of process and never consults custom `URLProtocol` classes. That helper is the only way to dispatch through the mock transport, so it is the single suite-level gate; pure-logic tests that never install a handler run on every platform. `scripts/platform-simulator-destination.sh` picks the first device under the matching runtime section of `xcrun simctl list devices available`, accepts upper- or lowercase UDIDs, and is covered by `scripts/check-platform-simulator-destination.sh` against fixtures in `scripts/fixtures/simctl/`.

`make live-test` is opt-in. It runs real API checks against a configured put.io test account and stays separate from the default verify path.

`make verify` requires the Swift 6.2 toolchain (Xcode 26 or newer); see
[Architecture — Swift Concurrency Posture](./ARCHITECTURE.md#swift-concurrency-posture)
for why and for the full strict-concurrency contract.

## Verification Shape

- `make verify` first runs `swift format lint --strict` with stock rules over the package, tests, example app, and scripts
- `make verify` runs `scripts/check-podspec-package.rb` through Bundler to ensure CocoaPods package pruning keeps `VERSION` and `podspec_helper.rb` without leaking a downloaded helper into later platform validation
- `make verify` runs `./scripts/check-sendable-audit.sh` to keep the strict-concurrency `Sendable` audit list exhaustive
- `make verify` runs `./scripts/check-transport-isolation.sh` so `PutioSDK.request` stays caller-isolated, `perform`/`execute` stay `@concurrent`, and no `@concurrent` transport body mentions `self` or reads bare `config`/`delegate`; parser fixtures live under `scripts/fixtures/transport-isolation/`
- Device-code cancellation tests park the SDK through the internal `deviceCodePollObserver`, `deviceCodePollSleeper`, and `deviceCodeSleepEntryObserver` seams instead of URLSession side effects; the production sleep primitive is cancelled directly and through the default polling loop
- `make verify` runs `./scripts/check-platform-simulator-destination.sh` to cover the tvOS/watchOS destination parser with captured simulator listings
- `make verify` runs package-level SwiftPM tests, including `PutioSDKTests` and `PutioSDKStrictConcurrencyTests` in one combined `swift test` invocation
- `make verify` fails if source line coverage for `PutioSDK/Classes` drops below `90%`
- `make verify` then builds the Swift package and the example-backed `PutioSDK` CocoaPods scheme
- `make live-test` runs live SwiftPM tests filtered to `PutioSDKLiveTests`
- `make verify-concurrency` runs only the strict-concurrency consumer proof, for quicker iteration
- GitHub Actions currently runs only `make verify`

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
- authenticated direct-HLS resolution for an already-playable owned video fixture when one is available

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
