# Agent Guide

## Repo

- Swift SDK for the put.io API; the first-party consumer is [putio-ios](https://github.com/putdotio/putio-ios)
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
- `make verify` starts with `swift format lint --strict` using the Xcode toolchain's stock rules; run `swift format --in-place --recursive --parallel` on the same paths to fix violations
- Update docs when package metadata, release flow, or verification changes

## Proof

- Docs only: no Markdown gate exists; confirm the commands and links you name resolve. No runtime proof.
- Source change: `make verify`; it also builds the example app.
- Platform-conditional code: `make verify-platforms`. Pull request CI skips it and the push to `main` runs it before release, so a tvOS or watchOS break otherwise surfaces only after merge.
- Request or auth-flow behavior: run the example app in an iPhone simulator for the auth-flow smoke, and `make live-test` when real API behavior matters. The live account is shared and real; stay inside the [safety rules](./docs/TESTING.md#safety-rules).

## Delivery

Pull requests squash-merge to `main`. A push to `main` runs `make verify` and `make verify-platforms`; when the commits since the last tag include `feat`, `fix`, `perf`, a revert, or a breaking change, semantic-release commits `VERSION`, tags `vX.Y.Z`, and creates the GitHub Release. Swift Package Manager consumers resolve that tag directly, so the tag is the publish. `docs`, `chore`, `test`, and `ci` release nothing. Recovery and the release environment: [Releases](./CONTRIBUTING.md#releases).
