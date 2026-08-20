import Foundation

open class PutioTrashFile: PutioBaseFile {
  open var deletedAt: Date
  open var expiresOn: Date

  enum CodingKeys: String, CodingKey {
    case deletedAt = "deleted_at"
    case expiresOn = "expiration_date"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.deletedAt = try PutioSDKDateParser.decodeDate(forKey: .deletedAt, from: container)
    self.expiresOn = try PutioSDKDateParser.decodeDate(forKey: .expiresOn, from: container)
    try super.init(from: decoder)
  }
}

open class PutioListTrashResponse: Decodable {
  open var cursor: String?
  open var total: Int?
  open var trashSize: Int64
  open var files: [PutioTrashFile]

  enum CodingKeys: String, CodingKey {
    case cursor
    case total
    case trashSize = "trash_size"
    case files
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    self.total = try container.decodeIfPresent(Int.self, forKey: .total)
    self.trashSize = try container.decodeIfPresent(Int64.self, forKey: .trashSize) ?? 0
    self.files = try container.decodeIfPresent([PutioTrashFile].self, forKey: .files) ?? []
  }
}

public struct PutioTrashListQuery: Sendable {
  public let perPage: Int?

  public init(perPage: Int? = 50) {
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
