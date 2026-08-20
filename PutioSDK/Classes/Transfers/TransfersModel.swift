import Foundation

public struct PutioTransferType: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let url = PutioTransferType(rawValue: "URL")
  public static let torrent = PutioTransferType(rawValue: "TORRENT")
  public static let playlist = PutioTransferType(rawValue: "PLAYLIST")
  public static let liveStream = PutioTransferType(rawValue: "LIVE_STREAM")
  public static let notAvailable = PutioTransferType(rawValue: "N/A")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  static func fromAPI(_ rawValue: String) -> PutioTransferType {
    switch rawValue {
    case Self.url.rawValue:
      return .url
    case Self.torrent.rawValue:
      return .torrent
    case Self.playlist.rawValue:
      return .playlist
    case Self.liveStream.rawValue:
      return .liveStream
    case Self.notAvailable.rawValue:
      return .notAvailable
    default:
      return PutioTransferType(rawValue: rawValue)
    }
  }

  private static let knownValues: Set<String> = [
    url.rawValue,
    torrent.rawValue,
    playlist.rawValue,
    liveStream.rawValue,
    notAvailable.rawValue,
  ]
}

public struct PutioTransferStatus: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let waiting = PutioTransferStatus(rawValue: "WAITING")
  public static let preparingDownload = PutioTransferStatus(rawValue: "PREPARING_DOWNLOAD")
  public static let inQueue = PutioTransferStatus(rawValue: "IN_QUEUE")
  public static let downloading = PutioTransferStatus(rawValue: "DOWNLOADING")
  public static let waitingForCompleteQueue = PutioTransferStatus(
    rawValue: "WAITING_FOR_COMPLETE_QUEUE")
  public static let waitingForDownloader = PutioTransferStatus(rawValue: "WAITING_FOR_DOWNLOADER")
  public static let completing = PutioTransferStatus(rawValue: "COMPLETING")
  public static let stopping = PutioTransferStatus(rawValue: "STOPPING")
  public static let seeding = PutioTransferStatus(rawValue: "SEEDING")
  public static let completed = PutioTransferStatus(rawValue: "COMPLETED")
  public static let error = PutioTransferStatus(rawValue: "ERROR")
  public static let preparingSeed = PutioTransferStatus(rawValue: "PREPARING_SEED")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  static func fromAPI(_ rawValue: String) -> PutioTransferStatus {
    switch rawValue {
    case Self.waiting.rawValue:
      return .waiting
    case Self.preparingDownload.rawValue:
      return .preparingDownload
    case Self.inQueue.rawValue:
      return .inQueue
    case Self.downloading.rawValue:
      return .downloading
    case Self.waitingForCompleteQueue.rawValue:
      return .waitingForCompleteQueue
    case Self.waitingForDownloader.rawValue:
      return .waitingForDownloader
    case Self.completing.rawValue:
      return .completing
    case Self.stopping.rawValue:
      return .stopping
    case Self.seeding.rawValue:
      return .seeding
    case Self.completed.rawValue:
      return .completed
    case Self.error.rawValue:
      return .error
    case Self.preparingSeed.rawValue:
      return .preparingSeed
    default:
      return PutioTransferStatus(rawValue: rawValue)
    }
  }

  private static let knownValues: Set<String> = [
    waiting.rawValue,
    preparingDownload.rawValue,
    inQueue.rawValue,
    downloading.rawValue,
    waitingForCompleteQueue.rawValue,
    waitingForDownloader.rawValue,
    completing.rawValue,
    stopping.rawValue,
    seeding.rawValue,
    completed.rawValue,
    error.rawValue,
    preparingSeed.rawValue,
  ]
}

public struct PutioTransferLink: Decodable {
  public let label: String
  public let url: String?
}

