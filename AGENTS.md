# Agent Guide

## Repo

- Swift SDK for the put.io API
- Current distribution model: Swift Package plus CocoaPods podspec, with an example app workspace

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Testing](./docs/TESTING.md)
- [Readiness](./docs/READINESS.md)
- [Security](./SECURITY.md)

## Commands

- `make bootstrap`
- `make verify`
- `make example-install`
- `make print-simulator-destination`

## Worktrees

`.worktreeinclude` carries `.env` and Bundler config into Codex and Claude
worktrees. Run `make bootstrap`; use `make secrets-setup` with
`PUTIO_SDK_SWIFT_SOPS_FILE` if live-test env is missing or stale.

## Repo-Specific Guidance

- Keep the public package surface open-source-safe
- Prefer the `make verify` entrypoint instead of ad hoc validation commands
- Live tests accept maintainer-supplied `PUTIO_SDK_SWIFT_SOPS_FILE`; `make secrets-setup` validates and writes ignored `.env.local`, and `make secrets-clean` removes it.
- The GitHub repository is `putio-sdk-swift`
- The Swift Package surface is `PutioSDK`
- The CocoaPods package is `PutioSDK`
- The Swift Package module, CocoaPods module, and public SDK types are all `PutioSDK`
- CI and release automation run from `main`
- The release workflow uses semantic-release after `make verify` passes on `main`
- GitHub release writes use `putio-releaser`; CocoaPods publishing additionally needs `COCOAPODS_TRUNK_TOKEN` in the protected `release` Environment
- The `release` Environment is a publish-secret boundary, so the release job sets `deployment: false`
- Release jobs cache CocoaPods downloads only and regenerate generated `Example/Pods`
- Verify example workspace installation when auth-flow or package-install surface changes
- Repo verification should build the Swift package and the `PutioSDK` CocoaPods scheme from the example workspace
- `make verify` prefers an Xcode-advertised iPhone simulator destination on iOS `26.0+` and falls back to the installed `iphonesimulator` SDK when Xcode is not exposing one yet
- `make print-simulator-destination` shows the concrete iPhone simulator destination the repo would use when Xcode can advertise one
- `pod lib lint` remains a manual publish-time check until destination resolution is consistent across local and CI environments
- Use the example app for auth-flow smoke checks when request behavior changes
- Update docs when package metadata, release flow, or verification changes
