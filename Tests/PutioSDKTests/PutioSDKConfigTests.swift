import XCTest

@testable import PutioSDK

/// An app-owned config shape, the way a consumer declares one.
private struct AppConfig: Codable, Equatable {
  var autoplayNextVideo = false
  var chromecastPlaybackType = "hls"
  var subtitleStyle: SubtitleStyle?

  struct SubtitleStyle: Codable, Equatable {
    var fontPercent: Double
    var edgeStyle: String?
  }

  enum CodingKeys: String, CodingKey {
    case autoplayNextVideo = "autoplay_next_video"
    case chromecastPlaybackType = "chromecast_playback_type"
    case subtitleStyle = "subtitle_style"
  }

  init(
    autoplayNextVideo: Bool = false, chromecastPlaybackType: String = "hls",
    subtitleStyle: SubtitleStyle? = nil
  ) {
    self.autoplayNextVideo = autoplayNextVideo
    self.chromecastPlaybackType = chromecastPlaybackType
    self.subtitleStyle = subtitleStyle
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    autoplayNextVideo =
      try container.decodeIfPresent(Bool.self, forKey: .autoplayNextVideo) ?? false
    chromecastPlaybackType =
      try container.decodeIfPresent(String.self, forKey: .chromecastPlaybackType) ?? "hls"
    subtitleStyle = try container.decodeIfPresent(SubtitleStyle.self, forKey: .subtitleStyle)
  }
}

final class PutioSDKConfigTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetConfigDecodesTheAppsOwnTypeWithItsDefaults() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v2/config")
      let payload = """
        {"status":"OK","config":{"autoplay_next_video":true,"unrelated_web_key":"ignored",
         "subtitle_style":{"fontPercent":1.5}}}
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }
    let config = try await makeSDK().getConfig(as: AppConfig.self)
    XCTAssertEqual(
      config,
      AppConfig(
        autoplayNextVideo: true, chromecastPlaybackType: "hls",
        subtitleStyle: .init(fontPercent: 1.5, edgeStyle: nil)))
  }

  func testWriteConfigSendsTheWholeDocument() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.url?.path, "/v2/config")
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      let config = try XCTUnwrap(json["config"] as? [String: Any])
      XCTAssertEqual(config["autoplay_next_video"] as? Bool, true)
      XCTAssertEqual(config["chromecast_playback_type"] as? String, "mp4")
      XCTAssertEqual((config["subtitle_style"] as? [String: Any])?["fontPercent"] as? Double, 2)
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }
    let response = try await makeSDK().writeConfig(
      AppConfig(
        autoplayNextVideo: true, chromecastPlaybackType: "mp4",
        subtitleStyle: .init(fontPercent: 2, edgeStyle: nil)))
    XCTAssertEqual(response.status, "OK")
  }

  func testGetConfigValueReadsOneKeyAsTheRequestedType() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v2/config/dismissed.extensions_message")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"status":"OK","value":true}"#.utf8)
      )
    }
    let value = try await makeSDK().getConfigValue(
      key: "dismissed.extensions_message", as: Bool.self)
    XCTAssertTrue(value)
  }

  func testSetConfigValueEncodesScalarsObjectsAndNull() async throws {
    var bodies: [String] = []
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.url?.path, "/v2/config/autoplay_next_video")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      let body = try XCTUnwrap(requestBodyData(for: request))
      bodies.append(try XCTUnwrap(String(data: body, encoding: .utf8)))
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }
    let sdk = makeSDK()
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", true)
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", 3)
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", 1.5)
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", "mp4")
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", ["a", "b"])
    _ = try await sdk.setConfigValue(
      key: "autoplay_next_video", AppConfig.SubtitleStyle(fontPercent: 1, edgeStyle: "raised"))
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", Optional<String>.none)
    _ = try await sdk.setConfigValue(key: "autoplay_next_video", UInt64.max)
    // Raw bodies, because JSONSerialization hands back one NSNumber for both
    // `true` and `1`.
    XCTAssertEqual(bodies[0], #"{"value":true}"#)
    XCTAssertEqual(bodies[1], #"{"value":3}"#)
    XCTAssertEqual(bodies[2], #"{"value":1.5}"#)
    XCTAssertEqual(bodies[3], #"{"value":"mp4"}"#)
    XCTAssertEqual(bodies[4], #"{"value":["a","b"]}"#)
    XCTAssertTrue(
      bodies[5] == #"{"value":{"fontPercent":1,"edgeStyle":"raised"}}"#
        || bodies[5] == #"{"value":{"edgeStyle":"raised","fontPercent":1}}"#, bodies[5])
    XCTAssertEqual(bodies[6], #"{"value":null}"#)
    XCTAssertEqual(bodies[7], #"{"value":18446744073709551615}"#, "a UInt64 lost precision")
  }

  func testDeleteConfigValueUsesDeleteOnTheKeyPath() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.url?.path, "/v2/config/ui.cursor")
      XCTAssertNil(requestBodyData(for: request))
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }
    let response = try await makeSDK().deleteConfigValue(key: "ui.cursor")
    XCTAssertEqual(response.status, "OK")
  }

  func testInvalidKeysAndUnencodableValuesFailBeforeAnyRequest() async throws {
    try installMockRequestHandler { request in
      XCTFail("unexpected request to \(request.url?.path ?? "")")
      return (makeHTTPResponse(for: request, statusCode: 500), Data())
    }
    let sdk = makeSDK()
    for key in ["", " padded", "a/b", "line\nbreak", "odd key", ".", ".."] {
      do {
        _ = try await sdk.getConfigValue(key: key, as: Bool.self)
        XCTFail("accepted key \(key.debugDescription)")
      } catch let error as PutioSDKError {
        XCTAssertEqual(error.underlyingError as? PutioConfigInputError, .invalidKey(key))
      }
    }
    do {
      _ = try await sdk.setConfigValue(key: "ratio", Double.nan)
      XCTFail("accepted NaN")
    } catch let error as PutioSDKError {
      guard case .unknownError = error.type else { return XCTFail("unexpected \(error.type)") }
      XCTAssertTrue(error.underlyingError is EncodingError, "lost the encoder's own error")
    }
  }

  func testKeysWithReservedCharactersArePercentEncoded() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/config/odd?key")
      XCTAssertEqual(request.url?.absoluteString.hasSuffix("/config/odd%3Fkey"), true)
      return (
        makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK","value":1}"#.utf8)
      )
    }
    let value = try await makeSDK().getConfigValue(key: "odd?key", as: Int.self)
    XCTAssertEqual(value, 1)
  }

  @available(*, deprecated)
  func testDeprecatedTypedConfigStillRidesTheGenericPath() async throws {
    var paths: [String] = []
    try installMockRequestHandler { request in
      paths.append(request.url?.path ?? "")
      if request.httpMethod == "GET" {
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"status":"OK","config":{"chromecast_playback_type":"mp4"}}"#.utf8)
        )
      }
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
      XCTAssertEqual(json["value"], "hls")
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }
    let sdk = makeSDK()
    let config = try await sdk.getConfig()
    XCTAssertEqual(config.chromecastPlaybackType, .mp4)
    _ = try await sdk.setChromecastPlaybackType(.hls)
    XCTAssertEqual(paths, ["/v2/config", "/v2/config/chromecast_playback_type"])
  }

  private func makeSDK() -> PutioSDK {
    PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession())
  }
}
