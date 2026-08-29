import Foundation

public struct PutioSDKConfig: Sendable {
  public let baseURL: String
  public var token: String
  public var clientID: String
  public var clientSecret: String
  public var clientName: String
  public var timeoutInterval: Double

  public init(
    clientID: String, clientSecret: String = "", clientName: String = "", token: String = "",
    timeoutInterval: Double = 15.0
  ) {
    self.init(
      baseURL: PutioSDK.apiURL,
      clientID: clientID,
      clientSecret: clientSecret,
      clientName: clientName,
      token: token,
      timeoutInterval: timeoutInterval
    )
  }

  public init(
    baseURL: String,
    clientID: String,
    clientSecret: String = "",
    clientName: String = "",
    token: String = "",
    timeoutInterval: Double = 15.0
  ) {
    self.baseURL = baseURL
    self.clientID = clientID
    self.clientSecret = clientSecret
    self.clientName = clientName
    self.token = token
    self.timeoutInterval = timeoutInterval
  }
}

enum PutioHTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"

  var acceptsBody: Bool {
    switch self {
    case .post, .put, .patch:
      return true
    case .get, .delete:
      return false
    }
  }
}

enum PutioRequestValue: Equatable, Encodable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case bool(Bool)
  case array([PutioRequestValue])
  case object(PutioRequestParameters)

  func encode(to encoder: Encoder) throws {
    switch self {
    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .integer(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .double(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .array(let values):
      var container = encoder.unkeyedContainer()
      for value in values {
        try container.encode(value)
      }
    case .object(let values):
      try values.encode(to: encoder)
    }
  }

  var queryValue: String {
    switch self {
    case .string(let value):
      return value
    case .integer(let value):
      return String(value)
    case .double(let value):
      return String(value)
    case .bool(let value):
      return value ? "1" : "0"
    case .array(let values):
      return values.map(\.queryValue).joined(separator: ",")
    case .object:
      return ""
    }
  }
}

extension PutioRequestValue: ExpressibleByStringLiteral {
  init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension PutioRequestValue: ExpressibleByIntegerLiteral {
  init(integerLiteral value: Int) {
    self = .integer(value)
  }
}

extension PutioRequestValue: ExpressibleByFloatLiteral {
  init(floatLiteral value: Double) {
    self = .double(value)
  }
}

extension PutioRequestValue: ExpressibleByBooleanLiteral {
  init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension PutioRequestValue: ExpressibleByArrayLiteral {
  init(arrayLiteral elements: PutioRequestValue...) {
    self = .array(elements)
  }
}

extension PutioRequestValue: ExpressibleByDictionaryLiteral {
  init(dictionaryLiteral elements: (String, PutioRequestValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}

typealias PutioRequestParameters = [String: PutioRequestValue]
typealias PutioHTTPHeaders = [String: String]

extension Dictionary where Key == String, Value == String {
  func value(for headerName: String) -> String? {
    first { key, _ in key.caseInsensitiveCompare(headerName) == .orderedSame }?.value
  }

  mutating func setValue(_ value: String, forHeader headerName: String) {
    if let existingKey = keys.first(where: { $0.caseInsensitiveCompare(headerName) == .orderedSame }
    ) {
      self[existingKey] = value
    } else {
      self[headerName] = value
    }
  }
}

public struct PutioSDKRequestConfig: Sendable {
  private let baseURL: String
  private let path: String
  let method: PutioHTTPMethod
  let headers: PutioHTTPHeaders
  let query: PutioRequestParameters
  let body: PutioRequestParameters?
  let timeoutInterval: Double

  var url: String {
    (try? buildURL().absoluteString) ?? "\(baseURL)\(path)"
  }

  init(
    apiConfig: PutioSDKConfig,
    url: String,
    method: PutioHTTPMethod,
    headers: PutioHTTPHeaders = [:],
    query: PutioRequestParameters = [:],
    body: PutioRequestParameters = [:]
  ) {
    self.baseURL = apiConfig.baseURL
    self.path = url
    self.method = method

    var enhancedHeaders = headers
    if enhancedHeaders.value(for: "authorization") == nil {
      if apiConfig.token != "" {
        enhancedHeaders.setValue("token \(apiConfig.token)", forHeader: "Authorization")
      }
    }

    self.headers = enhancedHeaders
    self.query = query
    self.body = method.acceptsBody ? body : nil
    self.timeoutInterval = apiConfig.timeoutInterval
  }

  func buildURL() throws -> URL {
    let trimmedBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let rawURL = "\(trimmedBaseURL)/\(trimmedPath)"

    guard var components = URLComponents(string: rawURL) else {
      throw URLError(.badURL)
    }

    if !query.isEmpty {
      components.queryItems = query.map { key, value in
        URLQueryItem(name: key, value: value.queryValue)
      }
    }

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    return url
  }
}

extension PutioSDKRequestConfig: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    "PutioSDKRequestConfig(url: \"\(redactedURL)\", method: \(method.rawValue), headers: \(redactedHeaders), query: \(redact(query)), body: \(redact(body ?? [:])))"
  }

  public var debugDescription: String {
    description
  }

  var redactedURL: String {
    guard var components = URLComponents(string: url), let queryItems = components.queryItems else {
      return url
    }

    components.queryItems = queryItems.map { item in
      sensitiveKey(item.name) ? URLQueryItem(name: "<redacted>", value: "<redacted>") : item
    }
    return components.string ?? url
  }

  private var redactedHeaders: PutioHTTPHeaders {
    var redacted: PutioHTTPHeaders = [:]
    for (key, value) in headers {
      redacted[sensitiveKey(key) ? "<redacted>" : key] = sensitiveKey(key) ? "<redacted>" : value
    }
    return redacted
  }
}

extension PutioSDKErrorRequestInformation: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    "PutioSDKErrorRequestInformation(config: \(config))"
  }

  public var debugDescription: String {
    description
  }
}

private func redact(_ parameters: PutioRequestParameters) -> PutioRequestParameters {
  var redacted = PutioRequestParameters()
  for (key, value) in parameters {
    redacted[sensitiveKey(key) ? "<redacted>" : key] =
      sensitiveKey(key) ? "<redacted>" : redact(value)
  }
  return redacted
}

private func redact(_ value: PutioRequestValue) -> PutioRequestValue {
  switch value {
  case .array(let values):
    return .array(values.map(redact))
  case .object(let parameters):
    return .object(redact(parameters))
  case .string, .integer, .double, .bool:
    return value
  }
}

func sensitiveKey(_ key: String) -> Bool {
  let normalized = key.lowercased()
  return normalized == "authorization" || normalized == "password"
    || normalized == "current_password" || normalized == "secret" || normalized == "recovery_codes"
    || normalized == "token" || normalized == "oauth_token" || normalized == "access_token"
    || normalized == "client_secret" || normalized.hasSuffix("_token")
    || normalized.hasSuffix("_secret") || normalized.contains("_secret_")
}

private func redactSensitiveText(_ text: String) -> String {
  let replacements = [
    (
      #"(?i)([?&](?:[^=\s&#"']*token|[^=\s&#"']*secret|password|current_password|recovery_codes)=)[^\s&#"']+"#,
      "$1<redacted>"
    ),
    (
      #"(?i)((?:^|[\s,])(?:[A-Za-z0-9_]*token|[A-Za-z0-9_]*secret|password|current_password|recovery_codes)=)[^\s,]+"#,
      "$1<redacted>"
    ),
    (
      #"(?i)("[^"]*(?:token|secret|password|recovery_codes)[^"]*"\s*:\s*)("[^"]*")"#,
      "$1\"<redacted>\""
    ),
    (#"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, "<redacted>"),
  ]

  return replacements.reduce(text) { result, replacement in
    result.replacingOccurrences(
      of: replacement.0,
      with: replacement.1,
      options: .regularExpression
    )
  }
}

public enum PutioSDKErrorType: Sendable {
  case httpError(statusCode: Int, errorType: String?)
  case networkError
  case decodingError
  case unknownError
}

public struct PutioSDKErrorRequestInformation: Sendable {
  let config: PutioSDKRequestConfig
}

internal struct PutioAPIErrorEnvelope: Decodable {
  let message: String?
  let errorMessage: String?
  let statusCode: Int?
  let errorType: String?

  enum CodingKeys: String, CodingKey {
    case message
    case errorMessage = "error_message"
    case statusCode = "status_code"
    case errorType = "error_type"
  }

  var resolvedMessage: String? {
    message ?? errorMessage
  }
}

public struct PutioSDKError: Error, LocalizedError, CustomStringConvertible,
  CustomDebugStringConvertible, Sendable
{
  public let request: PutioSDKErrorRequestInformation
  public let type: PutioSDKErrorType
  public let message: String
  public let underlyingError: Error
  public let responseBody: String?

  /// HTTP status code for API failures, when the request reached put.io.
  public var statusCode: Int? {
    switch type {
    case .httpError(let statusCode, _):
      return statusCode
    case .networkError, .decodingError, .unknownError:
      return nil
    }
  }

  /// Backend `error_type` value for API failures, when the response included one.
  public var apiErrorType: String? {
    switch type {
    case .httpError(_, let errorType):
      return errorType
    case .networkError, .decodingError, .unknownError:
      return nil
    }
  }

  /// True for authorization and authentication failures that usually require a fresh sign-in or token.
  public var isAuthenticationFailure: Bool {
    statusCode == 401 || statusCode == 403
  }

  /// True when the backend reported that the requested resource was not found.
  public var isNotFound: Bool {
    statusCode == 404
  }

  /// True when put.io is rate-limiting the request.
  public var isRateLimited: Bool {
    statusCode == 429
  }

  /// True when the SDK could not reach put.io due to a transport-level failure.
  public var isNetworkFailure: Bool {
    switch type {
    case .networkError:
      return true
    case .httpError, .decodingError, .unknownError:
      return false
    }
  }

  /// True when put.io responded, but the payload did not match the SDK model contract.
  public var isDecodingFailure: Bool {
    switch type {
    case .decodingError:
      return true
    case .httpError, .networkError, .unknownError:
      return false
    }
  }

  /// True for transient failures where callers can reasonably schedule a retry with backoff.
  public var isRetryable: Bool {
    switch type {
    case .networkError:
      return true
    case .httpError(let statusCode, _):
      return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    case .decodingError, .unknownError:
      return false
    }
  }

  /// Matches an API failure by status code, backend error type, or both.
  public func matches(statusCode: Int? = nil, errorType: String? = nil) -> Bool {
    if let statusCode, self.statusCode != statusCode {
      return false
    }

    if let errorType, self.apiErrorType != errorType {
      return false
    }

    return statusCode != nil || errorType != nil
  }

  public var errorDescription: String? {
    redactedMessage
  }

  public var failureReason: String? {
    switch type {
    case .httpError(let statusCode, let errorType):
      if let errorType, !errorType.isEmpty {
        return
          "put.io rejected \(request.config.method.rawValue) \(request.config.redactedURL) with HTTP \(statusCode) and error type \(errorType)."
      }

      return
        "put.io rejected \(request.config.method.rawValue) \(request.config.redactedURL) with HTTP \(statusCode)."
    case .networkError:
      return "The SDK could not reach put.io."
    case .decodingError:
      return "put.io responded, but the payload did not match the SDK contract."
    case .unknownError:
      return "The SDK failed before it could classify the error."
    }
  }

  public var description: String {
    "PutioSDKError(request: \(request), type: \(type), message: \"\(redactedMessage)\", underlyingError: \(underlyingError), responseBody: \(redactedResponseBodyDescription))"
  }

  public var debugDescription: String {
    description
  }

  public var recoverySuggestion: String? {
    switch type {
    case .httpError(let statusCode, _):
      switch statusCode {
      case 401, 403:
        return "Sign in again or refresh the access token, then retry the request."
      case 404:
        return "Verify the resource identifier and retry. The item may already be deleted or moved."
      case 429:
        return "Wait briefly before retrying. put.io is rate-limiting this request."
      default:
        return
          "Retry the request. If it keeps failing, inspect the attached status code and response body."
      }
    case .networkError:
      return
        "Check connectivity and retry. If you are offline or behind a restrictive network, wait for the connection to recover."
    case .decodingError:
      return
        "Upgrade the SDK or inspect the raw response body to confirm whether the backend contract changed."
    case .unknownError:
      return "Retry the request and inspect the underlying error for operator details."
    }
  }

  init(
    request: PutioSDKErrorRequestInformation,
    statusCode: Int,
    errorType: String?,
    message: String,
    underlyingError: Error,
    responseBody: String? = nil
  ) {
    self.request = request
    self.type = .httpError(statusCode: statusCode, errorType: errorType)
    self.message = message
    self.underlyingError = underlyingError
    self.responseBody = responseBody
  }

  init(request: PutioSDKErrorRequestInformation, error: Error) {
    self.request = request
    self.type = .networkError
    self.message = error.localizedDescription
    self.underlyingError = error
    self.responseBody = nil
  }

  init(request: PutioSDKErrorRequestInformation, decodingError: Error, responseBody: String) {
    self.request = request
    self.type = .decodingError
    self.message = decodingError.localizedDescription
    self.underlyingError = decodingError
    self.responseBody = responseBody
  }

  init(request: PutioSDKErrorRequestInformation, unknownError error: Error) {
    self.request = request
    self.type = .unknownError
    self.message = error.localizedDescription
    self.underlyingError = error
    self.responseBody = nil
  }

  private var redactedResponseBodyDescription: String {
    guard let responseBody else {
      return "nil"
    }

    return "<redacted body, \(responseBody.utf8.count) bytes>"
  }

  private var redactedMessage: String {
    redactSensitiveText(message)
  }
}

public struct PutioOKResponse: Codable, Sendable {
  public let status: String
  public let cursor: String?
  public let skipped: Int?
}
