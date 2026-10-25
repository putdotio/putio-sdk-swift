# Agent Guide

Public Swift SDK for the put.io API; its first-party consumer is
[putio-ios](https://github.com/putdotio/putio-ios). Read
[Contributing](./CONTRIBUTING.md) for the check lanes and the live environment.

## Boundaries

- The package is open source: keep first-party client identifiers, callback URLs,
  and token-scope details out of code, docs, and the example app, and use
  placeholders such as `<your-client-id>`.
- Live-test credentials live in an ignored `.env.local`; run
  `make secrets-clean` before you remove a worktree.
- Public `Sendable` conformances are API. Never add `@unchecked Sendable` to a
  type that is not thread-safe. Making the `open` class models or
  `PutioClearDataOptionKeys` `Sendable` breaks the API and needs a major release.

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
  [safety rules](./CONTRIBUTING.md#safety-rules).

## Delivery

Merging to `main` publishes, and the commit type decides the release
([Releases](./CONTRIBUTING.md#releases)).
