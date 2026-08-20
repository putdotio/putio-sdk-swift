open class PutioFileFromRSSDeletedErrorEvent: PutioHistoryEvent {
  open var fileName: String
  open var fileSource: String
  open var fileSize: Int64

  enum FileFromRSSDeletedCodingKeys: String, CodingKey {
    case fileName = "file_name"
    case fileSource = "file_source"
    case fileSize = "file_size"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FileFromRSSDeletedCodingKeys.self)
    self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
    self.fileSource = try container.decodeIfPresent(String.self, forKey: .fileSource) ?? ""
    self.fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
    try super.init(from: decoder)
  }
}
