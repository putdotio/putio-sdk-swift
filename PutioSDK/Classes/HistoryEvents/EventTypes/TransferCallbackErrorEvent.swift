open class PutioTransferCallbackErrorEvent: PutioHistoryEvent {
  open var transferID: Int
  open var transferName: String
  open var message: String

  enum TransferCallbackCodingKeys: String, CodingKey {
    case transferID = "transfer_id"
    case transferName = "transfer_name"
    case message
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: TransferCallbackCodingKeys.self)
    self.transferID = try container.decodeIfPresent(Int.self, forKey: .transferID) ?? 0
    self.transferName = try container.decodeIfPresent(String.self, forKey: .transferName) ?? ""
    self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
    try super.init(from: decoder)
  }
}
