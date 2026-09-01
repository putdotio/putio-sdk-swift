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
      as: PutioVideoPlaybackFileEnvelope.self
    )
    let file = envelope.file

    guard file.type == .video else {
      throw PutioVideoPlaybackResolutionError.unsupportedFileType(file.type)
    }

    guard !file.needConvert else {
      return .conversionRequired
    }

    return .ready(
      PutioVideoPlaybackSource(
        url: try makeVideoHLSURL(fileID: file.id, config: operationConfig),
        startFrom: file.startFrom
      )
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
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: config,
      url: "/files/\(fileID)/hls/media.m3u8",
      method: .get,
      query: [
        "subtitle_key": "all",
        "oauth_token": .string(config.token),
      ]
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

private struct PutioVideoPlaybackFileEnvelope: Decodable {
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

    if type == .video {
      self.needConvert = try container.decode(Bool.self, forKey: .needConvert)

      if let integerStartFrom = try? container.decode(Int.self, forKey: .startFrom) {
        guard integerStartFrom >= 0 else {
          throw Self.invalidStartFromError(in: container)
        }
        self.startFrom = integerStartFrom
        return
      }

      let startFrom = try container.decode(Double.self, forKey: .startFrom)
      guard startFrom.isFinite, startFrom >= 0, startFrom < Double(Int.max) else {
        throw Self.invalidStartFromError(in: container)
      }
      self.startFrom = Int(startFrom)
    } else {
      self.needConvert = false
      self.startFrom = 0
    }
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
