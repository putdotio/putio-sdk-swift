open class PutioPrivateTorrentPinEvent: PutioHistoryEvent {
  open var userDownloadName: String
  open var pinnedHostIP: String
  open var newHostIP: String

  enum PrivateTorrentPinCodingKeys: String, CodingKey {
    case userDownloadName = "user_download_name"
    case pinnedHostIP = "pinned_host_ip"
    case newHostIP = "new_host_ip"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: PrivateTorrentPinCodingKeys.self)
    self.userDownloadName =
      try container.decodeIfPresent(String.self, forKey: .userDownloadName) ?? ""
    self.pinnedHostIP = try container.decodeIfPresent(String.self, forKey: .pinnedHostIP) ?? ""
    self.newHostIP = try container.decodeIfPresent(String.self, forKey: .newHostIP) ?? ""
    try super.init(from: decoder)
  }
}
