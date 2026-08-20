open class PutioTransferFromRSSErrorEvent: PutioHistoryEvent {
  open var rssID: Int
  open var transferName: String

  enum TransferFromRSSCodingKeys: String, CodingKey {
    case rssID = "rss_id"
    case transferName = "transfer_name"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TransferFromRSSCodingKeys.self)
    self.rssID = try container.decodeIfPresent(Int.self, forKey: .rssID) ?? 0
    self.transferName = try container.decodeIfPresent(String.self, forKey: .transferName) ?? ""
    try super.init(from: decoder)
  }
}
