import Foundation

public struct PutioFileType: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let folder = PutioFileType(rawValue: "FOLDER")
  public static let video = PutioFileType(rawValue: "VIDEO")
  public static let audio = PutioFileType(rawValue: "AUDIO")
  public static let image = PutioFileType(rawValue: "IMAGE")
  public static let pdf = PutioFileType(rawValue: "PDF")
  public static let other = PutioFileType(rawValue: "OTHER")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  static func fromAPI(_ rawValue: String) -> PutioFileType {
    switch rawValue {
    case Self.folder.rawValue:
      return .folder
    case Self.video.rawValue:
      return .video
    case Self.audio.rawValue:
      return .audio
    case Self.image.rawValue:
      return .image
    case Self.pdf.rawValue:
      return .pdf
    default:
      return PutioFileType(rawValue: rawValue)
    }
  }

  private static let knownValues: Set<String> = [
    folder.rawValue,
    video.rawValue,
    audio.rawValue,
    image.rawValue,
    pdf.rawValue,
  ]
}

open class PutioBaseFile: Decodable {
  open var id: Int
  open var name: String
  open var icon: String
  open var type: PutioFileType
  open var parentID: Int
  open var size: Int64
  open var createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case icon
    case parentID = "parent_id"
    case size
    case createdAt = "created_at"
    case fileType = "file_type"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
    self.parentID = try container.decodeIfPresent(Int.self, forKey: .parentID) ?? 0
    self.size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
    self.createdAt = try PutioSDKDateParser.decodeDate(forKey: .createdAt, from: container)
    self.type = PutioFileType.fromAPI(try container.decode(String.self, forKey: .fileType))
  }
}

public struct PutioVideoMetadata: Decodable, Sendable {
  public var height: Int
  public var width: Int
  public var codec: String
  public var duration: Double
  public var aspectRatio: Double

  enum CodingKeys: String, CodingKey {
    case height
    case width
    case codec
    case duration
    case aspectRatio = "aspect_ratio"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
    self.width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
    self.codec = try container.decodeIfPresent(String.self, forKey: .codec) ?? ""
    self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
    self.aspectRatio = try container.decodeIfPresent(Double.self, forKey: .aspectRatio) ?? 0
  }
}

open class PutioFile: PutioBaseFile {
  open var isShared: Bool
  open var updatedAt: Date

  open var isSharedRoot: Bool = false
  open var sortBy: String = ""

  open var metaData: PutioVideoMetadata?
  open var screenshot: String = ""
  open var startFrom: Int = 0

  open var needConvert: Bool = false
  open var hasMp4: Bool = false

  open var mp4Size: Int64 = 0
  open var mp4StreamURL: String = ""

  open var streamURL: String = ""

  enum CodingKeys: String, CodingKey {
    case isShared = "is_shared"
    case updatedAt = "updated_at"
    case folderType = "folder_type"
    case sortBy = "sort_by"
    case metaData = "video_metadata"
    case screenshot
    case startFrom = "start_from"
    case needConvert = "need_convert"
    case hasMp4 = "is_mp4_available"
    case mp4Size = "mp4_size"
    case mp4StreamURL = "mp4_stream_url"
    case streamURL = "stream_url"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let baseContainer = try decoder.container(keyedBy: PutioBaseFile.CodingKeys.self)
    self.isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared) ?? false

    let id = try baseContainer.decode(Int.self, forKey: .id)
    let createdAt =
      id == 0 ? try PutioSDKDateParser.decodeDate(forKey: .createdAt, from: baseContainer) : nil
    let updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    self.updatedAt = try PutioSDKDateParser.parse(updatedAt, fallback: createdAt)

