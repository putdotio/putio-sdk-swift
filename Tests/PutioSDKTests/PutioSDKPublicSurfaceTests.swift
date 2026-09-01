import PutioSDK
import XCTest

final class PutioSDKPublicSurfaceTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testPublicInitializerAcceptsCustomURLSession() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/config")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"config":{"chromecast_playback_type":"hls"}}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let config = try await sdk.getConfig()

    XCTAssertEqual(config.chromecastPlaybackType, .hls)
  }

  func testVideoPlaybackValuesCanBeConstructedByPackageConsumers() throws {
    let source = PutioVideoPlaybackSource(
      url: try XCTUnwrap(
        URL(
          string:
            "https://example.test/video.m3u8?subtitle_key=all&oauth_token=token-123")),
      startFrom: 37
    )
    let resolution = PutioVideoPlaybackResolution.ready(source)

    XCTAssertEqual(resolution, .ready(source))
    for description in [
      String(describing: source),
      String(reflecting: source),
      String(describing: resolution),
      String(reflecting: resolution),
      dumpOutput(source),
      dumpOutput(resolution),
    ] {
      XCTAssertFalse(description.contains("token-123"))
      XCTAssertTrue(description.contains("redacted"))
    }
  }

  func testVideoPlaybackResolverIsAvailableToPackageConsumers() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42")
      let payload = """
        {
          "file": {
            "id": 42,
            "name": "Episode.mkv",
            "parent_id": 7,
            "size": 100,
            "created_at": "2026-04-20T10:00:00Z",
            "updated_at": "2026-04-20T10:00:00Z",
            "file_type": "VIDEO",
            "need_convert": false,
            "start_from": 37
          }
        }
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let resolution: PutioVideoPlaybackResolution =
      try await sdk.resolveVideoPlaybackSource(fileID: 42)

    guard case .ready(let source) = resolution else {
      return XCTFail("Expected the public resolver to return a ready source")
    }
    XCTAssertEqual(source.startFrom, 37)
    XCTAssertEqual(source.url.path, "/v2/files/42/hls/media.m3u8")
  }

  func testOptionalNextFileIsAvailableToPackageConsumers() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/next-file")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"next_file":null}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let nextFile: PutioNextFile? =
      try await sdk.findNextFileIfAvailable(fileID: 42, fileType: .video)

    XCTAssertNil(nextFile)
  }
}

private func dumpOutput<T>(_ value: T) -> String {
  var output = ""
  dump(value, to: &output)
  return output
}
