# Contributing

Thanks for contributing to the Swift SDK for put.io.

## Setup

Requires Xcode 26 or newer (Swift 6.2 toolchain) and the Ruby version from `.ruby-version`. Then bootstrap the repository:

```bash
make bootstrap
```

If you want to run the example app locally, install its CocoaPods workspace too:

```bash
make example-install
```

## Run Locally

Open the example workspace:

```bash
open Example/PutioSDK.xcworkspace
```

Any iPhone simulator on iOS `26.0` or newer works for interactive example runs.

## Validation

Run the repo-local verification command before opening or updating a pull request:

```bash
make verify
```

[Testing](./docs/TESTING.md) lists what `make verify`, `make verify-platforms`, and `make live-test` run. `make verify` prefers an Xcode-advertised iPhone simulator destination on iOS `26.0+` and falls back to the installed `iphonesimulator` SDK; `make print-simulator-destination` shows the destination it would use.

For real API verification, use the separate live lane:

```bash
make live-test
```

The live suite reads runtime env vars first, then `.env.local` and `.env`. See [Testing — Live Environment](./docs/TESTING.md#live-environment) for the supported variables and safety rules.

Maintainers with an authorized age identity can materialize the supplied SOPS
ciphertext into an ignored owner-only env file:

```bash
PUTIO_SDK_SWIFT_SOPS_FILE=/path/to/swift.sops.env make secrets-setup
make live-test
make secrets-clean
```

`secrets-setup` requires SOPS 3.10 or newer. Keep ciphertext coordinates and
private age identities outside this public repository.

## Development Notes

- Keep `README.md` consumer-facing and put contributor workflow here
- Keep `Package.swift`, `podspec_helper.rb`, `PutioSDK.podspec`, and `VERSION` aligned when dependency or platform support changes
- Use `bundle exec pod lib lint PutioSDK.podspec --allow-warnings` as a manual publish-time check when you need full podspec validation and have a working iOS destination available
- Use the example app for lightweight runtime sanity checks when changing auth or request flow behavior
- Keep tokens, private API credentials, and release-only secrets out of commits

## Releases

- Conventional commits drive automated version selection through semantic-release, which runs on `main` after `make verify` and `make verify-platforms` pass
- `scripts/prepare-release.sh` writes `VERSION` and regenerates `Example/Podfile.lock`; `scripts/publish-cocoapods.sh` pushes the pod and trusts trunk state over a flaky CLI exit code
- GitHub release writes use `putio-releaser` through `PUTIO_RELEASE_BOT_CLIENT_ID` and `PUTIO_RELEASE_BOT_PRIVATE_KEY` in the protected `release` Environment; CocoaPods publishing additionally needs `COCOAPODS_TRUNK_TOKEN` there
- The `release` Environment is a publish-secret boundary, so the release job sets `deployment: false`; keep its deployment policy restricted to `main`, since the workflow guard is defense in depth, not the secret boundary
- Release jobs cache CocoaPods downloads only and regenerate `Example/Pods`
- If semantic-release creates a version commit and tag before publishing fails, fix the cause on `main`, then dispatch `CI` from `main` with that exact `recover_version`
- Recovery validates `main`, `VERSION`, and the existing tag before loading release secrets, then idempotently publishes the missing CocoaPods version before creating the missing GitHub Release
- Recovery requires `VERSION` to remain unchanged and the tagged CocoaPods source payload (`LICENSE`, `PutioSDK/`, and `podspec_helper.rb`) to match `main`; source changes require a new release instead

## Pull Requests

- Keep changes focused and explicit
- Add or update verification when behavior changes
- Update docs when setup, release, or package expectations change
- Use the pull request template to include the validation and contract evidence reviewers need
- Prefer follow-up pull requests over mixing unrelated cleanup into the same branch
