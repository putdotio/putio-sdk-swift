open class PutioUploadEvent: PutioHistoryEvent, PutioFileHistoryEvent {
  open var fileName: String
  open var fileSize: Int64
  open var fileID: Int

  enum UploadCodingKeys: String, CodingKey {
    case fileName = "file_name"
    case fileSize = "file_size"
    case fileID = "file_id"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: UploadCodingKeys.self)
    self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
    self.fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
    self.fileID = try container.decodeIfPresent(Int.self, forKey: .fileID) ?? 0
    try super.init(from: decoder)
  }
}
