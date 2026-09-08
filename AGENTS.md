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

- `make bootstrap`
- `make verify`
- `make verify-platforms`
- `make live-test`
- `make example-install`
- `make print-simulator-destination`

## Worktrees

`.worktreeinclude` carries `.env`, `.env.local`, and Bundler config into Codex and Claude
worktrees. Run `make bootstrap`; use `make secrets-setup` with
`PUTIO_SDK_SWIFT_SOPS_FILE` if live-test env is missing or stale, and
`make secrets-clean` before removing the worktree.

## Repo-Specific Guidance

- Keep the public package surface open-source-safe: no first-party client identifiers, callback URLs, or token-scope details in code, docs, or the example app
- Prefer the `make verify` entrypoint instead of ad hoc validation commands
- The GitHub repository is `putio-sdk-swift`; the Swift Package product, CocoaPods pod, module, and public type prefix are all `PutioSDK`
- CI and release automation run from `main`; the release contract lives in [Contributing — Releases](./CONTRIBUTING.md#releases)
- Verify example workspace installation when auth-flow or package-install surface changes
- `make verify` starts with `swift format lint --strict` using the Xcode toolchain's stock rules; run `swift format --in-place --recursive --parallel` on the same paths to fix violations
- Use the example app for auth-flow smoke checks when request behavior changes
- Update docs when package metadata, release flow, or verification changes
