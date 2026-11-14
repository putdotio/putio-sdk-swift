import Foundation

public struct PutioMediaInfo: Decodable, Equatable, Sendable {
  public let mimeType: String?
  public let format: PutioMediaFormat?
  public let streams: [PutioMediaStream]
  public let playbackIssues: [PutioPlaybackIssue]

  public init(
    mimeType: String?,
    format: PutioMediaFormat?,
    streams: [PutioMediaStream],
    playbackIssues: [PutioPlaybackIssue]
  ) {
    self.mimeType = mimeType
    self.format = format
    self.streams = streams
    self.playbackIssues = playbackIssues
  }

  enum CodingKeys: String, CodingKey {
    case mimeType = "mime_type"
    case format
    case streams
    case playbackIssues = "playback_issues"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
    self.format = try container.decodeIfPresent(PutioMediaFormat.self, forKey: .format)
    self.streams = try container.decodeIfPresent([PutioMediaStream].self, forKey: .streams) ?? []
    self.playbackIssues =
      try container.decodeIfPresent([String].self, forKey: .playbackIssues)?
      .map(PutioPlaybackIssue.init(rawValue:)) ?? []
  }
}

public struct PutioMediaFormat: Decodable, Equatable, Sendable {
  public let name: String?

  public init(name: String?) {
    self.name = name
  }
}

public struct PutioMediaStream: Decodable, Equatable, Sendable {
  public let codecType: PutioMediaStreamType?
  public let codecName: String?
  public let rfc6381Codec: String?
  public let width: Int?
  public let height: Int?
  public let profile: String?
  public let level: Int?
  public let channels: Int?

  public init(
    codecType: PutioMediaStreamType?,
    codecName: String?,
    rfc6381Codec: String? = nil,
    width: Int? = nil,
    height: Int? = nil,
    profile: String? = nil,
    level: Int? = nil,
    channels: Int? = nil
  ) {
    self.codecType = codecType
    self.codecName = codecName
    self.rfc6381Codec = rfc6381Codec
    self.width = width
    self.height = height
    self.profile = profile
    self.level = level
    self.channels = channels
  }

  enum CodingKeys: String, CodingKey {
    case codecType = "codec_type"
    case codecName = "codec_name"
    case rfc6381Codec = "rfc6381_codec"
    case width
    case height
    case profile
    case level
    case channels
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.codecType = try container.decodeIfPresent(String.self, forKey: .codecType).map(
      PutioMediaStreamType.init(rawValue:))
    self.codecName = try container.decodeIfPresent(String.self, forKey: .codecName)
    self.rfc6381Codec = try container.decodeIfPresent(String.self, forKey: .rfc6381Codec)
    self.width = try container.decodeIfPresent(Int.self, forKey: .width)
    self.height = try container.decodeIfPresent(Int.self, forKey: .height)
    self.profile = try container.decodeIfPresent(String.self, forKey: .profile)
    self.level = try container.decodeIfPresent(Int.self, forKey: .level)
    self.channels = try container.decodeIfPresent(Int.self, forKey: .channels)
  }
}

public struct PutioMediaStreamType: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let video = PutioMediaStreamType(rawValue: "video")
  public static let audio = PutioMediaStreamType(rawValue: "audio")
  public static let subtitle = PutioMediaStreamType(rawValue: "subtitle")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  private static let knownValues: Set<String> = [
    video.rawValue,
    audio.rawValue,
    subtitle.rawValue,
  ]
}

public struct PutioPlaybackIssue: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let malformedSEI = PutioPlaybackIssue(rawValue: "malformed_sei")
  public static let malformedParameterSets = PutioPlaybackIssue(
    rawValue: "malformed_parameter_sets")
  public static let sparseIDR = PutioPlaybackIssue(rawValue: "sparse_idr")
  public static let interlacedVideo = PutioPlaybackIssue(rawValue: "interlaced_video")
  public static let excessiveFrameRate = PutioPlaybackIssue(rawValue: "excessive_frame_rate")
  public static let openGOP = PutioPlaybackIssue(rawValue: "open_gop")
  public static let movieFragments = PutioPlaybackIssue(rawValue: "movie_fragments")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  private static let knownValues: Set<String> = [
    malformedSEI.rawValue,
    malformedParameterSets.rawValue,
    sparseIDR.rawValue,
    interlacedVideo.rawValue,
    excessiveFrameRate.rawValue,
    openGOP.rawValue,
    movieFragments.rawValue,
  ]
}
