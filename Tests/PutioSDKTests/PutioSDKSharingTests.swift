import XCTest

@testable import PutioSDK

final class PutioSDKSharingTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  private func makeSDK() -> PutioSDK {
    PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession())
  }

  func testCloneSharedFilesPostsFileIDsAndParentAndReturnsTheCloneID() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/sharing/clone")
      XCTAssertEqual(request.httpMethod, "POST")
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["file_ids"] as? String, "11,12")
      XCTAssertEqual(json["parent_id"] as? Int, 7)
      XCTAssertEqual(json.count, 2)
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"id":321,"status":"OK"}"#.utf8)
      )
    }

    let cloneID = try await makeSDK().cloneSharedFiles(fileIDs: [11, 12], parentID: 7)

    XCTAssertEqual(cloneID, 321)
  }

  func testCloneSharedFilesTargetsTheRootByDefault() async throws {
    try installMockRequestHandler { request in
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["file_ids"] as? String, "11")
      XCTAssertEqual(json["parent_id"] as? Int, 0)
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        Data(#"{"id":322,"status":"OK"}"#.utf8)
      )
    }

    let cloneID = try await makeSDK().cloneSharedFiles(fileIDs: [11])

    XCTAssertEqual(cloneID, 322)
  }

  func testCloneSharedFilesRejectsAResponseWithoutAnID() async throws {
    try installMockRequestHandler { request in
      (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }

    do {
      _ = try await makeSDK().cloneSharedFiles(fileIDs: [11])
      XCTFail("Expected a decoding failure")
    } catch let error as PutioSDKError {
      XCTAssertTrue(error.isDecodingFailure)
      XCTAssertNil(error.sharedFileCloneLimit)
    }
  }

  func testCloneSharedFilesMapsEachLimitErrorToItsTypedLimit() async throws {
    let cases: [(String, PutioSharedFileCloneLimit)] = [
      ("SharedFileCloneConcurrentLimit", .concurrentCopies),
      ("SharedFileCloneTooManyFiles", .tooManyFiles),
      ("SharedFileCloneTooManyChildren", .tooManyChildren),
    ]

    let delegate = CloneDelegate()
    for (errorType, limit) in cases {
      try installMockRequestHandler { request in
        let payload = """
          {"error_type":"\(errorType)","error_message":"400 Bad Request","status_code":400,"status":"ERROR"}
          """
        return (makeHTTPResponse(for: request, statusCode: 400), Data(payload.utf8))
      }

      let sdk = makeSDK()
      sdk.delegate = delegate
      do {
        _ = try await sdk.cloneSharedFiles(fileIDs: [11], parentID: 7)
        XCTFail("Expected \(errorType) to throw")
      } catch let error as PutioSDKError {
        XCTAssertEqual(error.sharedFileCloneLimit, limit, errorType)
        XCTAssertEqual(error.statusCode, 400)
        XCTAssertFalse(error.isRetryable)
      }
    }
    XCTAssertEqual(delegate.count, 0)
  }

  func testOtherFailuresCarryNoCloneLimit() async throws {
    try installMockRequestHandler { request in
      let payload = """
        {"error_type":"BadRequest","error_message":"400 Bad Request","status_code":400,"status":"ERROR"}
        """
      return (makeHTTPResponse(for: request, statusCode: 400), Data(payload.utf8))
    }

    let delegate = CloneDelegate()
    let sdk = makeSDK()
    sdk.delegate = delegate
    do {
      _ = try await sdk.cloneSharedFiles(fileIDs: [11])
      XCTFail("Expected a bad request")
    } catch let error as PutioSDKError {
      XCTAssertEqual(error.apiErrorType, "BadRequest")
      XCTAssertNil(error.sharedFileCloneLimit)
    }
    XCTAssertEqual(delegate.count, 1)
  }

  func testGetCloneInfoDecodesEveryStatus() async throws {
    let responses = [
      #"{"shared_file_clone_status":"NEW","status":"OK"}"#,
      #"{"shared_file_clone_status":"PROCESSING","status":"OK"}"#,
      #"{"shared_file_clone_status":"DONE","status":"OK"}"#,
      #"{"shared_file_clone_status":"ERROR","error_msg":"File(s) size exceed disk limit.","status":"OK"}"#,
      #"{"shared_file_clone_status":"PAUSED","status":"OK"}"#,
      #"{"shared_file_clone_status":null,"status":"OK"}"#,
    ]
    var index = 0
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/sharing/clone/321")
      XCTAssertEqual(request.httpMethod, "GET")
      guard index < responses.count else {
        XCTFail("Unexpected extra request")
        return (makeHTTPResponse(for: request, statusCode: 500), Data())
      }
      defer { index += 1 }
      return (makeHTTPResponse(for: request, statusCode: 200), Data(responses[index].utf8))
    }

    let sdk = makeSDK()
    var infos: [PutioSharedFileCloneInfo] = []
    for _ in responses {
      infos.append(try await sdk.getCloneInfo(cloneID: 321))
    }

    XCTAssertEqual(
      infos,
      [
        PutioSharedFileCloneInfo(status: .new),
        PutioSharedFileCloneInfo(status: .processing),
        PutioSharedFileCloneInfo(status: .done),
        PutioSharedFileCloneInfo(status: .error, errorMessage: "File(s) size exceed disk limit."),
        PutioSharedFileCloneInfo(status: PutioSharedFileCloneStatus(rawValue: "PAUSED")),
        PutioSharedFileCloneInfo(status: PutioSharedFileCloneStatus(rawValue: "")),
      ])
    XCTAssertEqual(infos.map(\.status.isFinished), [false, false, true, true, false, false])
    XCTAssertEqual(infos.map(\.status.isKnown), [true, true, true, true, false, false])
  }

  func testGetCloneInfoRedactsSensitiveValuesInTheErrorMessage() async throws {
    try installMockRequestHandler { request in
      let payload =
        #"{"shared_file_clone_status":"ERROR","error_msg":"Failed https://example.test/cb?oauth_token=leak"}"#
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let info = try await makeSDK().getCloneInfo(cloneID: 9)

    XCTAssertEqual(info.errorMessage, "Failed https://example.test/cb?oauth_token=<redacted>")
  }

  func testGetCloneInfoSurfacesAMissingCloneAsNotFound() async throws {
    try installMockRequestHandler { request in
      let payload = """
        {"error_type":"SHARED_FILE_CLONE_NOT_FOUND","error_message":"Shared file clone not found.","status_code":404,"status":"ERROR"}
        """
      return (makeHTTPResponse(for: request, statusCode: 404), Data(payload.utf8))
    }

    do {
      _ = try await makeSDK().getCloneInfo(cloneID: 9)
      XCTFail("Expected a missing clone")
    } catch let error as PutioSDKError {
      XCTAssertTrue(error.isNotFound)
      XCTAssertEqual(error.apiErrorType, "SHARED_FILE_CLONE_NOT_FOUND")
      XCTAssertNil(error.sharedFileCloneLimit)
    }
  }
}

private final class CloneDelegate: PutioSDKDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var recorded = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  func onPutioSDKError(error: PutioSDKError) {
    lock.lock()
    recorded += 1
    lock.unlock()
  }
}
