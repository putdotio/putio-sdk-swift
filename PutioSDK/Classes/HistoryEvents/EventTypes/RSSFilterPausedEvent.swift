open class PutioRSSFilterPausedEvent: PutioHistoryEvent {
  open var rssFilterID: Int
  open var rssFilterTitle: String

  enum RSSFilterPausedCodingKeys: String, CodingKey {
    case rssFilterID = "rss_filter_id"
    case rssFilterTitle = "rss_filter_title"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: RSSFilterPausedCodingKeys.self)
    self.rssFilterID = try container.decodeIfPresent(Int.self, forKey: .rssFilterID) ?? 0
    self.rssFilterTitle = try container.decodeIfPresent(String.self, forKey: .rssFilterTitle) ?? ""
    try super.init(from: decoder)
  }
}
