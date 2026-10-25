# Contributing

## Setup

Requires Xcode 26 or newer (Swift 6.2) and Node `20.19+` or `22.12+` for the
Markdown check.

Open the example app, which links the package from this checkout:

```bash
open Example/PutioSDK.xcodeproj
```

## Validation

```bash
make verify               # the gate: format, audits, tests, coverage, example build
make verify-platforms     # tvOS and watchOS simulators
make verify-concurrency   # strict-concurrency consumer proof only
make markdown-check       # Markdown format only
```

The [Makefile](./Makefile) lists what each target runs. Run `make verify`
before you open or update a pull request.

- It builds the example app on an iPhone simulator on iOS `26.0+`, or on a
  generic iOS Simulator destination when Xcode advertises none.
  `make print-simulator-destination` shows the choice.
- Fix Swift format findings with
  `swift format --in-place --recursive --parallel` on the paths `make verify`
  lints, and Markdown with `npx --yes oxfmt@<version> '**/*.md'` at the version
  in [package.json](./package.json).
- Pull-request CI skips `make verify-platforms`; it runs on pushes to `main`
  ([ci.yml](./.github/workflows/ci.yml)).
- On watchOS, `URLSession` loads run out of process and never reach a custom
  `URLProtocol`. Tests that install a mock through `installMockRequestHandler`
  skip there, so keep that helper the only way into the mock transport.

## Live Environment

`make live-test` runs `PutioSDKLiveTests` against a real put.io test account.
It is opt-in and outside `make verify`.

Maintainers with an authorized age identity write the ignored, owner-only
`.env.local` from the supplied SOPS ciphertext (SOPS 3.10+):

```bash
PUTIO_SDK_SWIFT_SOPS_FILE=/path/to/swift.sops.env make secrets-setup
make live-test
make secrets-clean   # before you remove the worktree
```

To use your own credentials, copy [.env.example](./.env.example).
[LiveSupport.swift](./Tests/PutioSDKLiveTests/LiveSupport.swift) reads the
variables from the environment first, then `.env.local`, then `.env`; tests
skip without a token. Keep ciphertext coordinates and age identities out of
this public repository.

### Safety Rules

The live account is shared and real.

Allowed in `make live-test`:

- read-only account and transfer probes
- reversible playback-resume mutations with cleanup
- disposable file and trash flows with cleanup

Excluded:

- destructive account mutations
- trash emptying
- any mutation without cleanup

When the account has trash disabled, the disposable flow reports restore as
skipped instead of changing the shared setting.

## Releases

Merging to `main` publishes: [semantic-release](./.releaserc.json) tags a
release when the commits include `feat`, `fix`, `perf`, a revert, or a breaking
change, so the commit type decides the release. To recover a tag without its
GitHub Release, dispatch [CI](./.github/workflows/ci.yml) with
`recover_version`.

Keep the `release` Environment's deployment policy restricted to `main`. It is
the secret boundary for the `putio-ci` app key; the workflow guard is only
defense in depth.

## Pull Requests

- Add or update verification when behavior changes.
- Update docs when setup, release, or package expectations change.
- Fill in the [pull request template](./.github/pull_request_template.md).
- Keep unrelated cleanup in follow-up pull requests.
