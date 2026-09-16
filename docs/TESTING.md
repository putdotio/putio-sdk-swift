# Testing

## Commands

```bash
make verify
make verify-platforms
make verify-concurrency
make live-test
```

`make verify` is the deterministic repo gate and requires the Swift 6.2 toolchain (Xcode 26 or newer); see [Swift Concurrency Posture](./ARCHITECTURE.md#swift-concurrency-posture) for the strict-concurrency contract. In order it runs:

- `swift format lint --strict` with stock rules over the package, tests, example app, and scripts
- `scripts/check-podspec-package.rb` through Bundler, so CocoaPods package pruning keeps `VERSION` and `podspec_helper.rb` and a downloaded helper cannot replace the active one during later platform validation
- `scripts/check-sendable-audit.sh`, so every public `Sendable` type under `PutioSDK/Classes` is listed in the strict-concurrency audit
- `scripts/check-transport-isolation.sh`, so `PutioSDK.request` stays caller-isolated and the `@concurrent` `perform`/`execute` bodies never mention `self` or read bare `config`/`delegate`; parser fixtures live under `scripts/fixtures/transport-isolation/`
- `scripts/check-platform-simulator-destination.sh`, which covers the tvOS/watchOS destination parser against captured `simctl` listings in `scripts/fixtures/simctl/`
- `swift test` for `PutioSDKTests` and `PutioSDKStrictConcurrencyTests` in one invocation with coverage enabled
- `scripts/check-spm-coverage.sh 90`, failing when source line coverage for `PutioSDK/Classes` drops below `90%`
- `swift build`, then `pod install` and an `xcodebuild` of the example-backed `PutioSDK` CocoaPods scheme

`make verify-platforms` runs the deterministic suite on tvOS and watchOS simulators through the `PlatformVerify.xcworkspace` wrapper (the tracked CocoaPods `_Pods.xcodeproj` symlink breaks xcodebuild package discovery at the repository root). Tests that install a mock request handler through `installMockRequestHandler` skip on watchOS because watchOS proxies `URLSession` loads out of process and never consults custom `URLProtocol` classes; that helper is the only way to dispatch through the mock transport, so it is the single suite-level gate, and pure-logic tests run on every platform. `scripts/platform-simulator-destination.sh` picks the first available device in the matching family from `xcrun simctl list devices available` and accepts upper- or lowercase UDIDs.

`make verify-concurrency` runs only the strict-concurrency consumer proof, for quicker iteration.

`make live-test` is opt-in. It runs `PutioSDKLiveTests` against a configured put.io test account and stays separate from the default verify path.

Device-code cancellation tests drive the SDK through the internal `deviceCodePollObserver` and `deviceCodePollClock` seams instead of URLSession side effects; a test clock observes sleep entry from inside the suspension for the deterministic mid-sleep proof, while the spy-clock and default `ContinuousClock` tests only bound the cancellation response.

[ci.yml](../.github/workflows/ci.yml) runs `make verify` on `macos-latest` with the latest stable Xcode for every pull request and push to `main`; `make verify-platforms` runs on pushes and dispatches only.

## Live Environment

Copy [.env.example](../.env.example) when using your own credentials. Supported runtime variables:

- `PUTIO_TOKEN_FIRST_PARTY` (aliases: `PUTIO_ACCESS_TOKEN`, `PUTIO_TOKEN`): access token for the test account; tests skip when absent
- `PUTIO_CLIENT_ID`: your OAuth client ID
- `PUTIO_BASE_URL`: optional API base URL override

Run `make secrets-setup` with `PUTIO_SDK_SWIFT_SOPS_FILE` pointing to the
maintainer-supplied SOPS ciphertext. The command ([scripts/secrets-setup.sh](../scripts/secrets-setup.sh))
requires SOPS 3.10 or newer, rejects plaintext or malformed payloads, and writes
an owner-only `.env.local` file. The live harness loads exported environment
variables first, then `.env.local`, then `.env` from the repository root. Run
`make secrets-clean` before removing the worktree.

## Live Scope

Current live targets cover:

- account info and token validation against the real API
- disposable folder create, delete, trash restore, and cleanup flows
- transfer list/count/info decode against the real API
- playback-adjacent subtitle decode and reversible start-from roundtrips for owned video fixtures
- authenticated direct-HLS resolution for an already-playable owned video fixture when one is available
- authenticated audio-stream resolution for an owned audio fixture when one is available

When the live account has trash disabled, the disposable flow proves create, list, and delete and reports restore coverage as skipped instead of changing the shared account setting.

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
