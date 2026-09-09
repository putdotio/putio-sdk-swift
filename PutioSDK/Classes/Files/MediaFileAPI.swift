import Foundation

extension PutioSDK {
  public func resolveVideoPlaybackSource(fileID: Int) async throws
    -> PutioVideoPlaybackResolution
  {
    let operationConfig = config
    let envelope = try await request(
      "/files/\(fileID)",
      query: ["mp4_status": 1, "start_from": 1],
      apiConfig: operationConfig,
      as: PutioPlaybackFileEnvelope.self
    )
    let file = envelope.file

    guard file.type == .video else {
      throw PutioVideoPlaybackResolutionError.unsupportedFileType(file.type)
    }

    if file.needConvert {
      return .conversionRequired
    }

    return .ready(
      PutioVideoPlaybackSource(
        url: try makeVideoHLSURL(fileID: file.id, config: operationConfig),
        startFrom: file.startFrom
      )
    )
  }

  /// Resolves an audio file into its authenticated stream source. The
  /// returned URL carries the access token and is a bearer credential.
  public func resolveAudioPlaybackSource(fileID: Int) async throws -> PutioAudioPlaybackSource {
    let operationConfig = config
    let envelope = try await request(
      "/files/\(fileID)",
      query: ["start_from": 1],
      apiConfig: operationConfig,
      as: PutioPlaybackFileEnvelope.self
    )
    let file = envelope.file

    guard file.type == .audio else {
      throw PutioAudioPlaybackResolutionError.unsupportedFileType(file.type)
    }

    return PutioAudioPlaybackSource(
      url: try makeAudioStreamURL(fileID: file.id, config: operationConfig),
      startFrom: file.startFrom
    )
  }

  public func startMp4Conversion(fileID: Int) async throws -> PutioOKResponse {
    try await request("/files/\(fileID)/mp4", method: .post, as: PutioOKResponse.self)
  }

  public func getMp4ConversionStatus(fileID: Int) async throws -> PutioMp4Conversion {
    let envelope = try await request("/files/\(fileID)/mp4", as: PutioMp4ConversionEnvelope.self)
    return envelope.mp4
  }

  public func getStartFrom(fileID: Int) async throws -> Int {
    let response = try await request("/files/\(fileID)/start-from", as: PutioStartFromResponse.self)
    return response.startFrom
  }

  public func setStartFrom(fileID: Int, time: Int) async throws -> PutioOKResponse {
    try await request(
      "/files/\(fileID)/start-from/set", method: .post, body: ["time": .integer(time)],
      as: PutioOKResponse.self)
  }

  public func resetStartFrom(fileID: Int) async throws -> PutioOKResponse {
    try await request("/files/\(fileID)/start-from/delete", as: PutioOKResponse.self)
  }

  private func makeVideoHLSURL(fileID: Int, config: PutioSDKConfig) throws -> URL {
    try makePlaybackURL(
      path: "/files/\(fileID)/hls/media.m3u8",
      query: ["subtitle_key": "all"],
      config: config
    )
  }

  private func makeAudioStreamURL(fileID: Int, config: PutioSDKConfig) throws -> URL {
    try makePlaybackURL(path: "/files/\(fileID)/stream", query: [:], config: config)
  }

  private func makePlaybackURL(
    path: String, query: PutioRequestParameters, config: PutioSDKConfig
  ) throws -> URL {
    var query = query
    query["oauth_token"] = .string(config.token)
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: config,
      url: path,
      method: .get,
      query: query
    )

    do {
      return try requestConfig.buildURL()
    } catch {
      throw PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig),
        unknownError: error
      )
    }
  }
}

private struct PutioPlaybackFileEnvelope: Decodable {
  let file: PutioVideoPlaybackFile
}

private struct PutioVideoPlaybackFile: Decodable {
  let id: Int
  let type: PutioFileType
  let needConvert: Bool
  let startFrom: Int

  private enum CodingKeys: String, CodingKey {
    case id
    case type = "file_type"
    case needConvert = "need_convert"
    case startFrom = "start_from"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.type = PutioFileType.fromAPI(try container.decode(String.self, forKey: .type))

    switch type {
    case .video:
      self.needConvert = try container.decode(Bool.self, forKey: .needConvert)
      self.startFrom = try Self.decodeStartFrom(in: container)
    case .audio:
      self.needConvert = false
      self.startFrom = try Self.decodeStartFrom(in: container)
    default:
      self.needConvert = false
      self.startFrom = 0
    }
  }

  private static func decodeStartFrom(
    in container: KeyedDecodingContainer<CodingKeys>
  ) throws -> Int {
    if let integerStartFrom = try? container.decode(Int.self, forKey: .startFrom) {
      guard integerStartFrom >= 0 else {
        throw invalidStartFromError(in: container)
      }
      return integerStartFrom
    }

    let startFrom = try container.decode(Double.self, forKey: .startFrom)
    guard startFrom.isFinite, startFrom >= 0, startFrom < Double(Int.max) else {
      throw invalidStartFromError(in: container)
    }
    return Int(startFrom)
  }

  private static func invalidStartFromError(
    in container: KeyedDecodingContainer<CodingKeys>
  ) -> DecodingError {
    DecodingError.dataCorruptedError(
      forKey: .startFrom,
      in: container,
      debugDescription: "Expected a nonnegative playback position within the Int range"
    )
  }
}

private struct PutioMp4ConversionEnvelope: Decodable {
  let mp4: PutioMp4Conversion
}