public struct PutioTransfer: Decodable {
  public let id: Int
  public let name: String
  public let source: String
  public let type: PutioTransferType
  public let status: PutioTransferStatus
  public let saveParentID: Int
  public let fileID: Int?
  public let downloadID: Int?
  public let size: Double?
  public let percentDone: Double?
  public let completionPercent: Double?
  public let downloaded: Double?
  public let uploaded: Double?
  public let downSpeed: Double?
  public let upSpeed: Double?
  public let estimatedTime: Double?
  public let availability: Double?
  public let errorMessage: String?
  public let createdAt: String
  public let startedAt: String?
  public let finishedAt: String?
  public let callbackURL: String?
  public let currentRatio: Double?
  public let secondsSeeding: Double?
  public let isPrivate: Bool
  public let links: [PutioTransferLink]
  public let userFileExists: Bool?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case source
    case type
    case status
    case saveParentID = "save_parent_id"
    case fileID = "file_id"
    case downloadID = "download_id"
    case size
    case percentDone = "percent_done"
    case completionPercent = "completion_percent"
    case downloaded
    case uploaded
    case downSpeed = "down_speed"
    case upSpeed = "up_speed"
    case estimatedTime = "estimated_time"
    case availability
    case errorMessage = "error_message"
    case createdAt = "created_at"
    case startedAt = "started_at"
    case finishedAt = "finished_at"
    case callbackURL = "callback_url"
    case currentRatio = "current_ratio"
    case secondsSeeding = "seconds_seeding"
    case isPrivate = "is_private"
    case links
    case userFileExists = "userfile_exists"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
    self.type = PutioTransferType.fromAPI(
      try container.decodeIfPresent(String.self, forKey: .type)
        ?? PutioTransferType.notAvailable.rawValue)
    self.status = PutioTransferStatus.fromAPI(
      try container.decodeIfPresent(String.self, forKey: .status)
        ?? PutioTransferStatus.waiting.rawValue)
    self.saveParentID = try container.decodeIfPresent(Int.self, forKey: .saveParentID) ?? 0
    self.fileID = try container.decodeIfPresent(Int.self, forKey: .fileID)
    self.downloadID = try container.decodeIfPresent(Int.self, forKey: .downloadID)
    self.size = try container.decodeIfPresent(Double.self, forKey: .size)
    self.percentDone = try container.decodeIfPresent(Double.self, forKey: .percentDone)
    self.completionPercent = try container.decodeIfPresent(Double.self, forKey: .completionPercent)
    self.downloaded = try container.decodeIfPresent(Double.self, forKey: .downloaded)
    self.uploaded = try container.decodeIfPresent(Double.self, forKey: .uploaded)
    self.downSpeed = try container.decodeIfPresent(Double.self, forKey: .downSpeed)
    self.upSpeed = try container.decodeIfPresent(Double.self, forKey: .upSpeed)
    self.estimatedTime = try container.decodeIfPresent(Double.self, forKey: .estimatedTime)
    self.availability = try container.decodeIfPresent(Double.self, forKey: .availability)
    self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    self.startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
    self.finishedAt = try container.decodeIfPresent(String.self, forKey: .finishedAt)
    self.callbackURL = try container.decodeIfPresent(String.self, forKey: .callbackURL)
    self.currentRatio = try container.decodeIfPresent(Double.self, forKey: .currentRatio)
    self.secondsSeeding = try container.decodeIfPresent(Double.self, forKey: .secondsSeeding)
    self.isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
    self.links = try container.decodeIfPresent([PutioTransferLink].self, forKey: .links) ?? []
    self.userFileExists = try container.decodeIfPresent(Bool.self, forKey: .userFileExists)
  }
}

public struct PutioTransfersListQuery {
  public let perPage: Int?

  public init(perPage: Int? = nil) {
    self.perPage = perPage
  }

  var parameters: PutioRequestParameters {
    var query: PutioRequestParameters = [:]
    if let perPage {
      query["per_page"] = .integer(perPage)
    }
    return query
  }
}

public struct PutioTransfersListResponse: Decodable {
  public let cursor: String?
  public let total: Int?
  public let transfers: [PutioTransfer]
}

public struct PutioTransferAddInput {
  public let url: String
  public let saveParentID: Int?
  public let callbackURL: String?

  public init(url: String, saveParentID: Int? = nil, callbackURL: String? = nil) {
    self.url = url
    self.saveParentID = saveParentID
    self.callbackURL = callbackURL
  }

  var parameters: PutioRequestParameters {
    var body: PutioRequestParameters = ["url": .string(url)]
    if let saveParentID {
      body["save_parent_id"] = .integer(saveParentID)
    }
    if let callbackURL {
      body["callback_url"] = .string(callbackURL)
    }
    return body
  }
}

public struct PutioTransferInfoItem: Decodable {
  public let url: String
  public let name: String
  public let typeName: String
  public let fileSize: Double
  public let humanSize: String
  public let error: String?
  public let errorMessage: String?

  enum CodingKeys: String, CodingKey {
    case url
    case name
    case typeName = "type_name"
    case fileSize = "file_size"
    case humanSize = "human_size"
    case error
    case errorMessage = "error_message"
  }
}

public struct PutioTransferInfoResponse: Decodable {
  public let diskAvailable: Double
  public let items: [PutioTransferInfoItem]

  enum CodingKeys: String, CodingKey {
    case diskAvailable = "disk_avail"
    case items = "ret"
  }
}

public struct PutioTransfersAddManyError: Decodable {
  public let errorType: String
  public let statusCode: Int
  public let url: String

  enum CodingKeys: String, CodingKey {
    case errorType = "error_type"
    case statusCode = "status_code"
    case url
  }
}

public struct PutioTransfersAddManyResponse: Decodable {
  public let errors: [PutioTransfersAddManyError]
  public let transfers: [PutioTransfer]
}

public struct PutioTransfersCleanResponse: Decodable {
  public let deletedIDs: [Int]

  enum CodingKeys: String, CodingKey {
    case deletedIDs = "deleted_ids"
  }
}

struct PutioTransferEnvelope: Decodable {
  let transfer: PutioTransfer
}

struct PutioTransferCountEnvelope: Decodable {
  let count: Int
}
