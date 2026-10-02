# Agent Guide

## Repo

- Swift SDK for the put.io API
- Distribution: Swift Package Manager only (CocoaPods stopped at `3.8.1`), with an example app project

## Start Here

- [Overview](./README.md)
- [Contributing](./CONTRIBUTING.md) for setup, verification, live tests, and the release flow
- [Architecture](./docs/ARCHITECTURE.md)
- [Testing](./docs/TESTING.md) for what each verification command runs
- [Security policy](https://github.com/putdotio/.github/blob/main/SECURITY.md)

## Commands

Targets are defined in the [Makefile](./Makefile); [Testing](./docs/TESTING.md#commands) lists what each lane runs.

- `make verify`: deterministic gate; use it instead of ad hoc validation commands
- `make verify-platforms`: tvOS and watchOS lane
- `make live-test`: opt-in live suite; env in [Live Environment](./docs/TESTING.md#live-environment)
- `make print-simulator-destination`: the iPhone simulator destination `verify` would use

## Worktrees

`.worktreeinclude` carries `.env` and `.env.local` into Codex and Claude worktrees. Use
`make secrets-setup` with
`PUTIO_SDK_SWIFT_SOPS_FILE` if live-test env is missing or stale, and
`make secrets-clean` before removing the worktree.

## Repo-Specific Guidance

- Keep the public package surface open-source-safe: no first-party client identifiers, callback URLs, or token-scope details in code, docs, or the example app
- The GitHub repository is `putio-sdk-swift`; the Swift Package product and module are both `PutioSDK`, and public types use the `Putio` prefix
- CI and release automation run from `main`; the release contract lives in [Releases](./CONTRIBUTING.md#releases)
- `make verify` starts with `swift format lint --strict` using the Xcode toolchain's stock rules; run `swift format --in-place --recursive --parallel` on the same paths to fix violations
- Run the example app for auth-flow smoke checks when request behavior changes, and build it when the auth-flow or package surface changes
- Update docs when package metadata, release flow, or verification changes
