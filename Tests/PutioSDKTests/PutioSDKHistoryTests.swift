import XCTest

@testable import PutioSDK

final class PutioSDKHistoryTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testHistoryEndpointsDecodeAllConcreteEventTypes() async throws {
    try installMockRequestHandler { request in
      switch request.url?.path {
      case "/v2/events/list":
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "25")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "before" })?.value, "100")

        let payload = """
          {
            "status": "OK",
            "has_more": true,
            "events": [
              { "id": 1, "user_id": 42, "type": "upload", "created_at": "2026-04-20T10:00:00Z", "file_name": "Episode.mkv", "file_size": 10, "file_id": 9 },
              { "id": 2, "user_id": 42, "type": "file_shared", "created_at": "2026-04-20T10:01:00Z", "sharing_user_name": "bob", "file_name": "Movie.mkv", "file_size": 11, "file_id": 10 },
              { "id": 3, "user_id": 42, "type": "transfer_completed", "created_at": "2026-04-20T10:02:00Z", "transfer_name": "Torrent", "transfer_size": 12, "source": "magnet:?xt=1", "file_id": 11 },
              { "id": 4, "user_id": 42, "type": "transfer_error", "created_at": "2026-04-20T10:03:00Z", "source": "magnet:?xt=2", "transfer_name": "Broken" },
              { "id": 5, "user_id": 42, "type": "file_from_rss_deleted_for_space", "created_at": "2026-04-20T10:04:00Z", "file_name": "News.mp4", "file_source": "rss", "file_size": 13 },
              { "id": 6, "user_id": 42, "type": "rss_filter_paused", "created_at": "2026-04-20T10:05:00Z", "rss_filter_id": 99, "rss_filter_title": "Sci-Fi" },
              { "id": 7, "user_id": 42, "type": "transfer_from_rss_error", "created_at": "2026-04-20T10:06:00Z", "rss_id": 77, "transfer_name": "Feed Torrent" },
              { "id": 8, "user_id": 42, "type": "transfer_callback_error", "created_at": "2026-04-20T10:07:00Z", "transfer_id": 55, "transfer_name": "Callback Torrent", "message": "Webhook rejected" },
              { "id": 9, "user_id": 42, "type": "private_torrent_pin", "created_at": "2026-04-20T10:08:00Z", "user_download_name": "Linux ISO", "pinned_host_ip": "1.1.1.1", "new_host_ip": "2.2.2.2" },
              { "id": 10, "user_id": 42, "type": "voucher", "created_at": "2026-04-20T10:09:00Z", "voucher": 123, "voucher_owner_id": 456, "voucher_owner_name": "alice" },
              { "id": 11, "user_id": 42, "type": "zip_created", "created_at": "2026-04-20T10:10:00Z", "zip_id": 789, "zip_size": 14 },
              { "id": 12, "user_id": 42, "type": "future_new_event", "created_at": "2026-04-20T10:11:00Z" }
            ]
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/events/delete":
        XCTAssertEqual(request.httpMethod, "POST")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/events/delete/12":
        XCTAssertEqual(request.httpMethod, "POST")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      default:
        XCTFail("Unexpected history path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.getHistoryEvents(
      query: PutioHistoryEventsQuery(perPage: 25, before: 100))
    let events = response.events
    let cleared = try await sdk.clearHistoryEvents()
    let deleted = try await sdk.deleteHistoryEvent(eventID: 12)

    XCTAssertEqual(response.status, "OK")
    XCTAssertEqual(response.hasMore, true)
    XCTAssertEqual(events.count, 12)
    XCTAssertTrue(events[0] is PutioUploadEvent)
    XCTAssertEqual((events[0] as? PutioUploadEvent)?.fileID, 9)
    XCTAssertTrue(events[1] is PutioFileSharedEvent)
    XCTAssertEqual((events[1] as? PutioFileSharedEvent)?.sharingUserName, "bob")
    XCTAssertTrue(events[2] is PutioTransferCompletedEvent)
    XCTAssertEqual((events[2] as? PutioTransferCompletedEvent)?.source, "magnet:?xt=1")
    XCTAssertTrue(events[3] is PutioTransferErrorEvent)
    XCTAssertEqual((events[3] as? PutioTransferErrorEvent)?.transferName, "Broken")
    XCTAssertTrue(events[4] is PutioFileFromRSSDeletedErrorEvent)
    XCTAssertEqual((events[4] as? PutioFileFromRSSDeletedErrorEvent)?.fileSource, "rss")
    XCTAssertTrue(events[5] is PutioRSSFilterPausedEvent)
    XCTAssertEqual((events[5] as? PutioRSSFilterPausedEvent)?.rssFilterID, 99)
    XCTAssertTrue(events[6] is PutioTransferFromRSSErrorEvent)
    XCTAssertEqual((events[6] as? PutioTransferFromRSSErrorEvent)?.rssID, 77)
    XCTAssertTrue(events[7] is PutioTransferCallbackErrorEvent)
    XCTAssertEqual((events[7] as? PutioTransferCallbackErrorEvent)?.message, "Webhook rejected")
    XCTAssertTrue(events[8] is PutioPrivateTorrentPinEvent)
    XCTAssertEqual((events[8] as? PutioPrivateTorrentPinEvent)?.newHostIP, "2.2.2.2")
    XCTAssertTrue(events[9] is PutioVoucherEvent)
    XCTAssertEqual((events[9] as? PutioVoucherEvent)?.voucherOwnerName, "alice")
    XCTAssertTrue(events[10] is PutioZipCreatedEvent)
    XCTAssertEqual((events[10] as? PutioZipCreatedEvent)?.zipID, 789)
    XCTAssertEqual(events[11].type, .other)
    XCTAssertEqual(cleared.status, "OK")
    XCTAssertEqual(deleted.status, "OK")
  }
}
