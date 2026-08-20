open class PutioVoucherEvent: PutioHistoryEvent {
  open var voucherID: Int
  open var voucherOwnerID: Int
  open var voucherOwnerName: String

  enum VoucherCodingKeys: String, CodingKey {
    case voucherID = "voucher"
    case voucherOwnerID = "voucher_owner_id"
    case voucherOwnerName = "voucher_owner_name"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: VoucherCodingKeys.self)
    self.voucherID = try container.decodeIfPresent(Int.self, forKey: .voucherID) ?? 0
    self.voucherOwnerID = try container.decodeIfPresent(Int.self, forKey: .voucherOwnerID) ?? 0
    self.voucherOwnerName =
      try container.decodeIfPresent(String.self, forKey: .voucherOwnerName) ?? ""
    try super.init(from: decoder)
  }
}
