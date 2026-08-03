# Contributing

Thanks for contributing to the Swift SDK for put.io.

## Setup

Install the Ruby version from `.ruby-version`, then bootstrap the repository:

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

## Validation

Run the repo-local verification command before opening or updating a pull request:

```bash
make verify
```

This check builds the Swift package, installs the example workspace, and then builds the example-backed `PutioSDK` CocoaPods scheme from the example workspace. It prefers any Xcode-advertised iPhone simulator destination on iOS `26.0+`, and falls back to the installed `iphonesimulator` SDK when Xcode is not exposing one yet

For real API verification, use the separate live lane:

```bash
make live-test
```

The live suite prefers direct runtime env vars first and can optionally hydrate credentials from repo-local operator configuration. See [Testing](./docs/TESTING.md) for the supported public variables and safety rules.

Maintainers with an authorized age identity can materialize the supplied SOPS
ciphertext into an ignored owner-only env file:

```bash
PUTIO_SDK_SWIFT_SOPS_FILE=/path/to/swift.sops.env make secrets-setup
make live-test
make secrets-clean
```

`secrets-setup` requires SOPS 3.10 or newer. Keep ciphertext coordinates and
private age identities outside this public repository.

To see the concrete iPhone simulator destination Xcode is advertising to the repo on your machine, run:

```bash
make print-simulator-destination
```

## Development Notes

- Keep `README.md` consumer-facing and put contributor workflow here
- Keep deeper verification details in `docs/ARCHITECTURE.md`, `docs/TESTING.md`, and `docs/READINESS.md`
- The GitHub repository is `putio-sdk-swift`
- The Swift Package product and module are `PutioSDK`
- The CocoaPods package is `PutioSDK`
- The public SDK module and type names are `PutioSDK`
- Prefer the native async APIs and treat completion-handler entrypoints as compatibility wrappers when extending existing domains
- Keep `Package.swift`, `podspec_helper.rb`, `PutioSDK.podspec`, and `VERSION` aligned when dependency or platform support changes
- Any iPhone simulator on iOS `26.0` or newer is acceptable for interactive example runs; the repo does not require an exact simulator patch version
- Use `bundle exec pod lib lint PutioSDK.podspec --allow-warnings` as a manual publish-time check when you need full podspec validation and have a working iOS destination available
- Use the example app for lightweight runtime sanity checks when changing auth or request flow behavior
- Keep tokens, private API credentials, and release-only secrets out of commits
- The release workflow uses semantic-release on `main`
- Conventional commits drive automated version selection through semantic-release
- GitHub release writes use `putio-releaser` through `PUTIO_RELEASE_BOT_CLIENT_ID` and `PUTIO_RELEASE_BOT_PRIVATE_KEY` in the protected `release` Environment
- CocoaPods publishing additionally needs `COCOAPODS_TRUNK_TOKEN` in the protected `release` Environment
- The `release` Environment is a publish-secret boundary, so the release job sets `deployment: false`
- Release jobs cache CocoaPods download artifacts only and regenerate generated `Example/Pods`

## Pull Requests

- Keep changes focused and explicit
- Add or update verification when behavior changes
- Update docs when setup, release, or package expectations change
- Use the pull request template to include the validation and contract evidence reviewers need
- Prefer follow-up pull requests over mixing unrelated cleanup into the same branch
