# Contributing

## Setup

Requires Xcode 26 or newer (Swift 6.2) and Node `20.19+` or `22.12+` for the
Markdown check. The [example app](./Example/README.md) links the package from
this checkout.

## Validation

```bash
make verify               # the gate: format, audits, tests, coverage, example build
make verify-platforms     # tvOS and watchOS simulators
make verify-concurrency   # strict-concurrency consumer proof only
make markdown-check       # Markdown format only
```

The [Makefile](./Makefile) lists what each target runs.

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

To use your own credentials, copy [.env.example](./.env.example) to
`.env.local`. Keep ciphertext coordinates and age identities out of this public
repository.

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

## Releases

Merging to `main` publishes: [semantic-release](./.releaserc.json) tags a
release when the commits include `feat`, `fix`, `perf`, a revert, or a breaking
change, so the commit type decides the release. To recover a tag without its
GitHub Release, dispatch [CI](./.github/workflows/ci.yml) with
`recover_version`.

Keep the `release` Environment's deployment policy restricted to `main`. It is
the secret boundary for the `putio-ci` app key; the workflow guard is only
defense in depth.
