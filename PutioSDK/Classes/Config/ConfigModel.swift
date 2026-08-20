import Foundation

public enum PutioChromecastPlaybackType: String, Codable, CaseIterable, Sendable {
  case hls
  case mp4
}

public struct PutioConfig: Decodable, Sendable {
  public let chromecastPlaybackType: PutioChromecastPlaybackType

  public init(chromecastPlaybackType: PutioChromecastPlaybackType = .hls) {
    self.chromecastPlaybackType = chromecastPlaybackType
  }

  private enum CodingKeys: String, CodingKey {
    case chromecastPlaybackType = "chromecast_playback_type"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let rawPlaybackType = try container.decodeIfPresent(
      String.self, forKey: .chromecastPlaybackType)
    self.chromecastPlaybackType =
      rawPlaybackType.flatMap(PutioChromecastPlaybackType.init(rawValue:)) ?? .hls
  }
}

public enum PutioConfigUpdate: Sendable {
  case chromecastPlaybackType(PutioChromecastPlaybackType)

  var key: String {
    switch self {
    case .chromecastPlaybackType:
      return "chromecast_playback_type"
    }
  }

  var value: PutioRequestValue {
    switch self {
    case .chromecastPlaybackType(let playbackType):
      return .string(playbackType.rawValue)
    }
  }
}
