import Foundation

extension PutioSDK {
  /// Resolves a video file into its HLS source. `downloadToken` is `PutioAccount.downloadToken`;
  /// the metadata request uses the configured OAuth token, which never enters the returned URL.
  public func resolveVideoPlaybackSource(fileID: Int, downloadToken: String) async throws
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
        url: try makeVideoHLSURL(
          fileID: file.id, downloadToken: downloadToken, config: operationConfig),
        startFrom: file.startFrom
      )
    )
  }

  /// Resolves an audio file into its stream source. `downloadToken` is `PutioAccount.downloadToken`;
  /// the returned URL carries it and is a bearer credential.
  public func resolveAudioPlaybackSource(fileID: Int, downloadToken: String) async throws
    -> PutioAudioPlaybackSource
  {
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
      url: try makeFileStreamURL(
        fileID: file.id, downloadToken: downloadToken, config: operationConfig),
      startFrom: file.startFrom
    )
  }

  /// Plans a video or audio file under a Playback method. `downloadToken` is
  /// `PutioAccount.downloadToken`; the metadata request uses the configured OAuth token.
  /// Direct play asks `canPlayOriginal` whether this device decodes the original video.
  public func resolvePlayback(
    fileID: Int,
    downloadToken: String,
    method: PutioStreamingMethod,
    canPlayOriginal: PutioOriginalVideoDecision
  ) async throws -> PutioPlaybackPlan {
    let operationConfig = config
    var query: PutioRequestParameters = ["mp4_status": 1, "start_from": 1]
    if method == .directPlay {
      query["media_info"] = 1
    }
    let file = try await request(
      "/files/\(fileID)",
      query: query,
      apiConfig: operationConfig,
      as: PutioPlaybackPlanFileEnvelope.self
    ).file

    func stream(
      _ kind: PutioPlaybackStreamKind, fallbackReason: PutioPlaybackReason? = nil
    ) throws -> PutioPlaybackPlan {
      let url: URL
      switch kind {
      case .hls:
        url = try makeVideoHLSURL(
          fileID: file.id, downloadToken: downloadToken, config: operationConfig)
      case .original:
        url = try makeFileStreamURL(
          fileID: file.id, downloadToken: downloadToken, config: operationConfig)
      case .mp4:
        url = try makePlaybackURL(
          path: "/files/\(file.id)/mp4/stream", query: [:], downloadToken: downloadToken,
          config: operationConfig)
      }
      return .ready(
        PutioPlaybackStream(
          kind: kind,
          url: url,
          startFrom: file.startFrom,
          fallbackReason: fallbackReason,
          mediaInfo: file.mediaInfo
        )
      )
    }

    switch file.type {
    case .audio:
      return try stream(.original)
    case .video:
      break
    default:
      throw PutioPlaybackPlanError.unsupportedFileType(file.type)
    }

    switch method {
    case .standard:
      return file.needConvert ? .conversionRequired(nil) : try stream(.hls)
    case .directPlay:
      let reason: PutioPlaybackReason
      switch originalVideoSupport(of: file.mediaInfo, canPlayOriginal: canPlayOriginal) {
      case .playable:
        return try stream(.original)
      case .unsupported(let unsupportedReason):
        reason = unsupportedReason
      }
      if file.isMp4Available {
        return try stream(.mp4, fallbackReason: reason)
      }
      return file.needConvert ? .conversionRequired(reason) : .unplayable(reason)
    }
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

  private func makeVideoHLSURL(fileID: Int, downloadToken: String, config: PutioSDKConfig) throws
    -> URL
  {
    try makePlaybackURL(
      path: "/files/\(fileID)/hls/media.m3u8",
      query: ["subtitle_key": "all"],
      downloadToken: downloadToken,
      config: config
    )
  }

  private func makeFileStreamURL(fileID: Int, downloadToken: String, config: PutioSDKConfig)
    throws -> URL
  {
    try makePlaybackURL(
      path: "/files/\(fileID)/stream", query: [:], downloadToken: downloadToken, config: config)
  }

  private func makePlaybackURL(
    path: String, query: PutioRequestParameters, downloadToken: String, config: PutioSDKConfig
  ) throws -> URL {
    var query = query
    query["oauth_token"] = .string(downloadToken)
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

private func originalVideoSupport(
  of mediaInfo: PutioMediaInfo?, canPlayOriginal: PutioOriginalVideoDecision
) -> PutioOriginalVideoSupport {
  guard let mediaInfo else {
    return .unsupported(.notReady)
  }
  guard mediaInfo.playbackIssues.isEmpty else {
    return .unsupported(.playbackIssue)
  }
  return canPlayOriginal(mediaInfo)
}

private struct PutioPlaybackPlanFileEnvelope: Decodable {
  let file: PutioPlaybackPlanFile
}

private struct PutioPlaybackPlanFile: Decodable {
  let id: Int
  let type: PutioFileType
  let needConvert: Bool
  let isMp4Available: Bool
  let startFrom: Int
  let mediaInfo: PutioMediaInfo?

  private enum CodingKeys: String, CodingKey {
    case id
    case type = "file_type"
    case needConvert = "need_convert"
    case isMp4Available = "is_mp4_available"
    case startFrom = "start_from"
    case mediaInfo = "media_info"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.type = PutioFileType.fromAPI(try container.decode(String.self, forKey: .type))

    switch type {
    case .video:
      self.needConvert = try container.decode(Bool.self, forKey: .needConvert)
      self.isMp4Available = try container.decode(Bool.self, forKey: .isMp4Available)
      self.startFrom = try decodePlaybackStartFrom(forKey: .startFrom, in: container)
      self.mediaInfo = try container.decodeIfPresent(PutioMediaInfo.self, forKey: .mediaInfo)
    case .audio:
      self.needConvert = false
      self.isMp4Available = false
      self.startFrom = try decodePlaybackStartFrom(forKey: .startFrom, in: container)
      self.mediaInfo = try container.decodeIfPresent(PutioMediaInfo.self, forKey: .mediaInfo)
    default:
      self.needConvert = false
      self.isMp4Available = false
      self.startFrom = 0
      self.mediaInfo = nil
    }
  }
}

private struct PutioPlaybackFileEnvelope: Decodable {
  let file: PutioPlaybackFile
}

private struct PutioPlaybackFile: Decodable {
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
      self.startFrom = try decodePlaybackStartFrom(forKey: .startFrom, in: container)
    case .audio:
      self.needConvert = false
      self.startFrom = try decodePlaybackStartFrom(forKey: .startFrom, in: container)
    default:
      self.needConvert = false
      self.startFrom = 0
    }
  }
}

private func decodePlaybackStartFrom<Key: CodingKey>(
  forKey key: Key, in container: KeyedDecodingContainer<Key>
) throws -> Int {
  if let integerStartFrom = try? container.decode(Int.self, forKey: key) {
    guard integerStartFrom >= 0 else {
      throw invalidPlaybackStartFromError(forKey: key, in: container)
    }
    return integerStartFrom
  }

  let startFrom = try container.decode(Double.self, forKey: key)
  guard startFrom.isFinite, startFrom >= 0, startFrom < Double(Int.max) else {
    throw invalidPlaybackStartFromError(forKey: key, in: container)
  }
  return Int(startFrom)
}

private func invalidPlaybackStartFromError<Key: CodingKey>(
  forKey key: Key, in container: KeyedDecodingContainer<Key>
) -> DecodingError {
  DecodingError.dataCorruptedError(
    forKey: key,
    in: container,
    debugDescription: "Expected a nonnegative playback position within the Int range"
  )
}

private struct PutioMp4ConversionEnvelope: Decodable {
  let mp4: PutioMp4Conversion
}
