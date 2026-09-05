import XCTest

@testable import PutioSDK

final class PutioSDKTransfersTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testTransfersEndpointsDecodeResponsesAndBuildExpectedRequests() async throws {
    try installMockRequestHandler { request in
      switch request.url?.path {
      case "/v2/transfers/list":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "2")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(Self.transfersListPayload(cursor: "next-transfers", total: 3).utf8)
        )
      case "/v2/transfers/list/continue":
        XCTAssertEqual(request.httpMethod, "POST")
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "1")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["cursor"], "next-transfers")
        XCTAssertNil(json["per_page"])
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(Self.transfersListPayload(cursor: nil, total: nil).utf8)
        )
      case "/v2/transfers/42":
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(Self.transferEnvelopePayload(id: 42, status: "DOWNLOADING").utf8)
        )
      case "/v2/transfers/count":
        return (
          makeHTTPResponse(for: request, statusCode: 200), Data(#"{"count":7,"status":"OK"}"#.utf8)
        )
      case "/v2/transfers/info":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["urls"], "https://example.com/a\nhttps://example.com/b")
        let payload = """
          {
            "disk_avail": 1024,
            "ret": [
              {
                "url": "https://example.com/a",
                "name": "a.iso",
                "type_name": "URL",
                "file_size": 100,
                "human_size": "100 B"
              }
            ],
            "status": "OK"
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/transfers/add":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["url"] as? String, "https://example.com/file.torrent")
        XCTAssertEqual(json["save_parent_id"] as? Int, 9)
        XCTAssertEqual(json["callback_url"] as? String, "https://example.com/callback")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(Self.transferEnvelopePayload(id: 43, status: "WAITING").utf8)
        )
      case "/v2/transfers/add-multi":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        let urls = try XCTUnwrap(json["urls"])
        let urlsData = try XCTUnwrap(urls.data(using: .utf8))
        let inputs = try XCTUnwrap(JSONSerialization.jsonObject(with: urlsData) as? [[String: Any]])
        XCTAssertEqual(inputs.first?["url"] as? String, "https://example.com/one")
        XCTAssertEqual(inputs.last?["url"] as? String, "https://example.com/two")
        let payload = """
          {
            "errors": [
              {
                "error_type": "EMPTY_URL",
                "status_code": 400,
                "url": ""
              }
            ],
            "transfers": [
              \(Self.transferPayload(id: 44, status: "IN_QUEUE"))
            ],
            "status": "OK"
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/transfers/cancel":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["transfer_ids"], "42,43")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/transfers/clean":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["transfer_ids"], "42")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"deleted_ids":[42],"status":"OK"}"#.utf8)
        )
      case "/v2/transfers/retry":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Int])
        XCTAssertEqual(json["id"], 42)
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(Self.transferEnvelopePayload(id: 42, status: "WAITING").utf8)
        )
      default:
        XCTFail("Unexpected transfers path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let listed = try await sdk.listTransfers(query: PutioTransfersListQuery(perPage: 2))
    let continued = try await sdk.continueTransfers(
      cursor: "next-transfers", query: PutioTransfersListQuery(perPage: 1))
    let fetched = try await sdk.getTransfer(id: 42)
    let count = try await sdk.countTransfers()
    let info = try await sdk.getTransferInfo(urls: [
      "https://example.com/a", "https://example.com/b",
    ])
    let added = try await sdk.addTransfer(
      PutioTransferAddInput(
        url: "https://example.com/file.torrent",
        saveParentID: 9,
        callbackURL: "https://example.com/callback"
      )
    )
    let addedMany = try await sdk.addTransfers([
      PutioTransferAddInput(url: "https://example.com/one"),
      PutioTransferAddInput(url: "https://example.com/two"),
    ])
    let cancelled = try await sdk.cancelTransfers(ids: [42, 43])
    let cleaned = try await sdk.cleanTransfers(ids: [42])
    let retried = try await sdk.retryTransfer(id: 42)

    XCTAssertEqual(listed.cursor, "next-transfers")
    XCTAssertEqual(listed.total, 3)
    XCTAssertEqual(listed.transfers.first?.status, .downloading)
    XCTAssertEqual(continued.cursor, nil)
    XCTAssertEqual(fetched.id, 42)
    XCTAssertEqual(fetched.type, .torrent)
    XCTAssertEqual(fetched.links.first?.label, "torrent")
    XCTAssertEqual(count, 7)
    XCTAssertEqual(info.diskAvailable, 1024)
    XCTAssertEqual(info.items.first?.typeName, "URL")
    XCTAssertEqual(added.id, 43)
    XCTAssertEqual(addedMany.errors.first?.errorType, "EMPTY_URL")
    XCTAssertEqual(addedMany.transfers.first?.status, .inQueue)
    XCTAssertEqual(cancelled.status, "OK")
    XCTAssertEqual(cleaned.deletedIDs, [42])
    XCTAssertEqual(retried.status, .waiting)
  }

  func testTransferModelsPreserveUnknownBackendValues() throws {
    let transfer = try JSONDecoder().decode(
      PutioTransfer.self,
      from: Data(
        Self.transferPayload(
          id: 50,
          type: "NEW_NATIVE_TYPE",
          status: "NEW_NATIVE_STATUS"
        ).utf8
      )
    )

    XCTAssertFalse(transfer.type.isKnown)
    XCTAssertEqual(transfer.type.rawValue, "NEW_NATIVE_TYPE")
    XCTAssertFalse(transfer.status.isKnown)
    XCTAssertEqual(transfer.status.rawValue, "NEW_NATIVE_STATUS")
  }

  private static func transfersListPayload(cursor: String?, total: Int?) -> String {
    let cursorValue = cursor.map { #""\#($0)""# } ?? "null"
    let totalLine = total.map { #","total":\#($0)"# } ?? ""
    return """
      {
        "cursor": \(cursorValue),
        "transfers": [
          \(transferPayload(id: 42, status: "DOWNLOADING"))
        ]\(totalLine),
        "status": "OK"
      }
      """
  }

  private static func transferEnvelopePayload(id: Int, status: String) -> String {
    """
    {
      "transfer": \(transferPayload(id: id, status: status)),
      "status": "OK"
    }
    """
  }

  private static func transferPayload(
    id: Int,
    type: String = "TORRENT",
    status: String
  ) -> String {
    """
    {
      "id": \(id),
      "name": "Ubuntu.iso",
      "source": "magnet:?xt=urn:btih:example",
      "type": "\(type)",
      "status": "\(status)",
      "save_parent_id": 0,
      "file_id": 99,
      "download_id": 100,
      "size": 1000,
      "percent_done": 50,
      "completion_percent": 50,
      "downloaded": 500,
      "uploaded": 25,
      "down_speed": 10,
      "up_speed": 1,
      "estimated_time": 60,
      "availability": 1,
      "error_message": null,
      "created_at": "2026-04-20T10:00:00Z",
      "started_at": null,
      "finished_at": null,
      "callback_url": null,
      "current_ratio": 0.5,
      "seconds_seeding": 0,
      "is_private": true,
      "links": [
        {
          "label": "torrent",
          "url": "https://api.put.io/v2/transfers/\(id)/torrent"
        }
      ],
      "userfile_exists": true
    }
    """
  }
}
