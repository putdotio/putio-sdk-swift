import XCTest

@testable import PutioSDK

final class PutioSDKTransportTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetAccountInfoParsesResponseThroughSharedTransport() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token token-123")
      XCTAssertEqual(request.url?.path, "/v2/account/info")

      let payload = """
        {
          "info": {
            "user_id": 1,
            "username": "alice",
            "mail": "alice@example.com",
            "avatar_url": "https://example.com/avatar.png",
            "user_hash": "hash",
            "features": {
              "beta": true
            },
            "download_token": "download-token",
            "trash_size": 0,
            "account_active": true,
            "files_will_be_deleted_at": "",
            "password_last_changed_at": "",
            "disk": {
              "avail": 100,
              "size": 200,
              "used": 100
            },
            "settings": {
              "tunnel_route_name": "",
              "next_episode": true,
              "start_from": true,
              "history_enabled": true,
              "trash_enabled": true,
              "sort_by": "name",
              "show_optimistic_usage": false,
              "two_factor_enabled": false,
              "hide_subtitles": false,
              "dont_autoselect_subtitles": false
            }
          }
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let account = try await sdk.getAccountInfo()

    XCTAssertEqual(account.username, "alice")
    XCTAssertEqual(account.disk.available, 100)
    XCTAssertTrue(account.settings.historyEnabled)
  }

  // Companion to #52: the delegate crosses the executor hop as a weak reference, so a
  // delegate released while a request is in flight is neither kept alive nor called.
  // The config snapshot itself has no deterministic unit proof: the mock transport only
  // observes a request after the SDK has already read `config`, so an ordering test
  // cannot distinguish the on-actor snapshot from the old off-actor read. That shape is
  // enforced structurally by scripts/check-transport-isolation.sh in `make verify`.
  func testInFlightRequestDoesNotRetainReleasedDelegate() async throws {
    let gate = RequestGate()
    try installMockRequestHandler { request in
      gate.markRequestStarted()
      try gate.waitUntilReleased()
      return (makeHTTPResponse(for: request, statusCode: 500), Data(#"{"status":"ERROR"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )
    var delegate: RecordingDelegate? = RecordingDelegate()
    weak var weakDelegate = delegate
    sdk.delegate = delegate

    async let response = sdk.logout()
    try gate.waitUntilRequestStarted()
    delegate = nil
    XCTAssertNil(weakDelegate, "in-flight request must not retain the delegate")
    gate.release()

    do {
      _ = try await response
      XCTFail("Expected HTTP 500 to surface as an error")
    } catch let error as PutioSDKError {
      XCTAssertEqual(error.statusCode, 500)
    }
    XCTAssertNil(sdk.delegate)
  }

  // docs/ARCHITECTURE.md contract: delegate callbacks come from the global executor,
  // never inline on the caller's actor. Calling from the main actor makes "not on the
  // main thread" a faithful proxy for "off the caller's actor".
  @MainActor
  func testDelegateCallbacksArriveOffTheCallerActor() async throws {
    try installMockRequestHandler { request in
      (makeHTTPResponse(for: request, statusCode: 500), Data(#"{"status":"ERROR"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )
    let delegate = ThreadRecordingDelegate()
    sdk.delegate = delegate

    do {
      _ = try await sdk.getAccountInfo()
      XCTFail("Expected HTTP 500 to surface as an error")
    } catch let error as PutioSDKError {
      XCTAssertEqual(error.statusCode, 500)
    }

    XCTAssertEqual(delegate.callbacks.map(\.statusCode), [500])
    XCTAssertEqual(delegate.callbacks.map(\.onMainThread), [false])
  }

  func testGetFileSurfacesTypedHttpErrors() async throws {
    try installMockRequestHandler { request in
      let payload = """
        {
          "status": "ERROR",
          "status_code": 404,
          "error_type": "NOT_FOUND",
          "message": "file not found"
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 404), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.getFile(fileID: 99)
      XCTFail("Expected getFile to fail")
    } catch let error as PutioSDKError {
      switch error.type {
      case .httpError(let statusCode, let errorType):
        XCTAssertEqual(statusCode, 404)
        XCTAssertEqual(errorType, "NOT_FOUND")
        XCTAssertEqual(error.message, "file not found")
        XCTAssertEqual(error.errorDescription, "file not found")
        XCTAssertTrue(error.failureReason?.contains("HTTP 404") == true)
        XCTAssertTrue(error.failureReason?.contains("NOT_FOUND") == true)
        XCTAssertEqual(
          error.recoverySuggestion,
          "Verify the resource identifier and retry. The item may already be deleted or moved.")
      default:
        XCTFail("Expected an httpError, got \(error.type)")
      }
    }
  }

  func testUnknownFileTypePreservesRawValue() throws {
    let file = try JSONDecoder().decode(
      PutioFile.self,
      from: Data(
        """
        {
          "id": 1,
          "name": "Mystery",
          "icon": "icon",
          "parent_id": 0,
          "size": 0,
          "created_at": "2026-04-20T10:00:00Z",
          "updated_at": "2026-04-20T10:00:00Z",
          "is_shared": false,
          "file_type": "BOOK"
        }
        """.utf8))

    XCTAssertEqual(file.type.rawValue, "BOOK")
    XCTAssertFalse(file.type.isKnown)
  }

  func testSaveAccountSettingsPostsJsonAndDecodesOkResponse() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v2/account/settings")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Bool])
      XCTAssertEqual(json["history_enabled"], false)
      XCTAssertEqual(json["hide_subtitles"], true)

      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.saveAccountSettings(
      .patch(
        PutioAccountSettingsPatch(
          historyEnabled: false,
          hideSubtitles: true
        )
      )
    )

    XCTAssertEqual(response.status, "OK")
  }

  func testMoveFilesDecodesStructuredMoveErrors() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v2/files/move")
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["file_ids"] as? String, "9,10")
      XCTAssertEqual(json["parent_id"] as? Int, 7)

      let payload = """
        {
          "status": "OK",
          "errors": [
            {
              "error_type": "OWNER_CHECK_FAILED",
              "id": 10,
              "name": "Shared file",
              "status_code": 403
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.moveFiles(fileIDs: [9, 10], parentID: 7)

    XCTAssertEqual(response.status, "OK")
    XCTAssertEqual(response.errors.count, 1)
    XCTAssertEqual(response.errors.first?.errorType, "OWNER_CHECK_FAILED")
    XCTAssertEqual(response.errors.first?.statusCode, 403)
  }

  func testSendIFTTTEventPostsEventPayload() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v2/ifttt-client/event")
      let body = try XCTUnwrap(requestBodyData(for: request))
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["event_type"] as? String, "playback_started")
      let ingredients = try XCTUnwrap(json["ingredients"] as? [String: Any])
      XCTAssertEqual(ingredients["file_id"] as? Int, 42)
      XCTAssertEqual(ingredients["file_name"] as? String, "Movie")
      XCTAssertEqual(ingredients["file_type"] as? String, "VIDEO")

      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.sendIFTTTEvent(
      event: PutioIFTTTPlaybackEvent(
        eventType: "playback_started",
        ingredients: PutioIFTTTPlaybackEventIngredients(
          fileId: 42, fileName: "Movie", fileType: "VIDEO")
      )
    )

    XCTAssertEqual(response.status, "OK")
  }
}

private final class RequestGate: @unchecked Sendable {
  private let started = DispatchSemaphore(value: 0)
  private let released = DispatchSemaphore(value: 0)
  private let timeout: DispatchTimeInterval = .seconds(5)

  func markRequestStarted() {
    started.signal()
  }

  func waitUntilRequestStarted() throws {
    guard started.wait(timeout: .now() + timeout) == .success else {
      throw RequestGateTimeout(stage: "request start")
    }
  }

  func waitUntilReleased() throws {
    guard released.wait(timeout: .now() + timeout) == .success else {
      throw RequestGateTimeout(stage: "release")
    }
  }

  func release() {
    released.signal()
  }
}

private struct RequestGateTimeout: Error, CustomStringConvertible {
  let stage: String
  var description: String { "RequestGate timed out waiting for \(stage)" }
}

private final class RecordingDelegate: PutioSDKDelegate {
  func onPutioSDKError(error: PutioSDKError) {}
}

private final class ThreadRecordingDelegate: PutioSDKDelegate, @unchecked Sendable {
  struct Callback {
    let statusCode: Int?
    let onMainThread: Bool
  }

  private let lock = NSLock()
  private var recorded: [Callback] = []

  var callbacks: [Callback] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  func onPutioSDKError(error: PutioSDKError) {
    lock.lock()
    recorded.append(Callback(statusCode: error.statusCode, onMainThread: Thread.isMainThread))
    lock.unlock()
  }
}
