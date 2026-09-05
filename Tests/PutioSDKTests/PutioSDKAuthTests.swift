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

  // Cancellation during the sleep between polls. The interval sleep runs on a test
  // clock that signals once the SDK is actually suspended inside `sleep`; the test
  // cancels at that point. A sleeper that cannot be interrupted would keep the task
  // alive until the 60s interval elapsed and trip the elapsed bound.
  func testAwaitDeviceCodeAuthorizationStopsWhenCancelledDuringSleep() async throws {
    let counter = PollCounter()
    try installMockRequestHandler { request in
      _ = counter.increment()
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":null}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )
    let sleeper = ObservableSleeper()
    sdk.deviceCodePollSleeper = { interval in
      XCTAssertEqual(interval, .seconds(60))
      try await sleeper.sleep()
    }

    let clock = ContinuousClock()
    let start = clock.now
    let task = Task {
      try await sdk.awaitDeviceCodeAuthorization(code: "PENDING", pollInterval: .seconds(60))
    }
    defer { Task { await sleeper.abandon() } }
    try await sleeper.waitUntilSleeping()
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation to propagate")
    } catch is CancellationError {
    }
    XCTAssertEqual(counter.value, 1)
    XCTAssertLessThan(clock.now - start, .seconds(5), "cancellation must interrupt the sleep")
  }

  // Same contract against the production sleeper. The observer parks at `.willSleep`,
  // is released, and the SDK enters the real `Task.sleep` for a short interval before
  // the test cancels. An uncancellable production sleeper would wait out the whole
  // interval and trip the elapsed bound; a cancellable one returns almost immediately.
  func testAwaitDeviceCodeAuthorizationProductionSleepIsInterruptedByCancellation()
    async throws
  {
    let counter = PollCounter()
    try installMockRequestHandler { request in
      _ = counter.increment()
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":null}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )
    let barrier = PollBarrier()
    sdk.deviceCodePollObserver = { event in
      if event == .willSleep { await barrier.park() }
    }

    let interval = Duration.seconds(3)
    let clock = ContinuousClock()
    let task = Task {
      try await sdk.awaitDeviceCodeAuthorization(code: "PENDING", pollInterval: interval)
    }
    defer { Task { await barrier.abandon() } }
    try await barrier.waitUntilParked()
    let sleepStarted = clock.now
    await barrier.release()
    // Give the SDK time to resume from the observer and suspend inside `Task.sleep`.
    try await Task.sleep(for: .milliseconds(250))
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation to propagate")
    } catch is CancellationError {
    }
    XCTAssertEqual(counter.value, 1)
    XCTAssertLessThan(
      clock.now - sleepStarted, interval, "production sleep must not run to completion")
  }

  // Cancellation after a poll has produced a result. The SDK parks at `.pollCompleted`
  // with `.authorized` already in hand; cancelling there and releasing proves the
  // post-poll cancellation check wins. Removing that check returns `.authorized` here.
  func testAwaitDeviceCodeAuthorizationDiscardsResultWhenCancelledAfterPollCompletes()
    async throws
  {
    try installMockRequestHandler { request in
      (
        makeHTTPResponse(for: request, statusCode: 200), Data(#"{"oauth_token":"tv-token"}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", clientName: "put.io TV"),
      urlSession: makeTestSession()
    )
    let barrier = PollBarrier()
    sdk.deviceCodePollObserver = { event in
      if event == .pollCompleted { await barrier.park() }
    }

    let task = Task {
      try await sdk.awaitDeviceCodeAuthorization(code: "READY", pollInterval: .seconds(60))
    }
    defer { Task { await barrier.abandon() } }
    try await barrier.waitUntilParked()
    task.cancel()
    await barrier.release()

    do {
      let authorization = try await task.value
      XCTFail("Expected cancellation to win over \(authorization)")
    } catch is CancellationError {
    }
  }

  // A non-expiry failure reaches the delegate from the transport's global executor,
  // not on the caller's actor.
  @MainActor
  func testAwaitDeviceCodeAuthorizationForwardsFailuresOffTheCallerActor() async throws {
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
    XCTAssertEqual(delegate.callbacksOnMainThread, [false])
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
  private var mainThreadFlags: [Bool] = []

  var errors: [PutioSDKError] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  var callbacksOnMainThread: [Bool] {
    lock.lock()
    defer { lock.unlock() }
    return mainThreadFlags
  }

  func onPutioSDKError(error: PutioSDKError) {
    lock.lock()
    recorded.append(error)
    mainThreadFlags.append(Thread.isMainThread)
    lock.unlock()
  }
}

// Suspending rendezvous between a test and the SDK's poll observer. `park` suspends the
// SDK until `release`; `waitUntilParked` suspends the test until the SDK has parked.
// Everything suspends rather than blocking, so no cooperative-pool thread is held.
// Stand-in for `Task.sleep` that reports when the SDK is actually suspended inside it
// and honours cancellation the same way `Task.sleep` does: the continuation resumes
// with `CancellationError` when the sleeping task is cancelled, never on its own.
private actor ObservableSleeper {
  private var sleeper: CheckedContinuation<Void, Error>?
  private var waiter: CheckedContinuation<Void, Error>?
  private var isSleeping = false

  func sleep() async throws {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        sleeper = continuation
        isSleeping = true
        waiter?.resume()
        waiter = nil
        // Like a real interval, the sleep eventually ends on its own. Long enough to
        // trip the test's elapsed bound, short enough that a regression fails instead
        // of hanging the suite.
        Task {
          try? await Task.sleep(for: .seconds(6))
          await self.finish()
        }
      }
    } onCancel: {
      Task { await self.cancel() }
    }
  }

  private func finish() {
    sleeper?.resume()
    sleeper = nil
  }

  func waitUntilSleeping() async throws {
    if isSleeping { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      waiter = continuation
      scheduleDeadline(stage: "SDK to enter the poll sleep")
    }
  }

  // Failure cleanup: wake anything still suspended so a failed test reports instead of
  // hanging on a continuation nobody will resume.
  func abandon() {
    waiter?.resume(throwing: RendezvousTimeout(stage: "abandoned sleeper wait"))
    waiter = nil
    sleeper?.resume(throwing: CancellationError())
    sleeper = nil
  }

  private func scheduleDeadline(stage: String) {
    Task {
      try? await Task.sleep(for: .seconds(5))
      await self.expireWaiter(stage: stage)
    }
  }

  private func expireWaiter(stage: String) {
    waiter?.resume(throwing: RendezvousTimeout(stage: stage))
    waiter = nil
  }

  private func cancel() {
    sleeper?.resume(throwing: CancellationError())
    sleeper = nil
  }
}

