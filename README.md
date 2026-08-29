<div align="center">
  <p>
    <img src="https://static.put.io/images/putio-boncuk.png" width="72" alt="put.io boncuk">
  </p>

  <h1>putio-sdk-swift</h1>

  <p>
    Swift SDK for the <a href="https://api.put.io/v2/docs">put.io API</a>
  </p>

  <p>
    Swift Package: <code>PutioSDK</code> · CocoaPods package: <code>PutioSDK</code>
  </p>

  <p>
    <a href="https://github.com/putdotio/putio-sdk-swift/actions/workflows/ci.yml?query=branch%3Amain" style="text-decoration:none;"><img src="https://img.shields.io/github/actions/workflow/status/putdotio/putio-sdk-swift/ci.yml?branch=main&style=flat&label=ci&colorA=000000&colorB=000000" alt="CI"></a>
    <a href="https://cocoapods.org/pods/PutioSDK" style="text-decoration:none;"><img src="https://img.shields.io/cocoapods/v/PutioSDK?style=flat&colorA=000000&colorB=000000" alt="CocoaPods version"></a>
    <a href="https://github.com/putdotio/putio-sdk-swift/blob/main/LICENSE" style="text-decoration:none;"><img src="https://img.shields.io/github/license/putdotio/putio-sdk-swift?style=flat&colorA=000000&colorB=000000" alt="license"></a>
  </p>
</div>

## Installation

Install with Swift Package Manager in Xcode using:

```text
https://github.com/putdotio/putio-sdk-swift.git
```

Or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/putdotio/putio-sdk-swift.git", from: "1.0.0")
]
```

Then depend on the `PutioSDK` product.

Import it as:

```swift
import PutioSDK
```

If you use CocoaPods today, install with:

```ruby
pod 'PutioSDK'
```

## Quick Start

```swift
import PutioSDK

let sdk = PutioSDK(
    config: PutioSDKConfig(
        clientID: "<your-client-id>",
        token: "<your-access-token>"
    )
)

Task {
    do {
        let account = try await sdk.getAccountInfo()
        print(account.username)
    } catch let error as PutioSDKError {
        print(error.message)
        print(error.recoverySuggestion ?? "")
    }
}
```

The SDK exposes an async-first `async throws` surface with native `URLSession` transport and no third-party networking dependency. It no longer ships completion-handler compatibility wrappers or raw JSON response APIs.

Apps that need a custom transport for tests, fixtures, or specialized session configuration can pass their own `URLSession`:

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MockURLProtocol.self]

let sdk = PutioSDK(
    config: PutioSDKConfig(clientID: "<your-client-id>"),
    urlSession: URLSession(configuration: configuration)
)
```

## Error Handling

Thrown SDK errors are `PutioSDKError` values that conform to `LocalizedError` and expose small classification helpers for app code:

```swift
do {
    _ = try await sdk.getFile(fileID: 42)
} catch let error as PutioSDKError {
    if error.isAuthenticationFailure {
        // refresh credentials or send the user through sign-in
    } else if error.isRetryable {
        // schedule a retry with backoff
    } else if error.matches(statusCode: 404) {
        // refresh stale local state
    }
}
```

## Video Playback

The SDK resolves video metadata and constructs the authenticated HLS URL so apps do not supply or
assemble access-token query parameters:

```swift
switch try await sdk.resolveVideoPlaybackSource(fileID: 42) {
case .ready(let source):
    play(url: source.url, startingAt: source.startFrom)
case .conversionRequired:
    showConversionRequired()
}
```

Passing a non-video file throws `PutioVideoPlaybackResolutionError.unsupportedFileType` with a
localized recovery suggestion.

The returned URL is a bearer credential because it contains the access token needed by the media
endpoint. Use it only for playback; do not log, persist, or share it.

## Development

For local development, the repo exposes one verification command:

```bash
make verify
```

Use [Contributing](./CONTRIBUTING.md) for setup, deterministic verification, live API checks, and release expectations.

## Authentication Example

The example app shows a minimal `ASWebAuthenticationSession` flow and a follow-up account fetch:

- [Example/PutioSDK/ViewController.swift](./Example/PutioSDK/ViewController.swift)
- [Example app guide](./Example/README.md)

Use `try PutioSDK.generateOAuthState()` with `getAuthURL(redirectURI:state:)`, then validate the returned callback state before accepting `access_token`.

## Docs

- [Example app](./Example) for the example app and smoke-test workspace
- [Architecture](./docs/ARCHITECTURE.md) for the current async transport and decoding direction
- [Testing](./docs/TESTING.md) for deterministic and live verification
- [Readiness](./docs/READINESS.md) for the current verification confidence
- [Security](./SECURITY.md) for private vulnerability reporting

## Repo Internals

- [Agent guide](./AGENTS.md) for repo-specific agent guidance

## Contributing

Start with [Contributing](./CONTRIBUTING.md) so local setup, verification, and release expectations stay aligned with CI

## License

This project is available under the [MIT License](./LICENSE)
