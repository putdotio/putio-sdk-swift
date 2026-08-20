open class PutioFileSharedEvent: PutioHistoryEvent, PutioFileHistoryEvent {
  open var sharingUserName: String
  open var fileName: String
  open var fileSize: Int64
  open var fileID: Int

  enum FileSharedCodingKeys: String, CodingKey {
    case sharingUserName = "sharing_user_name"
    case fileName = "file_name"
    case fileSize = "file_size"
    case fileID = "file_id"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FileSharedCodingKeys.self)
    self.sharingUserName =
      try container.decodeIfPresent(String.self, forKey: .sharingUserName) ?? ""
    self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
    self.fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
    self.fileID = try container.decodeIfPresent(Int.self, forKey: .fileID) ?? 0
    try super.init(from: decoder)
  }
}