private actor PollBarrier {
  private var parked: CheckedContinuation<Void, Never>?
  private var waiter: CheckedContinuation<Void, Error>?
  private var isParked = false
  private var isReleased = false

  func park() async {
    isParked = true
    waiter?.resume()
    waiter = nil
    if isReleased { return }
    await withCheckedContinuation { parked = $0 }
  }

  func waitUntilParked() async throws {
    if isParked { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      waiter = continuation
      scheduleDeadline(stage: "SDK to park at the observer")
    }
  }

  func release() {
    isReleased = true
    parked?.resume()
    parked = nil
  }

  // Failure cleanup: wake anything still suspended so a failed test reports instead of
  // hanging on a continuation nobody will resume.
  func abandon() {
    waiter?.resume(throwing: RendezvousTimeout(stage: "abandoned barrier wait"))
    waiter = nil
    release()
  }

  private func scheduleDeadline(stage: String) {
    Task {
      try? await Task.sleep(for: .seconds(5))
      await self.expireWaiter(stage: stage)
    }
  }

  private func expireWaiter(stage: String) {
    waiter?.resume(throwing: RendezvousTimeout(stage: stage))
    waiter = nil
  }
}

// A rendezvous that never happens fails the test loudly after five seconds instead of
// hanging on a continuation nobody will resume.
private struct RendezvousTimeout: Error, CustomStringConvertible {
  let stage: String
  var description: String { "timed out waiting for \(stage)" }
}
