import XCTest

@testable import PutioSDK

final class PutioSDKRequestConfigTests: XCTestCase {
  func testSDKTokenMutationHelpers() {
    let sdk = PutioSDK(config: PutioSDKConfig(clientID: "ios-app"))

    sdk.setToken(token: "token-123")
    XCTAssertEqual(sdk.config.token, "token-123")

    sdk.clearToken()
    XCTAssertEqual(sdk.config.token, "")
  }

  func testRequestConfigAddsTokenAuthorizationAndEncodesQuery() {
    let request = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/files/list",
      method: .get,
      query: ["parent_id": 0, "name": "hello world"]
    )

    XCTAssertEqual(request.headers.value(for: "authorization"), "token token-123")

    let components = URLComponents(string: request.url)
    let queryItems = components?.queryItems ?? []
    XCTAssertEqual(components?.scheme, "https")
    XCTAssertEqual(components?.host, "api.put.io")
    XCTAssertEqual(components?.path, "/v2/files/list")
    XCTAssertEqual(queryItems.first(where: { $0.name == "parent_id" })?.value, "0")
    XCTAssertEqual(queryItems.first(where: { $0.name == "name" })?.value, "hello world")
  }

  func testRequestConfigHandlesNativeHeadersAndMethodBodies() {
    var headers = ["authorization": "old-token"]
    headers.setValue("new-token", forHeader: "Authorization")
    XCTAssertEqual(headers.value(for: "authorization"), "new-token")
    XCTAssertEqual(headers.value(for: "AUTHORIZATION"), "new-token")

    let request = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app"),
      url: "/files/delete",
      method: .delete,
      body: ["file_ids": "1,2"]
    )

    XCTAssertNil(request.body)
    XCTAssertFalse(request.debugDescription.isEmpty)
    XCTAssertFalse(PutioSDKErrorRequestInformation(config: request).debugDescription.isEmpty)
  }

  func testRequestValuesEncodeNestedJSONAndQueryStrings() throws {
    let parameters: PutioRequestParameters = [
      "name": "movie",
      "duration": .double(12.5),
      "ids": .array([1, "two"]),
      "metadata": .object(["enabled": .bool(true)]),
    ]

    let data = try JSONEncoder().encode(parameters)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(json["name"] as? String, "movie")
    XCTAssertEqual(json["duration"] as? Double, 12.5)
    let ids = try XCTUnwrap(json["ids"] as? [Any])
    XCTAssertEqual(ids.first as? Int, 1)
    XCTAssertEqual(ids.last as? String, "two")
    XCTAssertEqual((json["metadata"] as? [String: Bool])?["enabled"], true)

    XCTAssertEqual(PutioRequestValue.double(12.5).queryValue, "12.5")
    XCTAssertEqual(PutioRequestValue.array([1, "two"]).queryValue, "1,two")
    XCTAssertEqual(PutioRequestValue.object(["nested": "value"]).queryValue, "")
  }

  func testRequestConfigPreservesExplicitAuthorizationHeader() {
    let request = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/account/info",
      method: .get,
      headers: ["Authorization": "Bearer custom-token"]
    )

    XCTAssertEqual(request.headers.value(for: "authorization"), "Bearer custom-token")
  }

  func testRequestConfigCanSuppressConfiguredAuthorizationHeader() {
    let request = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/two_factor/verify/totp",
      method: .post,
      headers: ["Authorization": ""]
    )

    XCTAssertEqual(request.headers.value(for: "authorization"), "")
  }
}
