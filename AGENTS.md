# Agent Guide

Public Swift SDK for the put.io API; its first-party consumer is
[putio-ios](https://github.com/putdotio/putio-ios). Read
[Architecture](./docs/architecture.md) before changing the transport, concurrency
posture, or public types, and [Testing](./docs/testing.md) for what each lane runs
and the live environment.

## Boundaries

- The package is open source: keep first-party client identifiers, callback URLs,
  and token-scope details out of code, docs, and the example app, and use
  placeholders such as `<your-client-id>`.
- Live-test credentials live in an ignored `.env.local`:
  `PUTIO_SDK_SWIFT_SOPS_FILE=/path/to/swift.sops.env make secrets-setup` writes it,
  and `make secrets-clean` removes it before you remove a worktree.

## Formatting

`make verify` starts with `swift format lint --strict` on stock rules; fix findings
with `swift format --in-place --recursive --parallel` on the paths the
[Makefile](./Makefile) lints. For Markdown, run
`npx --yes oxfmt@<version> '**/*.md'` with the version pinned in
[package.json](./package.json).

## Proof

- Docs only: `make markdown-check`; CI checks relative links and anchors, so
  check web links and commands yourself.
- Source: `make verify`, which also builds the example app.
- Platform-conditional code: `make verify-platforms`. Pull request CI skips it,
  so a tvOS or watchOS break otherwise surfaces only after merge, where it
  blocks the release.
- Request or auth-flow behavior: the [example app](./Example/README.md) sign-in
  smoke in an iPhone simulator, and `make live-test` when real API behavior
  matters. The live account is shared and real; stay inside the
  [safety rules](./docs/testing.md#safety-rules).

## Delivery

Merging to `main` publishes. When the commits since the last tag include `feat`,
`fix`, `perf`, a revert, or a breaking change, semantic-release commits `VERSION`,
tags `vX.Y.Z`, and creates the GitHub Release; Swift Package Manager consumers
resolve that tag directly. Other commit types release nothing, so the commit type
decides the release. When a tag exists without its GitHub Release, follow
[Releases](./CONTRIBUTING.md#releases).
