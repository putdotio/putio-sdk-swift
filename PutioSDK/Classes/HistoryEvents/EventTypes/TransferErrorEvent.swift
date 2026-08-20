open class PutioTransferErrorEvent: PutioHistoryEvent {
  open var source: String
  open var transferName: String

  enum TransferErrorCodingKeys: String, CodingKey {
    case source
    case transferName = "transfer_name"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TransferErrorCodingKeys.self)
    self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
    self.transferName = try container.decodeIfPresent(String.self, forKey: .transferName) ?? ""
    try super.init(from: decoder)
  }
}