    let folderType = try container.decodeIfPresent(String.self, forKey: .folderType) ?? ""
    self.isSharedRoot = folderType == "SHARED_ROOT"
    self.sortBy = try container.decodeIfPresent(String.self, forKey: .sortBy) ?? ""
    self.metaData = try container.decodeIfPresent(PutioVideoMetadata.self, forKey: .metaData)
    self.screenshot = try container.decodeIfPresent(String.self, forKey: .screenshot) ?? ""
    self.startFrom = Int(try container.decodeIfPresent(Double.self, forKey: .startFrom) ?? 0)
    self.needConvert = try container.decodeIfPresent(Bool.self, forKey: .needConvert) ?? false
    self.hasMp4 = try container.decodeIfPresent(Bool.self, forKey: .hasMp4) ?? false
    self.mp4Size = try container.decodeIfPresent(Int64.self, forKey: .mp4Size) ?? 0
    self.mp4StreamURL = try container.decodeIfPresent(String.self, forKey: .mp4StreamURL) ?? ""
    self.streamURL = try container.decodeIfPresent(String.self, forKey: .streamURL) ?? ""

    try super.init(from: decoder)
  }

  public func getStreamURL(token: String) -> URL? {
    if type == .audio {
      return putioFileURL(
        fileID: id, pathSuffix: "stream",
        queryItems: [URLQueryItem(name: "oauth_token", value: token)])
    }

    if type == .video {
      return putioFileURL(
        fileID: id,
        pathSuffix: "hls/media.m3u8",
        queryItems: [
          URLQueryItem(name: "subtitle_key", value: "all"),
          URLQueryItem(name: "oauth_token", value: token),
        ]
      )
    }

    return nil
  }

  public func getHlsStreamURL(token: String) -> URL {
    putioFileURL(
      fileID: id,
      pathSuffix: "hls/media.m3u8",
      queryItems: [
        URLQueryItem(name: "subtitle_key", value: "all"),
        URLQueryItem(name: "oauth_token", value: token),
      ]
    )
  }

  public func getAudioStreamURL(token: String) -> URL {
    putioFileURL(
      fileID: id, pathSuffix: "stream",
      queryItems: [URLQueryItem(name: "oauth_token", value: token)])
  }

  public func getDownloadURL(token: String) -> URL {
    putioFileURL(
      fileID: id, pathSuffix: "download",
      queryItems: [URLQueryItem(name: "oauth_token", value: token)])
  }

  public func getMp4DownloadURL(token: String) -> URL {
    putioFileURL(
      fileID: id, pathSuffix: "mp4/download",
      queryItems: [URLQueryItem(name: "oauth_token", value: token)])
  }
}

public enum PutioNextFileType: String, Decodable, Sendable {
  case video = "VIDEO"
  case audio = "AUDIO"
}

public struct PutioFilesListQuery: Sendable {
  public let perPage: Int?
  public let total: Bool
  public let hidden: Bool
  public let noCursor: Bool
  public let contentType: String?
  public let fileType: PutioFileType?
  public let sortBy: String?
  public let mp4Status: Bool

  public init(
    perPage: Int? = nil,
    total: Bool = false,
    hidden: Bool = false,
    noCursor: Bool = false,
    contentType: String? = nil,
    fileType: PutioFileType? = nil,
    sortBy: String? = nil,
    mp4Status: Bool = false
  ) {
    self.perPage = perPage
    self.total = total
    self.hidden = hidden
    self.noCursor = noCursor
    self.contentType = contentType
    self.fileType = fileType
    self.sortBy = sortBy
    self.mp4Status = mp4Status
  }

  func parameters(parentID: Int) -> PutioRequestParameters {
    var query: PutioRequestParameters = [
      "parent_id": .integer(parentID),
      "mp4_status_parent": 1,
      "stream_url_parent": 1,
      "mp4_stream_url_parent": 1,
      "video_metadata_parent": 1,
    ]
    if let perPage { query["per_page"] = .integer(perPage) }
    if total { query["total"] = 1 }
    if hidden { query["hidden"] = 1 }
    if noCursor { query["no_cursor"] = 1 }
    if let contentType { query["content_type"] = .string(contentType) }
    if let fileType { query["file_type"] = .string(fileType.rawValue) }
    if let sortBy { query["sort_by"] = .string(sortBy) }
    if mp4Status { query["mp4_status"] = 1 }
    return query
  }
}

public struct PutioFilesListContinueQuery: Sendable {
  public let perPage: Int?

