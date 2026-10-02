# Contributing

## Setup

Requires Xcode 26 or newer (Swift 6.2 toolchain). There is nothing else to install.

## Run Locally

Open the example project, which depends on the package in this checkout:

```bash
open Example/PutioSDK.xcodeproj
```

Any iPhone simulator on iOS `26.0` or newer works for interactive example runs.

## Validation

Run the repo-local verification command before opening or updating a pull request:

```bash
make verify
```

[Testing](./docs/TESTING.md) lists what `make verify`, `make verify-platforms`, and `make live-test` run. `make verify` prefers an Xcode-advertised iPhone simulator destination on iOS `26.0+` and falls back to a generic iOS Simulator destination, which needs the iOS platform installed in Xcode; `make print-simulator-destination` shows the destination it would use.

For real API verification, use the separate live lane. Maintainers with an
authorized age identity materialize the supplied SOPS ciphertext into an
ignored owner-only env file first:

```bash
PUTIO_SDK_SWIFT_SOPS_FILE=/path/to/swift.sops.env make secrets-setup
make live-test
make secrets-clean
```

[Live Environment](./docs/TESTING.md#live-environment) in Testing has the
supported variables, load order, and safety rules. Keep ciphertext coordinates
and private age identities outside this public repository.

## Development Notes

- Keep `README.md` consumer-facing and put contributor workflow here
- Keep tokens, private API credentials, and release-only secrets out of commits

## Releases

- Conventional commits drive automated version selection through semantic-release ([.releaserc.json](./.releaserc.json)), which [ci.yml](./.github/workflows/ci.yml) runs on `main` after `make verify` and `make verify-platforms` pass
- Swift Package Manager resolves versions from the `vX.Y.Z` tags; `scripts/prepare-release.sh` writes `VERSION`, and the GitHub Release is the only publish step. CocoaPods publishing stopped after `3.8.1`
- GitHub release writes use `putio-releaser` through `PUTIO_RELEASE_BOT_CLIENT_ID` and `PUTIO_RELEASE_BOT_PRIVATE_KEY` in the protected `release` Environment
- The `release` Environment is a publish-secret boundary, so the release job sets `deployment: false`; keep its deployment policy restricted to `main`, since the workflow guard is defense in depth, not the secret boundary
- If semantic-release creates the version commit and tag but not the GitHub Release, dispatch `CI` from `main` with that exact `recover_version`
- Recovery validates `main`, `VERSION`, and the existing tag before loading release secrets, then creates the missing GitHub Release from the tag's release commit notes; it is a no-op when the release exists

## Pull Requests

- Add or update verification when behavior changes
- Update docs when setup, release, or package expectations change
- Fill in the pull request template's validation and contract evidence
- Keep unrelated cleanup in follow-up pull requests
