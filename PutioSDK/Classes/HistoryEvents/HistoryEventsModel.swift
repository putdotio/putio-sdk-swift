import Foundation

public protocol PutioFileHistoryEvent {
  var fileID: Int { get set }
}

public struct PutioHistoryEventsQuery {
  public let perPage: Int?
  public let before: Int?

  public init(perPage: Int? = nil, before: Int? = nil) {
    self.perPage = perPage
    self.before = before
  }

  var parameters: PutioRequestParameters {
    var query: PutioRequestParameters = [:]
    if let perPage {
      query["per_page"] = .integer(perPage)
    }
    if let before {
      query["before"] = .integer(before)
    }
    return query
  }
}

open class PutioHistoryEventsResponse: Decodable {
  open var events: [PutioHistoryEvent]
  open var hasMore: Bool
  open var status: String

  enum CodingKeys: String, CodingKey {
    case events
    case hasMore = "has_more"
    case status
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    var eventsContainer = try container.nestedUnkeyedContainer(forKey: .events)
    var decodedEvents: [PutioHistoryEvent] = []

    while !eventsContainer.isAtEnd {
      let eventDecoder = try eventsContainer.superDecoder()
      let eventContainer = try eventDecoder.container(keyedBy: PutioHistoryEvent.CodingKeys.self)
      let rawType = try eventContainer.decodeIfPresent(String.self, forKey: .type) ?? ""
      decodedEvents.append(
        try PutioHistoryEventFactory.decode(rawType: rawType, from: eventDecoder))
    }

    self.events = decodedEvents
    self.hasMore = try container.decode(Bool.self, forKey: .hasMore)
    self.status = try container.decode(String.self, forKey: .status)
  }
}

open class PutioHistoryEvent: Decodable {
  public enum EventType {
    case upload, fileShared, transferCompleted, transferError, fileFromRSSDeletedError,
      rssFilterPaused, transferFromRSSError, transferCallbackError, privateTorrentPin, voucher,
      zipCreated, other
  }

  open var id: Int
  open var userID: Int
  open var type: EventType
  open var createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case userID = "user_id"
    case type
    case createdAt = "created_at"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.userID = try container.decode(Int.self, forKey: .userID)
    self.type = Self.eventType(
      from: try container.decodeIfPresent(String.self, forKey: .type) ?? "")
    self.createdAt = try PutioSDKDateParser.decodeDate(forKey: .createdAt, from: container)
  }

  static func eventType(from rawValue: String) -> EventType {
    switch rawValue.lowercased() {
    case "upload":
      return .upload
    case "file_shared":
      return .fileShared
    case "transfer_completed":
      return .transferCompleted
    case "transfer_error":
      return .transferError
    case "file_from_rss_deleted_for_space":
      return .fileFromRSSDeletedError
    case "rss_filter_paused":
      return .rssFilterPaused
    case "transfer_from_rss_error":
      return .transferFromRSSError
    case "transfer_callback_error":
      return .transferCallbackError
    case "private_torrent_pin":
      return .privateTorrentPin
    case "voucher":
      return .voucher
    case "zip_created":
      return .zipCreated
    default:
      return .other
    }
  }
}
