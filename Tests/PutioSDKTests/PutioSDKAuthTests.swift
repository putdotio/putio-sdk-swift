import XCTest

@testable import PutioSDK

final class PutioSDKAuthTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetAuthURLBuildsExpectedQueryItems() throws {
    let sdk = PutioSDK(
      config: PutioSDKConfig(
        clientID: "ios-app", clientName: "put.io TV + Beta", token: "session-token"),
      urlSession: makeTestSession()
    )

    let url = sdk.getAuthURL(
      redirectURI: "putio://oauth/callback", responseType: "code", state: "csrf-token")
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

    XCTAssertEqual(components.path, "/v2/oauth2/authenticate")
    XCTAssertEqual(query["client_id"], "ios-app")
    XCTAssertEqual(query["client_name"], "put.io TV + Beta")
    XCTAssertEqual(query["redirect_uri"], "putio://oauth/callback")
    XCTAssertEqual(query["response_type"], "code")
    XCTAssertEqual(query["state"], "csrf-token")
  }

  func testGenerateOAuthStateProducesURLSafeHighEntropyValue() throws {
    let state = try PutioSDK.generateOAuthState()
    let secondState = try PutioSDK.generateOAuthState()

    XCTAssertGreaterThanOrEqual(state.count, 32)
    XCTAssertNotEqual(state, secondState)
    XCTAssertFalse(state.contains("+"))
    XCTAssertFalse(state.contains("/"))
    XCTAssertFalse(state.contains("="))
    XCTAssertThrowsError(try PutioSDK.generateOAuthState(byteCount: 0)) { error in
      XCTAssertEqual(error as? PutioOAuthStateError, .invalidByteCount)
    }
  }

  func testOAuthCallbackParserValidatesCallbackAndStateBeforeReturningToken() throws {
    let sdk = PutioSDK(
      config: PutioSDKConfig(
        clientID: "ios-app", clientName: "put.io TV + Beta", token: "session-token"),
      urlSession: makeTestSession()
    )
    let callbackURL = try XCTUnwrap(
      URL(string: "putioswift://auth#access_token=token-123&state=csrf-token"))

    let token = try sdk.accessToken(
      fromOAuthCallback: callbackURL,
      expectedScheme: "putioswift",
      expectedHost: "auth",
      expectedState: "csrf-token"
    )

    XCTAssertEqual(token, "token-123")
    XCTAssertThrowsError(
      try sdk.accessToken(
        fromOAuthCallback: callbackURL,
        expectedScheme: "putioswift",
        expectedHost: "auth",
        expectedState: "wrong-state"
      )
    ) { error in
      XCTAssertEqual(error as? PutioOAuthCallbackError, .invalidState)
    }
    XCTAssertThrowsError(
      try sdk.accessToken(
        fromOAuthCallback: callbackURL,
        expectedScheme: "putioswift",
        expectedHost: "other",
        expectedState: "csrf-token"
      )
    ) { error in
      XCTAssertEqual(error as? PutioOAuthCallbackError, .invalidCallbackURL)
    }
  }

  func testAuthAndTwoFactorEndpointsDecodeTypedResponses() async throws {
    var seenPaths: [String] = []

    try installMockRequestHandler { request in
      let path = request.url?.path ?? ""
      seenPaths.append(path)

      switch path {
      case "/v2/oauth2/oob/code":
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "app_id" })?.value, "ios-app")
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "client_name" })?.value,
          "put.io TV + Beta")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(
            #"{"code":"code-123","qr_code_url":"https://api.put.io/v2/oauth2/oob/qr/code-123"}"#
              .utf8)
        )
      case "/v2/oauth2/oob/code/code-123":
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"oauth_token":"oauth-token-456"}"#.utf8)
        )
      case "/v2/oauth2/validate":
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token external-token")
        let payload = """
          {
            "result": true,
            "token_id": 44,
            "token_scope": "stream",
            "user_id": 12
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/oauth/grants/logout":
        XCTAssertEqual(request.httpMethod, "POST")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/two_factor/generate/totp":
        XCTAssertEqual(request.httpMethod, "POST")
        let payload = """
          {
            "secret": "secret-123",
            "uri": "otpauth://totp/put.io",
            "recovery_codes": {
              "created_at": "2026-04-23T10:00:00Z",
              "codes": [
                { "code": "rc-1", "used_at": null }
              ]
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/two_factor/verify/totp":
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "oauth_token" })?.value,
          "two-factor-token")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["code"], "123456")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"token":"verified-token","user_id":12}"#.utf8)
        )
      case "/v2/two_factor/recovery_codes":
        let payload = """
          {
            "recovery_codes": {
              "created_at": "2026-04-23T10:00:00Z",
              "codes": [
                { "code": "rc-1", "used_at": "2026-04-22T10:00:00Z" },
                { "code": "rc-2", "used_at": null }
              ]
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/two_factor/recovery_codes/refresh":
        XCTAssertEqual(request.httpMethod, "POST")
        let payload = """
          {
            "recovery_codes": {
              "created_at": "2026-04-24T10:00:00Z",
              "codes": [
                { "code": "rc-3", "used_at": null }
              ]
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      default:
        XCTFail("Unexpected auth path \(path)")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(
        clientID: "ios-app", clientName: "put.io TV + Beta", token: "session-token"),
      urlSession: makeTestSession()
    )

    let authCode = try await sdk.getAuthCode()
    let token = try await sdk.checkAuthCodeMatch(code: authCode.code)
    let validation = try await sdk.validateToken(token: "external-token")
    let logout = try await sdk.logout()
    let generated = try await sdk.generateTOTP()
    let verified = try await sdk.verifyTOTP(
      twoFactorScopedToken: "two-factor-token", code: "123456")
    let recoveryCodes = try await sdk.getRecoveryCodes()
    let refreshedRecoveryCodes = try await sdk.regenerateRecoveryCodes()

    XCTAssertEqual(authCode.code, "code-123")
    XCTAssertEqual(
      authCode.qrCodeURL?.absoluteString, "https://api.put.io/v2/oauth2/oob/qr/code-123")
    XCTAssertEqual(token, "oauth-token-456")
    XCTAssertTrue(validation.result)
    XCTAssertEqual(validation.tokenID, Optional(44))
    XCTAssertEqual(validation.tokenScope, Optional("stream"))
    XCTAssertEqual(validation.userID, Optional(12))
    XCTAssertEqual(logout.status, "OK")
    XCTAssertEqual(generated.secret, "secret-123")
    XCTAssertEqual(generated.uri, "otpauth://totp/put.io")
    XCTAssertEqual(generated.recoveryCodes.codes.first?.code, "rc-1")
    XCTAssertEqual(verified.token, "verified-token")
    XCTAssertEqual(verified.userID, 12)
    XCTAssertEqual(recoveryCodes.createdAt, "2026-04-23T10:00:00Z")
    XCTAssertEqual(recoveryCodes.codes.count, 2)
    XCTAssertEqual(recoveryCodes.codes.first?.usedAt, "2026-04-22T10:00:00Z")
    XCTAssertEqual(refreshedRecoveryCodes.codes.map(\.code), ["rc-3"])
    XCTAssertEqual(
      seenPaths,
      [
        "/v2/oauth2/oob/code",
        "/v2/oauth2/oob/code/code-123",
        "/v2/oauth2/validate",
        "/v2/oauth/grants/logout",
        "/v2/two_factor/generate/totp",
        "/v2/two_factor/verify/totp",
        "/v2/two_factor/recovery_codes",
        "/v2/two_factor/recovery_codes/refresh",
      ]
    )
  }

  func testCheckAuthCodeMatchReturnsNilWhileCodeIsPending() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth2/oob/code/PENDING")
      XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":null}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV", token: "session-token"),
      urlSession: makeTestSession()
    )

    let token = try await sdk.checkAuthCodeMatch(code: "PENDING")

    XCTAssertNil(token)
  }

  func testAwaitDeviceCodeAuthorizationPollsUntilTokenArrives() async throws {
    let counter = PollCounter()
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth2/oob/code/PENDING")
      XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
      let attempt = counter.increment()
      let payload = attempt < 3 ? #"{"oauth_token":null}"# : #"{"oauth_token":"tv-token"}"#
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )

    let authorization = try await sdk.awaitDeviceCodeAuthorization(
      code: "PENDING", pollInterval: .milliseconds(5))

    XCTAssertEqual(authorization, .authorized(token: "tv-token"))
    XCTAssertEqual(counter.value, 3)
  }

  func testAwaitDeviceCodeAuthorizationSurfacesExpiryAsTypedState() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth2/oob/code/STALE")
      return (
        makeHTTPResponse(for: request, statusCode: 404),
        Data(#"{"error_type":"NotFound","error_message":"Code not found","status_code":404}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )

    let delegate = RecordingDelegate()
    sdk.delegate = delegate

    let authorization = try await sdk.awaitDeviceCodeAuthorization(
      code: "STALE", pollInterval: .milliseconds(5))

    XCTAssertEqual(authorization, .expired)
    XCTAssertEqual(delegate.errors.count, 0, "expected expiry must not reach the delegate")
  }

  func testAwaitDeviceCodeAuthorizationClampsPollIntervalToOneSecond() async throws {
    let counter = PollCounter()
    try installMockRequestHandler { request in
      let attempt = counter.increment()
      let payload = attempt < 2 ? #"{"oauth_token":null}"# : #"{"oauth_token":"tv-token"}"#
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )

    let clock = ContinuousClock()
    let start = clock.now
    _ = try await sdk.awaitDeviceCodeAuthorization(code: "PENDING", pollInterval: .zero)

    XCTAssertGreaterThanOrEqual(clock.now - start, PutioSDK.minimumDeviceCodePollInterval)
    XCTAssertEqual(counter.value, 2)
  }

  func testDeviceCodeAuthorizationRedactsTokenFromDescriptions() {
    let authorization = PutioDeviceCodeAuthorization.authorized(token: "secret-token")

    XCTAssertFalse(authorization.description.contains("secret-token"))
    XCTAssertFalse(authorization.debugDescription.contains("secret-token"))
    XCTAssertFalse(String(reflecting: authorization).contains("secret-token"))
    XCTAssertFalse("\(authorization)".contains("secret-token"))
    let mirrored = authorization.customMirror.children.map { "\($0.value)" }.joined()
    XCTAssertFalse(mirrored.contains("secret-token"))
    XCTAssertEqual(
      PutioDeviceCodeAuthorization.expired.description, "PutioDeviceCodeAuthorization.expired")
  }

  func testAwaitDeviceCodeAuthorizationRethrowsOtherFailures() async throws {
    try installMockRequestHandler { request in
      (makeHTTPResponse(for: request, statusCode: 500), Data(#"{"status":"ERROR"}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )

    let delegate = RecordingDelegate()
    sdk.delegate = delegate

    do {
      _ = try await sdk.awaitDeviceCodeAuthorization(code: "BROKEN", pollInterval: .milliseconds(5))
      XCTFail("Expected a server failure to propagate")
    } catch let error as PutioSDKError {
      XCTAssertEqual(error.statusCode, 500)
    }
    XCTAssertEqual(delegate.errors.map(\.statusCode), [500])
  }

  func testAwaitDeviceCodeAuthorizationStopsWhenCancelled() async throws {
    let counter = PollCounter()
    try installMockRequestHandler { request in
      _ = counter.increment()
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":null}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )

    let task = Task {
      try await sdk.awaitDeviceCodeAuthorization(code: "PENDING", pollInterval: .seconds(60))
    }
    while counter.value == 0 {
      await Task.yield()
    }
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation to propagate")
    } catch is CancellationError {
    }
    XCTAssertEqual(counter.value, 1)
  }

  func testAwaitDeviceCodeAuthorizationDiscardsResultWhenCancelledMidPoll() async throws {
    // The handler is installed before the polling task exists, and it looks the task up
    // through a box, so the first request can never race a missing handler.
    let pollingTask = TaskBox<PutioDeviceCodeAuthorization>()
    try installMockRequestHandler { request in
      // Cancel while the poll is producing a success, so the result is already in hand
      // when the method reaches its post-poll cancellation check.
      pollingTask.cancel()
      return (
        makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":"tv-token"}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )
    let task = pollingTask.start {
      try await sdk.awaitDeviceCodeAuthorization(code: "READY", pollInterval: .seconds(60))
    }

    do {
      let authorization = try await task.value
      XCTFail("Expected cancellation to win over \(authorization)")
    } catch is CancellationError {
    }
  }

  func testAuthModelsDecodeGracefulDefaults() throws {
    let decoder = JSONDecoder()

    let authCode = try decoder.decode(PutioAuthCode.self, from: Data(#"{}"#.utf8))
    let validation = try decoder.decode(PutioTokenValidationResult.self, from: Data(#"{}"#.utf8))
    let recoveryCodes = try decoder.decode(
      PutioTwoFactorRecoveryCodes.self, from: Data(#"{}"#.utf8))
    let verification = try decoder.decode(PutioVerifyTOTPResult.self, from: Data(#"{}"#.utf8))

    XCTAssertEqual(authCode.code, "")
    XCTAssertNil(authCode.qrCodeURL)
    XCTAssertFalse(validation.result)
    XCTAssertNil(validation.tokenID)
    XCTAssertNil(validation.tokenScope)
    XCTAssertNil(validation.userID)
    XCTAssertEqual(recoveryCodes.createdAt, "")
    XCTAssertTrue(recoveryCodes.codes.isEmpty)
    XCTAssertEqual(verification.token, "")
    XCTAssertEqual(verification.userID, 0)
  }
}

private final class PollCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }

  func increment() -> Int {
    lock.lock()
    defer { lock.unlock() }
    count += 1
    return count
  }
}

private final class RecordingDelegate: PutioSDKDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [PutioSDKError] = []

  var errors: [PutioSDKError] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  func onPutioSDKError(error: PutioSDKError) {
    lock.lock()
    recorded.append(error)
    lock.unlock()
  }
}

private final class TaskBox<Success: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var task: Task<Success, Error>?
  private var cancelRequested = false

  func start(_ operation: @escaping @Sendable () async throws -> Success) -> Task<Success, Error> {
    lock.lock()
    defer { lock.unlock() }
    let task = Task(operation: operation)
    self.task = task
    if cancelRequested {
      task.cancel()
    }
    return task
  }

  func cancel() {
    lock.lock()
    defer { lock.unlock() }
    cancelRequested = true
    task?.cancel()
  }
}
