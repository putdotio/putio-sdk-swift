open class PutioZipCreatedEvent: PutioHistoryEvent {
  open var zipID: Int
  open var zipSize: Int64

  enum ZipCreatedCodingKeys: String, CodingKey {
    case zipID = "zip_id"
    case zipSize = "zip_size"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: ZipCreatedCodingKeys.self)
    self.zipID = try container.decodeIfPresent(Int.self, forKey: .zipID) ?? 0
    self.zipSize = try container.decodeIfPresent(Int64.self, forKey: .zipSize) ?? 0
    try super.init(from: decoder)
  }
}
