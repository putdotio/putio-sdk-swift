# Testing

## Commands

```bash
make verify
make live-test
```

`make verify` is the deterministic repo gate. It runs the Swift package tests with coverage enabled, enforces a `90%` source line coverage floor across `PutioSDK/Classes`, then builds the package and the example-backed CocoaPods workspace.

`make live-test` is opt-in. It runs real API checks against a configured put.io test account and stays separate from the default verify path.

## Verification Shape

- `make verify` runs package-level SwiftPM tests
- `make verify` fails if source line coverage for `PutioSDK/Classes` drops below `90%`
- `make verify` exercises the async `URLSession` transport and decoded model slice through `PutioSDKTests`
- `make verify` then builds the Swift package and the example-backed `PutioSDK` CocoaPods scheme
- `make live-test` runs live SwiftPM tests filtered to `PutioSDKLiveTests`
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

Run `make secrets-setup` to render shared live credentials from the Infisical
`/sdk-swift` path into `.env.local`. The live harness auto-loads `.env.local`
and `.env`; already-exported environment variables keep highest priority.

## Live Scope

Current live targets cover:

- account info against the real API
- disposable folder create, delete, trash restore, and cleanup flows
- transfer list/count/info decode against the real API
- playback-adjacent subtitle decode and reversible start-from roundtrips for owned video fixtures

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