  public init(perPage: Int? = nil) {
    self.perPage = perPage
  }

  var parameters: PutioRequestParameters {
    var query: PutioRequestParameters = [:]
    if let perPage { query["per_page"] = .integer(perPage) }
    return query
  }
}

public struct PutioFileDetailsQuery: Sendable {
  public let mp4Size: Bool
  public let startFrom: Bool
  public let streamURL: Bool
  public let mp4StreamURL: Bool

  public init(
    mp4Size: Bool = true,
    startFrom: Bool = true,
    streamURL: Bool = true,
    mp4StreamURL: Bool = true
  ) {
    self.mp4Size = mp4Size
    self.startFrom = startFrom
    self.streamURL = streamURL
    self.mp4StreamURL = mp4StreamURL
  }

  var parameters: PutioRequestParameters {
    var query: PutioRequestParameters = [:]
    if mp4Size { query["mp4_size"] = 1 }
    if startFrom { query["start_from"] = 1 }
    if streamURL { query["stream_url"] = 1 }
    if mp4StreamURL { query["mp4_stream_url"] = 1 }
    return query
  }
}

public struct PutioFileDeleteOptions: Sendable {
  public let skipNonexistents: Bool
  public let skipOwnerCheck: Bool

  public init(skipNonexistents: Bool = true, skipOwnerCheck: Bool = false) {
    self.skipNonexistents = skipNonexistents
    self.skipOwnerCheck = skipOwnerCheck
  }

  var parameters: PutioRequestParameters {
    [
      "skip_nonexistents": .bool(skipNonexistents),
      "skip_owner_check": .bool(skipOwnerCheck),
    ]
  }
}

open class PutioNextFile: Decodable {
  open var id: Int
  open var name: String
  open var parentID: Int
  open var type: PutioNextFileType

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case parentID = "parent_id"
    case type = "file_type"
  }

  init(id: Int, name: String, parentID: Int, type: PutioNextFileType) {
    self.id = id
    self.name = name
    self.parentID = parentID
    self.type = type
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.parentID = try container.decodeIfPresent(Int.self, forKey: .parentID) ?? 0
    self.name = try container.decode(String.self, forKey: .name)
    self.type = try container.decode(PutioNextFileType.self, forKey: .type)
  }

  public func getStreamURL(token: String) -> URL {
    switch type {
    case .audio:
      return putioFileURL(
        fileID: id, pathSuffix: "stream",
        queryItems: [URLQueryItem(name: "oauth_token", value: token)])
    case .video:
      return putioFileURL(
        fileID: id,
        pathSuffix: "hls/media.m3u8",
        queryItems: [
          URLQueryItem(name: "subtitle_key", value: "all"),
          URLQueryItem(name: "oauth_token", value: token),
        ]
      )
    }
  }
}

private func putioFileURL(fileID: Int, pathSuffix: String, queryItems: [URLQueryItem]) -> URL {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "api.put.io"
  components.path = "/v2/files/\(fileID)/\(pathSuffix)"
  components.queryItems = queryItems

  guard let url = components.url else {
    preconditionFailure("Unable to build a put.io file URL")
  }

  return url
}

enum PutioSDKDateParser {
  private static let formatter = ISO8601DateFormatter()

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let formatterQueue = DispatchQueue(label: "io.putdotio.sdk.date-parser")

  static func decodeDate<Key: CodingKey>(
    forKey key: Key, from container: KeyedDecodingContainer<Key>
  ) throws -> Date {
    let value = try container.decode(String.self, forKey: key)
    return try parse(value)
  }

  static func parse(_ value: String?, fallback: Date? = nil) throws -> Date {
    if let value, !value.isEmpty {
      for candidate in [value, "\(value)Z", "\(value)+00:00"] {
        if let parsed = formatterQueue.sync(execute: {
          formatter.date(from: candidate) ?? fractionalFormatter.date(from: candidate)
        }) {
          return parsed
        }
      }
    }

    if let fallback {
      return fallback
    }

    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: [],
        debugDescription: "Expected an ISO8601-ish put.io date string",
      )
    )
  }
}
