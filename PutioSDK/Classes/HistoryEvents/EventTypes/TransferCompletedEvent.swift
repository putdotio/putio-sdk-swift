open class PutioTransferCompletedEvent: PutioHistoryEvent, PutioFileHistoryEvent {
  open var transferName: String
  open var transferSize: Int64
  open var source: String
  open var fileID: Int

  enum TransferCompletedCodingKeys: String, CodingKey {
    case transferName = "transfer_name"
    case transferSize = "transfer_size"
    case source
    case fileID = "file_id"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TransferCompletedCodingKeys.self)
    self.transferName = try container.decodeIfPresent(String.self, forKey: .transferName) ?? ""
    self.transferSize = try container.decodeIfPresent(Int64.self, forKey: .transferSize) ?? 0
    self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
    self.fileID = try container.decodeIfPresent(Int.self, forKey: .fileID) ?? 0
    try super.init(from: decoder)
  }
}
