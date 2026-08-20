import XCTest

@testable import PutioSDK

final class PutioSDKTrashTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testTrashEndpointsDecodeResponsesAndBuildExpectedBodies() async throws {
    MockURLProtocol.requestHandler = { request in
      switch request.url?.path {
      case "/v2/trash/list":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "25")
        let payload = """
          {
            "cursor": "trash-page-2",
            "total": 1,
            "trash_size": 99,
            "files": [
              {
                "id": 10,
                "name": "Old episode",
                "icon": "video",
                "parent_id": 2,
                "size": 123,
                "created_at": "2026-04-20T10:00:00Z",
                "file_type": "VIDEO",
                "deleted_at": "2026-04-21T10:00:00Z",
                "expiration_date": "2026-05-01T10:00:00Z"
              }
            ]
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/trash/list/continue":
        XCTAssertEqual(request.httpMethod, "POST")
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertNil(components?.queryItems?.first(where: { $0.name == "cursor" }))
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "10")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["cursor"], "trash-page-2")
        XCTAssertNil(json["per_page"])
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"cursor":"done","trash_size":0,"files":[]}"#.utf8)
        )
      case "/v2/trash/restore":
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["file_ids"], "10,11")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/trash/delete":
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["cursor"], "trash-page-2")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"status":"OK","cursor":"deleted"}"#.utf8)
        )
      case "/v2/trash/empty":
        XCTAssertEqual(request.httpMethod, "POST")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      default:
        XCTFail("Unexpected trash path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let listed = try await sdk.listTrash(query: PutioTrashListQuery(perPage: 25))
    let continued = try await sdk.continueListTrash(
      cursor: "trash-page-2", query: PutioTrashListQuery(perPage: 10))
    let restored = try await sdk.restoreTrashFiles(fileIDs: [10, 11], cursor: nil)
    let deleted = try await sdk.deleteTrashFiles(fileIDs: [], cursor: "trash-page-2")
    let emptied = try await sdk.emptyTrash()

    XCTAssertEqual(listed.cursor, Optional("trash-page-2"))
    XCTAssertEqual(listed.total, 1)
    XCTAssertEqual(listed.trashSize, 99)
    XCTAssertEqual(listed.files.first?.name, "Old episode")
    XCTAssertEqual(continued.cursor, Optional("done"))
    XCTAssertEqual(restored.status, "OK")
    XCTAssertEqual(deleted.cursor, "deleted")
    XCTAssertEqual(emptied.status, "OK")
  }

  func testTrashModelsDecodeDefaultEmptyPayloads() throws {
    let decoder = JSONDecoder()
    let response = try decoder.decode(PutioListTrashResponse.self, from: Data(#"{}"#.utf8))

    XCTAssertNil(response.cursor)
    XCTAssertNil(response.total)
    XCTAssertEqual(response.trashSize, 0)
    XCTAssertTrue(response.files.isEmpty)
  }

  func testTrashListQueryBuildsOptionalPaginationParameters() {
    XCTAssertEqual(PutioTrashListQuery(perPage: 10).parameters["per_page"], .integer(10))
    XCTAssertTrue(PutioTrashListQuery(perPage: nil).parameters.isEmpty)
  }
}
