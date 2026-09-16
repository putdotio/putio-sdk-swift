# Agent Guide

## Repo

- Swift SDK for the put.io API
- Distribution: Swift Package plus CocoaPods podspec, with an example app workspace

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md) for setup, verification, live tests, and the release flow
- [Architecture](./docs/ARCHITECTURE.md)
- [Testing](./docs/TESTING.md) for what each verification command runs
- [Security](./SECURITY.md)

## Commands

Targets are defined in the [Makefile](./Makefile); [Testing](./docs/TESTING.md#commands) lists what each lane runs.

- `make bootstrap`: Bundler setup
- `make verify`: deterministic gate; use it instead of ad hoc validation commands
- `make verify-platforms`: tvOS and watchOS lane
- `make live-test`: opt-in live suite; env in [Live Environment](./docs/TESTING.md#live-environment)
- `make example-install`: CocoaPods install for the example workspace
- `make print-simulator-destination`: the iPhone simulator destination `verify` would use

## Worktrees

`.worktreeinclude` carries `.env`, `.env.local`, and Bundler config into Codex and Claude
worktrees. Run `make bootstrap`; use `make secrets-setup` with
`PUTIO_SDK_SWIFT_SOPS_FILE` if live-test env is missing or stale, and
`make secrets-clean` before removing the worktree.

## Repo-Specific Guidance

- Keep the public package surface open-source-safe: no first-party client identifiers, callback URLs, or token-scope details in code, docs, or the example app
- The GitHub repository is `putio-sdk-swift`; the Swift Package product, CocoaPods pod, and module are all `PutioSDK`, and public types use the `Putio` prefix
- CI and release automation run from `main`; the release contract lives in [Releases](./CONTRIBUTING.md#releases)
- `make verify` starts with `swift format lint --strict` using the Xcode toolchain's stock rules; run `swift format --in-place --recursive --parallel` on the same paths to fix violations
- Run the example app for auth-flow smoke checks when request behavior changes, and verify its workspace installation when the auth-flow or package-install surface changes
- Update docs when package metadata, release flow, or verification changes
