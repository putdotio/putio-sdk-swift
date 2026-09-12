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

Requires Xcode 26 or newer. The Swift Package targets iOS, macOS, Mac Catalyst, tvOS, and watchOS 26; the CocoaPods pod targets iOS, tvOS, and watchOS 26.

Install with Swift Package Manager in Xcode using:

```text
https://github.com/putdotio/putio-sdk-swift.git
```

Or add it to `Package.swift` and depend on the `PutioSDK` product:

```swift
dependencies: [
    .package(url: "https://github.com/putdotio/putio-sdk-swift.git", from: "3.0.0")
]
```

With CocoaPods:

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

Every network call is `async throws` over native `URLSession`; there is no third-party networking dependency. URL builders and callback parsing are synchronous.

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

Audio files resolve the same way into a direct stream source, with `startFrom` carrying the saved
position:

```swift
let source = try await sdk.resolveAudioPlaybackSource(fileID: 50)
play(url: source.url, startingAt: source.startFrom)
```

Passing a non-audio file throws `PutioAudioPlaybackResolutionError.unsupportedFileType`.

Returned playback URLs are bearer credentials because they contain the access token needed by the
media endpoint. Use them only for playback; do not log, persist, or share them.

## App Config

`/config` stores whatever keys an app writes. Declare the shape in the app and let the SDK carry it:

```swift
struct AppConfig: Decodable {
  var autoplayNextVideo: Bool

  enum CodingKeys: String, CodingKey {
    case autoplayNextVideo = "autoplay_next_video"
  }

  // The document only holds keys some client has written; missing keys are
  // the app's defaults, not decoding failures.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    autoplayNextVideo = try container.decodeIfPresent(Bool.self, forKey: .autoplayNextVideo) ?? false
  }
}

let config = try await sdk.getConfig(as: AppConfig.self)
_ = try await sdk.setConfigValue(key: "autoplay_next_video", true)
```

## Authentication Example

The example app shows a minimal `ASWebAuthenticationSession` flow with your own client ID and redirect URI, followed by an account fetch:

- [Example/PutioSDK/ViewController.swift](./Example/PutioSDK/ViewController.swift)
- [Example app guide](./Example/README.md)

Generate a state with `try PutioSDK.generateOAuthState()`, pass it to `getAuthURL(redirectURI:state:)`, then extract the token with `accessToken(fromOAuthCallback:expectedScheme:expectedHost:expectedState:)`, which rejects callbacks whose state does not match.

## Docs

- [Contributing](./CONTRIBUTING.md) for setup, `make verify`, live API checks, and releases
- [Architecture](./docs/ARCHITECTURE.md) for the transport, concurrency posture, and covered API surface
- [Testing](./docs/TESTING.md) for what each verification command runs
- [Security](./SECURITY.md) for private vulnerability reporting
- [Agent guide](./AGENTS.md) for repo-specific agent guidance

## License

This project is available under the [MIT License](./LICENSE)
