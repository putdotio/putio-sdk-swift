import Foundation

public enum PutioStreamingMethod: String, CaseIterable, Equatable, Sendable {
  case standard = "hls"
  case directPlay = "file"
}

public enum PutioPlaybackReason: String, CaseIterable, Equatable, Sendable {
  case notReady = "not_ready"
  case playbackIssue = "playback_issue"
  case containerUnsupported = "container_unsupported"
  case videoUnsupported = "video_unsupported"
  case audioUnsupported = "audio_unsupported"
  case decoderError = "decoder_error"
  case conversionFailed = "conversion_failed"
}

public enum PutioOriginalVideoSupport: Equatable, Sendable {
  case playable
  case unsupported(PutioPlaybackReason)
}

/// Decides whether this device decodes the original video `media_info` describes.
/// The SDK asks only when `media_info` is present and lists no playback issue.
public typealias PutioOriginalVideoDecision =
  @Sendable (PutioMediaInfo) -> PutioOriginalVideoSupport

public enum PutioPlaybackStreamKind: String, Equatable, Sendable {
  case hls
  case original
  case mp4
}

public struct PutioPlaybackStream: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible, CustomReflectable
{
  public let kind: PutioPlaybackStreamKind
  public let url: URL
  public let startFrom: Int
  public let fallbackReason: PutioPlaybackReason?
  public let mediaInfo: PutioMediaInfo?

  public init(
    kind: PutioPlaybackStreamKind,
    url: URL,
    startFrom: Int,
    fallbackReason: PutioPlaybackReason? = nil,
    mediaInfo: PutioMediaInfo? = nil
  ) {
    self.kind = kind
    self.url = url
    self.startFrom = startFrom
    self.fallbackReason = fallbackReason
    self.mediaInfo = mediaInfo
  }

  public var description: String {
    "PutioPlaybackStream(kind: \(kind.rawValue), url: \(redactedPlaybackURLDescription(url)), "
      + "startFrom: \(startFrom), fallbackReason: \(fallbackReason?.rawValue ?? "nil"))"
  }

  public var debugDescription: String {
    description
  }

  public var customMirror: Mirror {
    Mirror(
      self,
      children: [
        "kind": kind,
        "url": redactedPlaybackURLDescription(url),
        "startFrom": startFrom,
        "fallbackReason": fallbackReason as Any,
        "mediaInfo": mediaInfo as Any,
      ],
      displayStyle: .struct
    )
  }
}

public enum PutioPlaybackPlan: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible, CustomReflectable
{
  case ready(PutioPlaybackStream)
  case conversionRequired(PutioPlaybackReason?)
  case unplayable(PutioPlaybackReason)

  public var description: String {
    switch self {
    case .ready(let stream):
      return "PutioPlaybackPlan.ready(\(stream))"
    case .conversionRequired(let reason):
      return "PutioPlaybackPlan.conversionRequired(\(reason?.rawValue ?? "nil"))"
    case .unplayable(let reason):
      return "PutioPlaybackPlan.unplayable(\(reason.rawValue))"
    }
  }

  public var debugDescription: String {
    description
  }

  public var customMirror: Mirror {
    switch self {
    case .ready(let stream):
      return Mirror(self, children: ["ready": stream], displayStyle: .enum)
    case .conversionRequired(let reason):
      return Mirror(self, children: ["conversionRequired": reason as Any], displayStyle: .enum)
    case .unplayable(let reason):
      return Mirror(self, children: ["unplayable": reason], displayStyle: .enum)
    }
  }
}

public enum PutioPlaybackPlanError: Error, LocalizedError, Equatable, Sendable {
  case unsupportedFileType(PutioFileType)

  public var errorDescription: String? {
    switch self {
    case .unsupportedFileType:
      return "Only video and audio files can be played."
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .unsupportedFileType:
      return "Choose a video or audio file and try again."
    }
  }
}
