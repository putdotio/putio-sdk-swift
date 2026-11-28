# Contributing

## Setup

Requires Xcode 26 or newer (Swift 6.2) on macOS, or Swift 6.2+ on Linux for
`make verify-linux`, plus Node `20.19+` or `22.12+` for the Markdown check. The
[example app](./Example/README.md) links the package from this checkout.

## Validation

```bash
make verify               # the gate: format, audits, tests, coverage, example build
make verify-platforms     # tvOS and watchOS simulators
make verify-linux         # Linux build and tests
make verify-concurrency   # strict-concurrency consumer proof only
make markdown-check       # Markdown format only
```

The [Makefile](./Makefile) lists what each target runs.

## Live Environment

`make live-test` runs `PutioSDKLiveTests` against a real put.io test account.
It is opt-in and outside `make verify`.

Pass credentials through the environment or copy [.env.example](./.env.example)
to the gitignored `.env.local`, then run `make live-test`.

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

Merging to `main` publishes via [semantic-release](./.releaserc.json) using
Conventional Commits; the commit type decides the version bump. To recover a tag
without its GitHub Release, dispatch [CI](./.github/workflows/ci.yml) with
`recover_version`.

Keep the `release` Environment's deployment policy restricted to `main`. It is
the secret boundary for the `putio-ci` app key; the workflow guard is only
defense in depth.
