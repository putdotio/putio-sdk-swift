open class PutioHistoryEventFactory {
  static func decode(rawType: String, from decoder: Decoder) throws -> PutioHistoryEvent {
    switch rawType.lowercased() {
    case "upload":
      return try PutioUploadEvent(from: decoder)
    case "file_shared":
      return try PutioFileSharedEvent(from: decoder)
    case "transfer_completed":
      return try PutioTransferCompletedEvent(from: decoder)
    case "transfer_error":
      return try PutioTransferErrorEvent(from: decoder)
    case "file_from_rss_deleted_for_space":
      return try PutioFileFromRSSDeletedErrorEvent(from: decoder)
    case "rss_filter_paused":
      return try PutioRSSFilterPausedEvent(from: decoder)
    case "transfer_from_rss_error":
      return try PutioTransferFromRSSErrorEvent(from: decoder)
    case "transfer_callback_error":
      return try PutioTransferCallbackErrorEvent(from: decoder)
    case "private_torrent_pin":
      return try PutioPrivateTorrentPinEvent(from: decoder)
    case "voucher":
      return try PutioVoucherEvent(from: decoder)
    case "zip_created":
      return try PutioZipCreatedEvent(from: decoder)
    default:
      return try PutioHistoryEvent(from: decoder)
    }
  }
}
