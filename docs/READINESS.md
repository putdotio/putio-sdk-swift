# SDK Readiness

This document tracks how ready `putio-sdk-swift` is for autonomous agent work and public package maintenance.

## Overall Status

- deterministic package-level unit tests now exist under `Tests/PutioSDKTests`
- an opt-in live verification layer exists under `Tests/PutioSDKLiveTests`
- the shared transport now has a native async `URLSession` path with `Decodable` boundary parsing for the modernized domains
- a Swift 6 consumer target now verifies actor-owned SDK use and the audited `Sendable` value surface under strict concurrency
- typed failures now conform to `LocalizedError` and carry recovery guidance, retryability, and classification helpers
- `make verify` is the canonical deterministic guardrail and enforces a `90%` source line coverage floor for `PutioSDK/Classes`
- `make live-test` is the opt-in real API verification lane

## Current Confidence

| Area | Status | Notes |
| --- | --- | --- |
| Package boot | `good` | `make bootstrap` and `make verify` are documented and exercised in CI |
| Unit verification | `good` | request config, async transport, localized errors, and the modernized account/auth/history/files/media/grants/routes/subtitles/transfers/trash domains now have deterministic package coverage with a `90%` source line floor enforced by `make verify` |
| Live verification | `medium` | account, disposable file/trash, transfer read paths, and playback-adjacent file helpers are live-covered; more namespaces still need safe real-API targets |
| Native SDK baseline | `good` | auth/OAuth, account/settings/security/2FA, files, search, transfers, history/events, trash, subtitles, and playback-adjacent helpers have typed async surfaces |
| Strict concurrency | `good` | async APIs inherit caller isolation; the consumer proof covers every SDK domain, actor-owned mutable models, and low-risk `Sendable` value types |
| Release readiness | `good` | `main` stays verify-first, with semantic-release and optional CocoaPods publishing |

## Highest-Value Next Gaps

1. add more live coverage for safe read and reversible mutation flows
2. keep broadening deterministic tests as new namespaces land so the `90%` floor stays comfortable
3. keep the example app aligned with the async-first package surface as auth and playback flows evolve
4. plan mutable open-class model conversions and the legacy mutable global as deliberate semver-major work rather than unchecked sendability
