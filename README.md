<div align="center">
  <p>
    <img src="https://static.put.io/images/putio-boncuk.png" width="72" alt="put.io boncuk">
  </p>

  <h1>putio-sdk-swift</h1>

  <p>
    Swift SDK for the <a href="https://api.put.io/v2/docs">put.io API</a>
  </p>

  <p>
    Swift Package: <code>PutioSDK</code>
  </p>

  <p>
    <a href="https://github.com/putdotio/putio-sdk-swift/actions/workflows/ci.yml?query=branch%3Amain" style="text-decoration:none;"><img src="https://img.shields.io/github/actions/workflow/status/putdotio/putio-sdk-swift/ci.yml?branch=main&style=flat&label=ci&colorA=000000&colorB=000000" alt="CI"></a>
    <a href="https://github.com/putdotio/putio-sdk-swift/releases/latest" style="text-decoration:none;"><img src="https://img.shields.io/github/v/release/putdotio/putio-sdk-swift?style=flat&label=release&colorA=000000&colorB=000000" alt="Latest release"></a>
    <a href="https://github.com/putdotio/putio-sdk-swift/blob/main/LICENSE" style="text-decoration:none;"><img src="https://img.shields.io/github/license/putdotio/putio-sdk-swift?style=flat&colorA=000000&colorB=000000" alt="license"></a>
  </p>
</div>

## Installation

Requires Xcode 26 or newer. The Swift Package targets iOS, macOS, Mac Catalyst, tvOS, and watchOS 26.

Install with Swift Package Manager in Xcode using:

```text
https://github.com/putdotio/putio-sdk-swift.git
```

Or add it to `Package.swift` and depend on the `PutioSDK` product:

```swift
dependencies: [
    .package(url: "https://github.com/putdotio/putio-sdk-swift.git", from: "4.0.0")
]
```

CocoaPods is no longer supported: [trunk goes read-only](https://blog.cocoapods.org/CocoaPods-Specs-Repo/) in December 2026, and `3.8.1` is the last `PutioSDK` pod. Switch to Swift Package Manager for `4.0.0` and later.

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

Pass your own `URLSession` for tests, fixtures, or custom session configuration:

```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [MockURLProtocol.self]

let sdk = PutioSDK(
    config: PutioSDKConfig(clientID: "<your-client-id>"),
    urlSession: URLSession(configuration: configuration)
)
```

## Concurrency

Public async methods run on the caller's actor.

- Keep each `PutioSDK` instance, its `config` and `delegate`, and the mutable
  response models on one actor; never capture them in detached or concurrent
  tasks.
- Pass only `Sendable` inputs and immutable results between actors.
- Types passed to `getConfig(as:)` need a `nonisolated` `Decodable`
  conformance.

## Error Handling

SDK errors are `PutioSDKError` values. They conform to `LocalizedError` and expose classification helpers:

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

Media URLs carry the account's download token, never the OAuth token. The download token
authorizes only media endpoints (streams, HLS, downloads, subtitles), so hand it to players,
cast receivers, and ecosystem apps. Fetch it once from account info:

```swift
let account = try await sdk.getAccountInfo(query: PutioAccountInfoQuery(downloadToken: true))
let downloadToken = account.downloadToken
```

The SDK resolves video metadata with the configured OAuth token and builds the HLS URL with the
download token:

```swift
switch try await sdk.resolveVideoPlaybackSource(fileID: 42, downloadToken: downloadToken) {
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
let source = try await sdk.resolveAudioPlaybackSource(fileID: 50, downloadToken: downloadToken)
play(url: source.url, startingAt: source.startFrom)
```

Passing a non-audio file throws `PutioAudioPlaybackResolutionError.unsupportedFileType`.

`PutioFile` and `PutioNextFile` build the same URLs directly with `getStreamURL(downloadToken:)`,
`getHlsStreamURL(downloadToken:)`, `getAudioStreamURL(downloadToken:)`,
`getDownloadURL(downloadToken:)`, and `getMp4DownloadURL(downloadToken:)`.

Media URLs are still bearer credentials for the account's files: never log or persist them.

## App Config

`/config` stores whatever keys an app writes. Declare the shape in the app and let the SDK carry it:

```swift
// The SDK decodes off the caller's actor; `nonisolated` keeps the conformance
// usable there in targets with `MainActor` default isolation.
nonisolated struct AppConfig: Decodable {
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

The [example app](./Example/README.md) runs a minimal `ASWebAuthenticationSession` flow with your own client ID and redirect URI, then fetches the account ([ViewController.swift](./Example/PutioSDK/ViewController.swift)).

Generate a state with `try PutioSDK.generateOAuthState()`, pass it to `getAuthURL(redirectURI:state:)`, then extract the token with `accessToken(fromOAuthCallback:expectedScheme:expectedHost:expectedState:)`, which rejects callbacks whose state does not match.

## Docs

- [Contributing](./CONTRIBUTING.md): setup, checks, live tests, and releases
- [Security policy](https://github.com/putdotio/.github/blob/main/SECURITY.md):
  private vulnerability reports
- [Agent guide](./AGENTS.md)

## License

[MIT](./LICENSE)
