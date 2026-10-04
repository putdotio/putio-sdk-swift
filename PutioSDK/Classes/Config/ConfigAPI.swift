import Foundation

// `/config` is an app-owned document: put.io stores whatever keys a client
// writes and returns them as they were stored. Each app declares its own
// `Codable` shape and keys, the way the TypeScript SDK's `readConfigWith` and
// `setConfigKey` leave the schema to the caller; the SDK never hardcodes keys.
extension PutioSDK {
  /// Reads the whole config document into the app's own type. Missing keys are
  /// the app's concern: give them defaults in the type's decoder. The SDK decodes
  /// off the caller's actor, so the type's `Decodable` conformance must be
  /// nonisolated; the `SendableMetatype` requirement makes the compiler flag an
  /// actor-isolated one.
  public func getConfig<Config: Decodable & SendableMetatype>(as type: Config.Type) async throws
    -> Config
  {
    let envelope = try await request("/config", as: PutioConfigDocumentEnvelope<Config>.self)
    return envelope.config
  }

  /// Replaces the whole config document. `config` must encode to a JSON
  /// object; anything else fails with `PutioConfigInputError.nonObjectConfig`
  /// before a request is sent.
  public func writeConfig<Config: Encodable>(_ config: Config) async throws -> PutioOKResponse {
    let requestConfig = configRequestConfig(path: "/config", method: .put)
    let value = try encodeConfigValue(config, requestConfig: requestConfig)
    guard case .object = value else {
      throw PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig),
        unknownError: PutioConfigInputError.nonObjectConfig)
    }
    return try await request(
      "/config", method: .put, body: ["config": value], as: PutioOKResponse.self)
  }

  /// Reads one key of the config document. Same nonisolated-conformance rule as
  /// `getConfig(as:)`.
  public func getConfigValue<Value: Decodable & SendableMetatype>(key: String, as type: Value.Type)
    async throws
    -> Value
  {
    let path = try configKeyPath(key, method: .get)
    let envelope = try await request(path, as: PutioConfigValueEnvelope<Value>.self)
    return envelope.value
  }

  /// Writes one key of the config document without touching the others.
  public func setConfigValue<Value: Encodable>(key: String, _ value: Value) async throws
    -> PutioOKResponse
  {
    let path = try configKeyPath(key, method: .put)
    let requestConfig = configRequestConfig(path: path, method: .put)
    let encoded = try encodeConfigValue(value, requestConfig: requestConfig)
    // The body field is always `value`, so the key decides whether it is sensitive.
    return try await request(
      path, method: .put, body: ["value": encoded],
      redactedBodyKeys: sensitiveKey(key) ? ["value"] : [], as: PutioOKResponse.self)
  }

  /// Removes one key from the config document.
  public func deleteConfigValue(key: String) async throws -> PutioOKResponse {
    let path = try configKeyPath(key, method: .delete)
    return try await request(path, method: .delete, as: PutioOKResponse.self)
  }

  @available(*, deprecated, message: "Declare the app's config type and call getConfig(as:).")
  public func getConfig() async throws -> PutioConfig {
    try await getConfig(as: PutioConfig.self)
  }

  @available(*, deprecated, message: "Call setConfigValue(key:_:) with the app's own key.")
  public func saveConfig(_ update: PutioConfigUpdate) async throws -> PutioOKResponse {
    try await setConfigValue(key: update.key, update.value)
  }

  @available(*, deprecated, message: "Call setConfigValue(key:_:) with the app's own key.")
  public func setChromecastPlaybackType(_ playbackType: PutioChromecastPlaybackType) async throws
    -> PutioOKResponse
  {
    try await setConfigValue(key: "chromecast_playback_type", playbackType)
  }

  // Keys are path segments; anything the server would split or reject stays
  // a caller error instead of a mysterious 404.
  private func configKeyPath(_ key: String, method: PutioHTTPMethod) throws -> String {
    guard !key.isEmpty, !key.contains("/"), key != ".", key != "..",
      key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
      let encoded = key.addingPercentEncoding(withAllowedCharacters: .putioConfigKey)
    else {
      let requestConfig = configRequestConfig(path: "/config/\(key)", method: method)
      throw PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig),
        unknownError: PutioConfigInputError.invalidKey(key))
    }
    return "/config/\(encoded)"
  }

  private func configRequestConfig(path: String, method: PutioHTTPMethod) -> PutioSDKRequestConfig {
    PutioSDKRequestConfig(apiConfig: config, url: path, method: method)
  }

  private func encodeConfigValue<Value: Encodable>(
    _ value: Value, requestConfig: PutioSDKRequestConfig
  ) throws -> PutioRequestValue {
    do {
      return try PutioRequestValue(encoding: value)
    } catch {
      throw PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig), unknownError: error)
    }
  }
}

/// Why a config call was rejected before any request was sent.
public enum PutioConfigInputError: Error, Equatable, Sendable {
  /// The key was empty, a dot segment, or contained whitespace or a path
  /// separator.
  case invalidKey(String)
  /// The value encoded to something other than JSON. An `EncodingError` from
  /// the value itself, such as `Double.nan`, is passed through as it is.
  case unencodableValue
  /// `writeConfig` was given a value that did not encode to a JSON object,
  /// such as a scalar, an array, or `nil`.
  case nonObjectConfig
}

private struct PutioConfigDocumentEnvelope<Config: Decodable>: Decodable {
  let config: Config
}

private struct PutioConfigValueEnvelope<Value: Decodable>: Decodable {
  let value: Value
}

extension CharacterSet {
  fileprivate static let putioConfigKey: CharacterSet = {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove("/")
    return allowed
  }()
}
