import Foundation
import Security

public enum PutioOAuthCallbackError: Error, LocalizedError, Equatable, Sendable {
  case invalidCallbackURL
  case invalidState
  case missingAccessToken

  public var errorDescription: String? {
    switch self {
    case .invalidCallbackURL:
      return "The OAuth callback URL did not match the expected app callback."
    case .invalidState:
      return "The OAuth callback state did not match the pending sign-in state."
    case .missingAccessToken:
      return "The OAuth callback did not include an access token."
    }
  }
}

public enum PutioOAuthStateError: Error, LocalizedError, Equatable, Sendable {
  case invalidByteCount
  case generationFailed(OSStatus)

  public var errorDescription: String? {
    switch self {
    case .invalidByteCount:
      return "OAuth state byte count must be greater than zero."
    case .generationFailed:
      return "The SDK could not generate a secure OAuth state."
    }
  }
}

extension PutioSDK {
  public static func generateOAuthState(byteCount: Int = 32) throws -> String {
    guard byteCount > 0 else {
      throw PutioOAuthStateError.invalidByteCount
    }

    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = bytes.withUnsafeMutableBytes { buffer -> OSStatus in
      guard let baseAddress = buffer.baseAddress else {
        return errSecParam
      }

      return SecRandomCopyBytes(kSecRandomDefault, byteCount, baseAddress)
    }
    guard status == errSecSuccess else {
      throw PutioOAuthStateError.generationFailed(status)
    }

    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  public func getAuthURL(redirectURI: String, responseType: String = "token", state: String) -> URL
  {
    var url = URLComponents(string: "\(self.config.baseURL)/oauth2/authenticate")

    url?.queryItems = [
      URLQueryItem(name: "client_id", value: self.config.clientID),
      URLQueryItem(name: "client_name", value: self.config.clientName),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_type", value: responseType),
      URLQueryItem(name: "state", value: state),
    ]

    guard let authURL = url?.url else {
      preconditionFailure("Unable to build put.io auth URL")
    }

    return authURL
  }

  @available(
    *, deprecated,
    message:
      "Generate and pass a high-entropy state value, for example try PutioSDK.generateOAuthState()."
  )
  public func getAuthURL(redirectURI: String, responseType: String = "token") -> URL {
    getAuthURL(redirectURI: redirectURI, responseType: responseType, state: "")
  }

  public func accessToken(
    fromOAuthCallback callbackURL: URL,
    expectedScheme: String,
    expectedHost: String,
    expectedState: String
  ) throws -> String {
    guard
      callbackURL.scheme?.caseInsensitiveCompare(expectedScheme) == .orderedSame,
      callbackURL.host?.caseInsensitiveCompare(expectedHost) == .orderedSame
    else {
      throw PutioOAuthCallbackError.invalidCallbackURL
    }

    var urlComponents = URLComponents()
    urlComponents.query = callbackURL.fragment
    let queryItems = urlComponents.queryItems ?? []

    guard
      !expectedState.isEmpty,
      queryItems.first(where: { $0.name == "state" })?.value == expectedState
    else {
      throw PutioOAuthCallbackError.invalidState
    }

    guard let token = queryItems.first(where: { $0.name == "access_token" })?.value, !token.isEmpty
    else {
      throw PutioOAuthCallbackError.missingAccessToken
    }

    return token
  }

  public func getAuthCode() async throws -> PutioAuthCode {
    let query = [
      "app_id": PutioRequestValue.string(self.config.clientID),
      "client_name": PutioRequestValue.string(self.config.clientName),
    ]

    return try await request(
      "/oauth2/oob/code",
      headers: ["Authorization": ""],
      query: query,
      as: PutioAuthCode.self
    )
  }

  public func checkAuthCodeMatch(code: String) async throws -> String? {
    try await checkAuthCodeMatch(code: code, isExpectedFailure: { _ in false })
  }

  private func checkAuthCodeMatch(
    code: String, isExpectedFailure: @escaping @Sendable (PutioSDKError) -> Bool
  ) async throws -> String? {
    let envelope = try await request(
      "/oauth2/oob/code/\(code)",
      headers: ["Authorization": ""],
      isExpectedFailure: isExpectedFailure,
      as: PutioOAuthTokenEnvelope.self
    )
    return envelope.oauthToken
  }

  /// Polls `/oauth2/oob/code/{code}` until the user approves the code on put.io,
  /// the code expires, or the calling task is cancelled.
  ///
  /// The backend answers `oauth_token: null` while the code is pending and HTTP 404
  /// once it is unknown or expired, so expiry surfaces as `.expired` instead of a
  /// raw not-found error, and that expected 404 is not reported to `delegate`. Any
  /// other transport or API failure is rethrown unchanged and reaches the delegate
  /// from the transport's global executor as usual.
  ///
  /// Cancelling the calling task surfaces as `CancellationError` at the next
  /// cancellation point: before each poll, after it completes, during the sleep between
  /// polls, or while a poll request is in flight (URLSession reports the latter as
  /// `URLError.cancelled`, which is normalized here). A poll that has already produced
  /// a result when cancellation arrives is discarded in favour of `CancellationError`.
  ///
  /// `pollInterval` is clamped to at least one second so a misconfigured or
  /// nonpositive value cannot hammer the endpoint into rate limiting.
  public func awaitDeviceCodeAuthorization(
    code: String, pollInterval: Duration = .seconds(3)
  ) async throws -> PutioDeviceCodeAuthorization {
    let interval = max(pollInterval, Self.minimumDeviceCodePollInterval)

    while true {
      try Task.checkCancellation()

      let authorization: PutioDeviceCodeAuthorization?
      do {
        if let token = try await checkAuthCodeMatch(code: code, isExpectedFailure: \.isNotFound) {
          authorization = .authorized(token: token)
        } else {
          authorization = nil
        }
      } catch let error as PutioSDKError where error.isNotFound {
        authorization = .expired
      } catch let error as PutioSDKError where Task.isCancelled {
        throw CancellationError()
      }

      await deviceCodePollObserver?(.pollCompleted)
      try Task.checkCancellation()
      if let authorization {
        return authorization
      }

      await deviceCodePollObserver?(.willSleep)
      try await deviceCodePollClock.sleep(for: interval)
    }
  }

  static let minimumDeviceCodePollInterval: Duration = .seconds(1)

  public func validateToken(token: String) async throws -> PutioTokenValidationResult {
    try await request(
      "/oauth2/validate", headers: ["Authorization": "Token \(token)"],
      as: PutioTokenValidationResult.self)
  }

  public func logout() async throws -> PutioOKResponse {
    try await request("/oauth/grants/logout", method: .post, as: PutioOKResponse.self)
  }

  // MARK: two-factor
  public func generateTOTP() async throws -> PutioGenerateTOTPResult {
    try await request("/two_factor/generate/totp", method: .post, as: PutioGenerateTOTPResult.self)
  }
  public func verifyTOTP(twoFactorScopedToken: String, code: String) async throws
    -> PutioVerifyTOTPResult
  {
    try await request(
      "/two_factor/verify/totp",
      method: .post,
      headers: ["Authorization": ""],
      query: ["oauth_token": .string(twoFactorScopedToken)],
      body: ["code": .string(code)],
      as: PutioVerifyTOTPResult.self
    )
  }
  public func getRecoveryCodes() async throws -> PutioTwoFactorRecoveryCodes {
    let envelope = try await request(
      "/two_factor/recovery_codes", as: PutioRecoveryCodesEnvelope.self)
    return envelope.recoveryCodes
  }
  public func regenerateRecoveryCodes() async throws -> PutioTwoFactorRecoveryCodes {
    let envelope = try await request(
      "/two_factor/recovery_codes/refresh", method: .post, as: PutioRecoveryCodesEnvelope.self)
    return envelope.recoveryCodes
  }
}

// Boundaries of one `awaitDeviceCodeAuthorization` iteration, reported through the
// internal `deviceCodePollObserver` seam.
enum PutioDeviceCodePollEvent: Sendable {
  case pollCompleted
  case willSleep
}

private struct PutioOAuthTokenEnvelope: Decodable {
  let oauthToken: String?

  enum CodingKeys: String, CodingKey {
    case oauthToken = "oauth_token"
  }
}

private struct PutioRecoveryCodesEnvelope: Decodable {
  let recoveryCodes: PutioTwoFactorRecoveryCodes

  enum CodingKeys: String, CodingKey {
    case recoveryCodes = "recovery_codes"
  }
}
