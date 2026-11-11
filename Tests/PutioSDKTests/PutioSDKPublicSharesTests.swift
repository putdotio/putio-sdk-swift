import XCTest

@testable import PutioSDK

final class PutioSDKPublicSharesTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testListDecodesEverySharedFileAndAMissingExpiryAsNil() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v2/public_share/list")
      let payload = """
        {
          "status": "OK",
          "public_shares": [
            \(publicShareJSON(id: 21)),
            {
              "id": 22,
              "token": "secret-token-22",
              "push_token": "secret-token-22",
              "created_at": "2026-09-02T10:00:00",
              "expiration_date": null,
              "owner": {"name": "altay"},
              "user_file": {"id": 6, "name": "Season 1", "file_type": "FOLDER"}
            }
          ]
        }
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let shares = try await makeSDK().listPublicShares()

    XCTAssertEqual(shares.map(\.id), [21, 22])
    XCTAssertEqual(shares[0].expirationDate, "2026-10-01T10:00:00")
    XCTAssertEqual(shares[0].createdAt, "2026-09-01T10:00:00")
    XCTAssertEqual(
      shares[0].userFile, PutioPublicShareFile(id: 5, name: "Movie.mkv", fileType: .video))
    XCTAssertNil(shares[1].expirationDate)
    XCTAssertEqual(shares[1].userFile.fileType, .folder)
    XCTAssertEqual(shares[1].token.value, "secret-token-22")
  }

  func testCreatePostsTheFileIDAndRedactsTheTokens() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v2/public_share/5")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"status":"OK","public_share":\#(publicShareJSON(id: 21))}"#.utf8)
      )
    }

    let share = try await makeSDK().createPublicShare(fileID: 5)

    XCTAssertEqual(share.id, 21)
    XCTAssertEqual(share.token.value, "secret-token")
    XCTAssertEqual(share.pushToken.value, "secret-push-token")
    XCTAssertEqual(share.owner, PutioPublicShareOwner(name: "altay"))
    XCTAssertEqual(share.userFile.id, 5)
    for description in [
      String(describing: share),
      String(reflecting: share),
      dumpOutput(share),
    ] {
      XCTAssertFalse(description.contains("secret"), description)
      XCTAssertTrue(description.contains("<redacted public share token>"), description)
    }
  }

  func testDeleteSendsADeleteForTheShareID() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.url?.path, "/v2/public_share/21")
      XCTAssertNil(requestBodyData(for: request))
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }

    let response = try await makeSDK().deletePublicShare(id: 21)

    XCTAssertEqual(response.status, "OK")
  }

  func testCreateRefusalSurfacesAsATypedRefusal() async throws {
    let cases: [(Int, String, PutioPublicShareRefusal)] = [
      (403, "PUBLIC_SHARE_NOT_ALLOWED_PLAN", .planNotAllowed),
      (400, "PUBLIC_SHARE_FOLDER_ROOT_NOT_ALLOWED", .rootFolderNotAllowed),
      (403, "PUBLIC_SHARE_SINGLE_FILE_LIMIT_EXCEEDED", .singleFileLimitExceeded),
      (403, "PUBLIC_SHARE_FOLDER_LINK_COUNT_LIMIT_EXCEEDED", .folderLinkLimitExceeded),
      (403, "PUBLIC_SHARE_FOLDER_MAX_SIZE_LIMIT_EXCEEDED", .folderSizeLimitExceeded),
      (403, "PUBLIC_SHARE_FOLDER_MAX_CHILDREN_LIMIT_EXCEEDED", .folderChildrenLimitExceeded),
      (403, "PUBLIC_SHARE_DAILY_TOTAL_LINK_COUNT_EXCEEDED", .dailyLinkLimitExceeded),
      (403, "PUBLIC_SHARE_WEEKLY_TOTAL_LINK_COUNT_EXCEEDED", .weeklyLinkLimitExceeded),
    ]

    for (statusCode, errorType, refusal) in cases {
      try installMockRequestHandler { request in
        let payload = """
          {
            "status": "ERROR",
            "status_code": \(statusCode),
            "error_type": "\(errorType)",
            "error_message": "\(errorType)",
            "error_uri": "http://api.put.io/v2/docs",
            "error_id": null,
            "extra": {"limit": 10, "current": 10}
          }
          """
        return (makeHTTPResponse(for: request, statusCode: statusCode), Data(payload.utf8))
      }

      do {
        _ = try await makeSDK().createPublicShare(fileID: 5)
        XCTFail("\(errorType) should throw")
      } catch let error as PutioSDKError {
        XCTAssertEqual(error.publicShareRefusal, refusal, errorType)
        XCTAssertEqual(error.statusCode, statusCode, errorType)
        XCTAssertTrue(refusal.isKnown, errorType)
      }
    }
  }

  func testOtherFailuresCarryNoRefusal() async throws {
    try installMockRequestHandler { request in
      let payload = """
        {"status":"ERROR","status_code":404,"error_type":"NotFound","error_message":"File not found"}
        """
      return (makeHTTPResponse(for: request, statusCode: 404), Data(payload.utf8))
    }

    do {
      _ = try await makeSDK().createPublicShare(fileID: 5)
      XCTFail("a missing file should throw")
    } catch let error as PutioSDKError {
      XCTAssertNil(error.publicShareRefusal)
      XCTAssertTrue(error.isNotFound)
    }
    XCTAssertFalse(PutioPublicShareRefusal(rawValue: "PUBLIC_SHARE_SOMETHING_NEW").isKnown)
  }

  func testShareWithoutIDOrTokenIsADecodingFailure() async throws {
    let malformed = [
      #"{"token":"secret-token","push_token":"secret-push-token","created_at":"2026-09-01T10:00:00","expiration_date":"2026-10-01T10:00:00","owner":{"name":"altay"},"user_file":{"id":5,"name":"Movie.mkv","file_type":"VIDEO"}}"#,
      #"{"id":21,"push_token":"secret-push-token","created_at":"2026-09-01T10:00:00","expiration_date":"2026-10-01T10:00:00","owner":{"name":"altay"},"user_file":{"id":5,"name":"Movie.mkv","file_type":"VIDEO"}}"#,
      #"{"id":21,"token":"","push_token":"secret-push-token","created_at":"2026-09-01T10:00:00","expiration_date":"2026-10-01T10:00:00","owner":{"name":"altay"},"user_file":{"id":5,"name":"Movie.mkv","file_type":"VIDEO"}}"#,
      #"{"id":21,"token":null,"push_token":"secret-push-token","created_at":"2026-09-01T10:00:00","expiration_date":"2026-10-01T10:00:00","owner":{"name":"altay"},"user_file":{"id":5,"name":"Movie.mkv","file_type":"VIDEO"}}"#,
    ]

    for share in malformed {
      try installMockRequestHandler { request in
        (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"status":"OK","public_shares":[\#(share)]}"#.utf8)
        )
      }

      do {
        _ = try await makeSDK().listPublicShares()
        XCTFail("\(share) should not decode")
      } catch let error as PutioSDKError {
        XCTAssertTrue(error.isDecodingFailure, share)
      }
    }
  }

  private func makeSDK() -> PutioSDK {
    PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )
  }
}

private func publicShareJSON(id: Int) -> String {
  """
  {
    "id": \(id),
    "token": "secret-token",
    "push_token": "secret-push-token",
    "created_at": "2026-09-01T10:00:00",
    "expiration_date": "2026-10-01T10:00:00",
    "owner": {"name": "altay"},
    "user_file": {"id": 5, "name": "Movie.mkv", "file_type": "VIDEO"}
  }
  """
}

private func dumpOutput<T>(_ value: T) -> String {
  var output = ""
  dump(value, to: &output)
  return output
}
