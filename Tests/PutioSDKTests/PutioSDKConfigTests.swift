import XCTest

@testable import PutioSDK

final class PutioSDKConfigTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetConfigDecodesNativeConfigWithDefaults() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v2/config")

      let payload = """
        {
          "status": "OK",
          "config": {
            "chromecast_playback_type": "mp4"
          }
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let config = try await sdk.getConfig()

    XCTAssertEqual(config.chromecastPlaybackType, .mp4)
  }

  func testConfigFallsBackToHLSForMissingEmptyOrUnknownPlaybackTypes() throws {
    let decoder = JSONDecoder()

    let missing = try decoder.decode(PutioConfig.self, from: Data("{}".utf8))
    let empty = try decoder.decode(
      PutioConfig.self, from: Data(#"{"chromecast_playback_type":""}"#.utf8))
    let unknown = try decoder.decode(
      PutioConfig.self, from: Data(#"{"chromecast_playback_type":"bogus"}"#.utf8))

    XCTAssertEqual(missing.chromecastPlaybackType, .hls)
    XCTAssertEqual(empty.chromecastPlaybackType, .hls)
    XCTAssertEqual(unknown.chromecastPlaybackType, .hls)
  }

  func testSaveConfigPostsTypedValue() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.url?.path, "/v2/config/chromecast_playback_type")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
      XCTAssertEqual(json["value"], "hls")

      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.setChromecastPlaybackType(.hls)

    XCTAssertEqual(response.status, "OK")
  }
}
