import Foundation

public struct PutioSearchHistoryConfig: Codable, Equatable, Sendable {
  public static let maxItems = 5

  public let items: [String]
  public let isEnabled: Bool

  public init(items: [String] = [], isEnabled: Bool = true) {
    self.items = Self.normalized(items)
    self.isEnabled = isEnabled
  }

  private enum CodingKeys: String, CodingKey {
    case items = "searchHistory"
    case isEnabled = "searchHistoryEnabled"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    var rawItems: [String] = []
    if container.contains(.items), try !container.decodeNil(forKey: .items) {
      var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
      while !itemsContainer.isAtEnd {
        if try itemsContainer.decodeNil() {
          continue
        }
        if let item = try? itemsContainer.decode(String.self) {
          rawItems.append(item)
        } else {
          _ = try itemsContainer.decode(IgnoredJSONValue.self)
        }
      }
    }
    self.items = Self.normalized(rawItems)
    self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
  }

  public func recording(_ keyword: String) -> [String] {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return items }
    return Self.normalized([trimmed] + items)
  }

  private static func normalized(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for value in values {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
      result.append(trimmed)
      if result.count == maxItems { break }
    }
    return result
  }
}

public enum PutioChromecastPlaybackType: String, Codable, CaseIterable, Sendable {
  case hls
  case mp4
}

@available(
  *, deprecated,
  message:
    "Config keys belong to the app; declare your own Codable config type and use getConfig(as:)."
)
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

@available(*, deprecated, message: "Use setConfigValue(key:_:) with the app's own key.")
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

private struct IgnoredJSONValue: Decodable {
  init(from decoder: Decoder) throws {}
}
