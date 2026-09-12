import Foundation

// `/config` is an app-owned document: put.io stores whatever keys a client
// writes and returns them as they were stored. Each app declares its own
// `Codable` shape and keys, the way the TypeScript SDK's `readConfigWith` and
// `setConfigKey` leave the schema to the caller; the SDK never hardcodes keys.
extension PutioSDK {
  /// Reads the whole config document into the app's own type. Missing keys are
  /// the app's concern: give them defaults in the type's decoder.
  public func getConfig<Config: Decodable>(as type: Config.Type) async throws -> Config {
    let envelope = try await request("/config", as: PutioConfigDocumentEnvelope<Config>.self)
    return envelope.config
  }

  /// Replaces the whole config document.
  public func writeConfig<Config: Encodable>(_ config: Config) async throws -> PutioOKResponse {
    let requestConfig = configRequestConfig(path: "/config", method: .put)
    let value = try encodeConfigValue(config, requestConfig: requestConfig)
    return try await request(
      "/config", method: .put, body: ["config": value], as: PutioOKResponse.self)
  }

  /// Reads one key of the config document.
  public func getConfigValue<Value: Decodable>(key: String, as type: Value.Type) async throws
    -> Value
  {
    let path = try configKeyPath(key)
    let envelope = try await request(path, as: PutioConfigValueEnvelope<Value>.self)
    return envelope.value
  }

  /// Writes one key of the config document without touching the others.
  public func setConfigValue<Value: Encodable>(key: String, _ value: Value) async throws
    -> PutioOKResponse
  {
    let path = try configKeyPath(key)
    let requestConfig = configRequestConfig(path: path, method: .put)
    let encoded = try encodeConfigValue(value, requestConfig: requestConfig)
    return try await request(path, method: .put, body: ["value": encoded], as: PutioOKResponse.self)
  }

  /// Removes one key from the config document.
  public func deleteConfigValue(key: String) async throws -> PutioOKResponse {
    let path = try configKeyPath(key)
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
  private func configKeyPath(_ key: String) throws -> String {
    guard !key.isEmpty, !key.contains("/"),
      key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
      let encoded = key.addingPercentEncoding(withAllowedCharacters: .putioConfigKey)
    else {
      let requestConfig = configRequestConfig(path: "/config/\(key)", method: .get)
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
  /// The key was empty or contained whitespace or a path separator.
  case invalidKey(String)
  /// The value encoded to something other than JSON. An `EncodingError` from
  /// the value itself, such as `Double.nan`, is passed through as it is.
  case unencodableValue
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
