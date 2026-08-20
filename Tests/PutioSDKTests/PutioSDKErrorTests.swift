import XCTest

@testable import PutioSDK

final class PutioSDKErrorTests: XCTestCase {
  private final class DelegateProbe: PutioSDKDelegate {
    var errors: [PutioSDKError] = []

    func onPutioSDKError(error: PutioSDKError) {
      errors.append(error)
    }
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testTypedErrorsExposeHelpfulFailureReasonsAndRecovery() {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/files/42",
      method: .get
    )
    let requestInfo = PutioSDKErrorRequestInformation(config: requestConfig)

    let unauthorized = PutioSDKError(
      request: requestInfo,
      statusCode: 401,
      errorType: "UNAUTHORIZED",
      message: "unauthorized",
      underlyingError: URLError(.userAuthenticationRequired),
      responseBody: #"{"status":"ERROR"}"#
    )
    let rateLimited = PutioSDKError(
      request: requestInfo,
      statusCode: 429,
      errorType: nil,
      message: "slow down",
      underlyingError: URLError(.badServerResponse)
    )
    let serverError = PutioSDKError(
      request: requestInfo,
      statusCode: 500,
      errorType: nil,
      message: "server error",
      underlyingError: URLError(.badServerResponse)
    )
    let networkError = PutioSDKError(request: requestInfo, error: URLError(.notConnectedToInternet))
    let decodingError = PutioSDKError(
      request: requestInfo,
      decodingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "broken")),
      responseBody: "{}"
    )
    let unknownError = PutioSDKError(request: requestInfo, unknownError: URLError(.badURL))

    XCTAssertEqual(unauthorized.errorDescription, "unauthorized")
    XCTAssertTrue(unauthorized.failureReason?.contains("HTTP 401") == true)
    XCTAssertEqual(
      unauthorized.recoverySuggestion,
      "Sign in again or refresh the access token, then retry the request.")
    XCTAssertEqual(
      rateLimited.recoverySuggestion,
      "Wait briefly before retrying. put.io is rate-limiting this request.")
    XCTAssertEqual(
      serverError.recoverySuggestion,
      "Retry the request. If it keeps failing, inspect the attached status code and response body.")
    XCTAssertEqual(networkError.failureReason, "The SDK could not reach put.io.")
    XCTAssertTrue(networkError.recoverySuggestion?.contains("Check connectivity") == true)
    XCTAssertEqual(
      decodingError.failureReason,
      "put.io responded, but the payload did not match the SDK contract.")
    XCTAssertTrue(decodingError.recoverySuggestion?.contains("Upgrade the SDK") == true)
    XCTAssertEqual(unknownError.failureReason, "The SDK failed before it could classify the error.")
    XCTAssertTrue(unknownError.recoverySuggestion?.contains("underlying error") == true)
  }

  func testTypedErrorsExposeConsumerClassificationHelpers() {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/files/42",
      method: .get
    )
    let requestInfo = PutioSDKErrorRequestInformation(config: requestConfig)

    let unauthorized = PutioSDKError(
      request: requestInfo,
      statusCode: 401,
      errorType: "invalid_scope",
      message: "unauthorized",
      underlyingError: URLError(.userAuthenticationRequired)
    )
    let notFound = PutioSDKError(
      request: requestInfo,
      statusCode: 404,
      errorType: "NOT_FOUND",
      message: "missing",
      underlyingError: URLError(.badServerResponse)
    )
    let rateLimited = PutioSDKError(
      request: requestInfo,
      statusCode: 429,
      errorType: nil,
      message: "slow down",
      underlyingError: URLError(.badServerResponse)
    )
    let serverError = PutioSDKError(
      request: requestInfo,
      statusCode: 503,
      errorType: nil,
      message: "unavailable",
      underlyingError: URLError(.badServerResponse)
    )
    let networkError = PutioSDKError(request: requestInfo, error: URLError(.notConnectedToInternet))
    let decodingError = PutioSDKError(
      request: requestInfo,
      decodingError: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "broken")),
      responseBody: "{}"
    )

    XCTAssertEqual(unauthorized.statusCode, 401)
    XCTAssertEqual(unauthorized.apiErrorType, "invalid_scope")
    XCTAssertTrue(unauthorized.isAuthenticationFailure)
    XCTAssertFalse(unauthorized.isRetryable)
    XCTAssertTrue(unauthorized.matches(statusCode: 401))
    XCTAssertTrue(unauthorized.matches(errorType: "invalid_scope"))
    XCTAssertTrue(unauthorized.matches(statusCode: 401, errorType: "invalid_scope"))
    XCTAssertFalse(unauthorized.matches(statusCode: 403, errorType: "invalid_scope"))

    XCTAssertTrue(notFound.isNotFound)
    XCTAssertFalse(notFound.isRetryable)

    XCTAssertTrue(rateLimited.isRateLimited)
    XCTAssertTrue(rateLimited.isRetryable)
    XCTAssertTrue(serverError.isRetryable)

    XCTAssertNil(networkError.statusCode)
    XCTAssertNil(networkError.apiErrorType)
    XCTAssertTrue(networkError.isNetworkFailure)
    XCTAssertTrue(networkError.isRetryable)

    XCTAssertTrue(decodingError.isDecodingFailure)
    XCTAssertFalse(decodingError.isRetryable)
    XCTAssertFalse(decodingError.matches())
  }

  func testErrorDescriptionsRedactSensitiveRequestData() {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(
        baseURL: "https://api.put.io/v2", clientID: "ios-app", token: "config-token"),
      url: "/two_factor/verify/totp",
      method: .post,
      headers: ["Authorization": "Bearer header-token"],
      query: ["oauth_token": "query-token", "password": "password"],
      body: [
        "client_secret": "client-secret",
        "current_password": "current_password",
        "profile": .object(["totp_secret": "totp-secret"]),
        "name": "safe-name",
      ]
    )
    let requestInfo = PutioSDKErrorRequestInformation(config: requestConfig)
    let error = PutioSDKError(
      request: requestInfo,
      statusCode: 401,
      errorType: "invalid_scope",
      message: "invalid scope",
      underlyingError: URLError(.userAuthenticationRequired)
    )

    let description = String(describing: error)

    XCTAssertFalse(description.contains("config-token"))
    XCTAssertFalse(description.contains("header-token"))
    XCTAssertFalse(description.contains("query-token"))
    XCTAssertFalse(description.contains("client-secret"))
    XCTAssertFalse(description.contains("password"))
    XCTAssertFalse(description.contains("current_password"))
    XCTAssertFalse(description.contains("totp-secret"))
    XCTAssertTrue(description.contains("safe-name"))
    XCTAssertTrue(description.contains("<redacted>"))
    XCTAssertFalse(error.failureReason?.contains("query-token") == true)
  }

  func testErrorDescriptionRedactsRawResponseBodyButKeepsExplicitProperty() {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      url: "/account/info",
      method: .get
    )
    let requestInfo = PutioSDKErrorRequestInformation(config: requestConfig)
    let rawBody = """
      {
        "email": "person@example.com",
        "access_token": "response-token",
        "download_url": "https://example.com/file?oauth_token=url-token"
      }
      """
    let error = PutioSDKError(
      request: requestInfo,
      statusCode: 403,
      errorType: "forbidden",
      message:
        #"safe failure for person@example.com with access_token=response-token and {"client_secret":"message-secret"}"#,
      underlyingError: URLError(.userAuthenticationRequired),
      responseBody: rawBody
    )

    let description = String(describing: error)
    let debugDescription = String(reflecting: error)

    XCTAssertFalse(description.contains("person@example.com"))
    XCTAssertFalse(description.contains("response-token"))
    XCTAssertFalse(description.contains("url-token"))
    XCTAssertFalse(description.contains("message-secret"))
    XCTAssertFalse(debugDescription.contains("person@example.com"))
    XCTAssertFalse(debugDescription.contains("response-token"))
    XCTAssertFalse(debugDescription.contains("message-secret"))
    XCTAssertFalse(error.errorDescription?.contains("person@example.com") == true)
    XCTAssertFalse(error.errorDescription?.contains("response-token") == true)
    XCTAssertFalse(error.errorDescription?.contains("message-secret") == true)
    XCTAssertTrue(description.contains("HTTP 403") || description.contains("statusCode: 403"))
    XCTAssertTrue(description.contains("forbidden"))
    XCTAssertTrue(description.contains("safe failure"))
    XCTAssertTrue(description.contains("<redacted body,"))
    XCTAssertEqual(error.responseBody, rawBody)
  }

  func testTransportNotifiesDelegateForNetworkAndDecodingFailures() async throws {
    let delegate = DelegateProbe()

    MockURLProtocol.requestHandler = { request in
      switch request.url?.path {
      case "/v2/account/info":
        throw URLError(.notConnectedToInternet)
      default:
        XCTFail("Unexpected path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )
    sdk.delegate = delegate

    do {
      _ = try await sdk.getAccountInfo()
      XCTFail("Expected network failure")
    } catch let error as PutioSDKError {
      switch error.type {
      case .networkError:
        break
      default:
        XCTFail("Expected networkError, got \(error.type)")
      }
    }

    MockURLProtocol.requestHandler = { request in
      switch request.url?.path {
      case "/v2/account/info":
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"info":{}}"#.utf8))
      default:
        XCTFail("Unexpected path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    do {
      _ = try await sdk.getAccountInfo()
      XCTFail("Expected decoding failure")
    } catch let error as PutioSDKError {
      switch error.type {
      case .decodingError:
        XCTAssertEqual(error.responseBody, #"{"info":{}}"#)
      default:
        XCTFail("Expected decodingError, got \(error.type)")
      }
    }

    XCTAssertEqual(delegate.errors.count, 2)
  }

  func testInvalidBaseURLSurfacesUnknownError() async throws {
    let sdk = PutioSDK(
      config: PutioSDKConfig(baseURL: "http://[::1", clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.getAccountInfo()
      XCTFail("Expected invalid URL to fail")
    } catch let error as PutioSDKError {
      switch error.type {
      case .unknownError:
        XCTAssertEqual(error.message, URLError(.badURL).localizedDescription)
      default:
        XCTFail("Expected unknownError, got \(error.type)")
      }
    }
  }
}
