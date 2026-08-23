import XCTest

@testable import PutioSDK

final class PutioSDKAccountTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testAccountEndpointsDecodeSettingsAndMutationBodies() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      switch request.url?.path {
      case "/v2/account/settings":
        if request.httpMethod == "GET" {
          let payload = """
            {
              "settings": {
                "tunnel_route_name": "eu-west",
                "next_episode": true,
                "start_from": true,
                "history_enabled": true,
                "trash_enabled": true,
                "sort_by": "NAME_ASC",
                "show_optimistic_usage": true,
                "two_factor_enabled": true,
                "hide_subtitles": false,
                "dont_autoselect_subtitles": true
              }
            }
            """
          return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
        }

        XCTFail("saveAccountSettings is covered elsewhere and should not hit this test")
        return (makeHTTPResponse(for: request, statusCode: 500), Data())
      case "/v2/account/clear":
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Bool])
        XCTAssertEqual(json["files"], true)
        XCTAssertEqual(json["history"], false)
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/account/destroy":
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["current_password"], "secret-123")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"status":"OK","skipped":0}"#.utf8)
        )
      default:
        XCTFail("Unexpected account path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let settings = try await sdk.getAccountSettings()
    let cleared = try await sdk.clearAccountData(
      options: PutioAccountClearOptions(files: true, history: false))
    let destroyed = try await sdk.destroyAccount(currentPassword: "secret-123")

    XCTAssertEqual(settings.routeName, "eu-west")
    XCTAssertTrue(settings.historyEnabled)
    XCTAssertTrue(settings.dontAutoSelectSubtitles)
    XCTAssertEqual(cleared.status, "OK")
    XCTAssertEqual(destroyed.status, "OK")
    XCTAssertEqual(destroyed.skipped, 0)
  }

  func testAccountModelsDecodeDefaultsAndClearDataOptionKeysStayStable() throws {
    let decoder = JSONDecoder()

    let settings = try decoder.decode(
      PutioAccount.Settings.self,
      from: Data(
        """
        {
          "sort_by": "NAME_ASC"
        }
        """.utf8
      )
    )
    let account = try decoder.decode(
      PutioAccount.self,
      from: Data(
        """
        {
          "user_id": 1,
          "username": "alice",
          "mail": "alice@example.com",
          "disk": {
            "avail": 100,
            "size": 200,
            "used": 100
          },
          "settings": {
            "sort_by": "NAME_ASC"
          }
        }
        """.utf8
      )
    )

    XCTAssertEqual(settings.routeName, "default")
    XCTAssertFalse(settings.historyEnabled)
    XCTAssertFalse(settings.trashEnabled)
    XCTAssertFalse(settings.twoFactorEnabled)
    XCTAssertEqual(account.avatarURL, "")
    XCTAssertEqual(account.hash, "")
    XCTAssertEqual(account.downloadToken, "")
    XCTAssertEqual(account.trashSize, 0)
    XCTAssertEqual(account.features, [:])
    XCTAssertEqual(account.filesWillBeDeletedAt, "")
    XCTAssertEqual(account.passwordLastChangedAt, "")
    XCTAssertTrue(PutioClearDataOptionKeys.contains("history"))
    XCTAssertTrue(PutioClearDataOptionKeys.contains("trash"))
  }

  func testTypedAccountInputsBuildExpectedParameters() {
    let infoQuery = PutioAccountInfoQuery(
      downloadToken: true,
      features: true,
      intercom: true,
      pas: true,
      platform: "ios",
      profitwell: true,
      pushToken: true
    )
    let settingsPatch = PutioAccountSettingsPatch(
      historyEnabled: false,
      trashEnabled: true,
      hideSubtitles: true,
      dontAutoSelectSubtitles: false,
      tunnelRouteName: "eu-west",
      showOptimisticUsage: true,
      sortBy: "NAME_ASC"
    )
    let twoFactor = PutioTwoFactorSettings(code: "123456", enable: true)
    let clearOptions = PutioAccountClearOptions(
      files: true,
      finishedTransfers: true,
      activeTransfers: true,
      rssFeeds: true,
      rssLogs: true,
      history: true,
      trash: true,
      friends: true
    )

    XCTAssertEqual(infoQuery.parameters["download_token"], .integer(1))
    XCTAssertEqual(infoQuery.parameters["features"], .integer(1))
    XCTAssertEqual(infoQuery.parameters["intercom"], .integer(1))
    XCTAssertEqual(infoQuery.parameters["pas"], .integer(1))
    XCTAssertEqual(infoQuery.parameters["platform"], .string("ios"))
    XCTAssertEqual(infoQuery.parameters["profitwell"], .integer(1))
    XCTAssertEqual(infoQuery.parameters["push_token"], .integer(1))
    XCTAssertEqual(settingsPatch.parameters["history_enabled"], .bool(false))
    XCTAssertEqual(settingsPatch.parameters["trash_enabled"], .bool(true))
    XCTAssertEqual(settingsPatch.parameters["hide_subtitles"], .bool(true))
    XCTAssertEqual(settingsPatch.parameters["dont_autoselect_subtitles"], .bool(false))
    XCTAssertEqual(settingsPatch.parameters["tunnel_route_name"], .string("eu-west"))
    XCTAssertEqual(settingsPatch.parameters["show_optimistic_usage"], .bool(true))
    XCTAssertEqual(settingsPatch.parameters["sort_by"], .string("NAME_ASC"))
    XCTAssertEqual(twoFactor.parameters["code"], .string("123456"))
    XCTAssertEqual(twoFactor.parameters["enable"], .bool(true))
    XCTAssertEqual(
      PutioAccountSettingsUpdate.patch(settingsPatch).parameters["history_enabled"], .bool(false))
    XCTAssertEqual(
      PutioAccountSettingsUpdate.username("alice").parameters["username"], .string("alice"))
    XCTAssertEqual(
      PutioAccountSettingsUpdate.mail(currentPassword: "old", mail: "a@example.com").parameters[
        "mail"], .string("a@example.com"))
    XCTAssertEqual(
      PutioAccountSettingsUpdate.password(currentPassword: "old", password: "new").parameters[
        "password"], .string("new"))
    XCTAssertNotNil(
      PutioAccountSettingsUpdate.twoFactor(twoFactor).parameters["two_factor_enabled"])
    XCTAssertEqual(clearOptions.parameters["files"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["finished_transfers"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["active_transfers"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["rss_feeds"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["rss_logs"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["history"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["trash"], .bool(true))
    XCTAssertEqual(clearOptions.parameters["friends"], .bool(true))
  }
}
