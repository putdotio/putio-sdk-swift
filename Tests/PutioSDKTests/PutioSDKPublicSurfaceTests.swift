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
}
