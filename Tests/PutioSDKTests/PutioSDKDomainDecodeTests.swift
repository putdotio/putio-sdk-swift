import XCTest

@testable import PutioSDK

final class PutioSDKDomainDecodeTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testGetRoutesDecodesTypedRoutes() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/tunnel/routes")

      let payload = """
        {
          "routes": [
            {
              "name": "default",
              "description": "Default route",
              "hosts": ["a.put.io", "b.put.io"]
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let routes = try await sdk.getRoutes()

    XCTAssertEqual(routes.count, 1)
    XCTAssertEqual(routes.first?.name, "default")
    XCTAssertEqual(routes.first?.hosts, ["a.put.io", "b.put.io"])
  }

  func testGetGrantsDecodesAppList() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth/grants")

      let payload = """
        {
          "apps": [
            {
              "id": 5,
              "name": "Calendar Sync",
              "description": "Calendar integration",
              "website": "https://example.com",
              "has_icon": true
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let grants = try await sdk.getGrants()

    XCTAssertEqual(grants.count, 1)
    XCTAssertEqual(grants.first?.id, 5)
    XCTAssertEqual(grants.first?.website?.absoluteString, "https://example.com")
    XCTAssertEqual(grants.first?.hasIcon, true)
  }

  func testGetClientsDecodesSessionsWithDefaults() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth/clients")
      let payload = """
        {
          "status": "OK",
          "clients": [
            {
              "id": 11,
              "app_id": 5,
              "app_name": "Calendar Sync",
              "client_name": "iPhone",
              "created_at": "2026-10-01T09:00:00",
              "last_used_at": "2026-11-09T18:30:00",
              "active": true
            },
            { "id": 12, "app_id": 6 }
          ]
        }
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }
    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let clients = try await sdk.getClients()

    XCTAssertEqual(
      clients,
      [
        PutioOAuthClient(
          id: 11, appID: 5, appName: "Calendar Sync", clientName: "iPhone",
          createdAt: "2026-10-01T09:00:00", lastUsedAt: "2026-11-09T18:30:00", isActive: true),
        PutioOAuthClient(id: 12, appID: 6),
      ])
  }

  func testGetAppIconReturnsTheImageBytesWithTheToken() async throws {
    let png = Data([0x89, 0x50, 0x4E, 0x47])
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/oauth/apps/5/icon")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token token-123")
      return (makeHTTPResponse(for: request, statusCode: 200), png)
    }
    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let icon = try await sdk.getAppIcon(appID: 5)

    XCTAssertEqual(icon, png)
  }

  func testGetAppIconThrowsOnAMissingIcon() async throws {
    try installMockRequestHandler { request in
      (makeHTTPResponse(for: request, statusCode: 404), Data())
    }
    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.getAppIcon(appID: 5)
      XCTFail("a missing icon returned bytes")
    } catch let error as PutioSDKError {
      XCTAssertEqual(error.statusCode, 404)
    }
  }

  func testGetSubtitlesPreservesOauthTokenQueryAndDecodesResponse() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/subtitles")
      let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      XCTAssertEqual(
        components?.queryItems?.first(where: { $0.name == "oauth_token" })?.value, "token-123")

      let payload = """
        {
          "default": "all",
          "subtitles": [
            {
              "format": "vtt",
              "key": "all",
              "language": "English",
              "language_code": "en",
              "name": "English",
              "source": "put.io",
              "url": "https://example.com/subtitles/en.vtt"
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.getSubtitles(fileID: 42)

    XCTAssertEqual(response.defaultKey, "all")
    XCTAssertEqual(response.subtitles.count, 1)
    XCTAssertEqual(response.subtitles.first?.format, "vtt")
    XCTAssertEqual(response.subtitles.first?.languageCode, "en")
    XCTAssertEqual(response.subtitles.first?.url, "https://example.com/subtitles/en.vtt")
  }

  func testSearchFilesDecodesTypedFilesAndCursor() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/files/search")
      let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "query" })?.value, "matrix")
      XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "25")

      let payload = """
        {
          "cursor": "page-2",
          "total": 1,
          "files": [
            {
              "id": 7,
              "name": "The Matrix.mkv",
              "size": 100,
              "created_at": "2026-04-20T10:00:00Z",
              "updated_at": "2026-04-20T10:00:00Z",
              "file_type": "VIDEO",
              "parent_id": 1
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.searchFiles(
      query: PutioFileSearchQuery(keyword: "matrix", perPage: 25))

    XCTAssertEqual(response.cursor, Optional("page-2"))
    XCTAssertEqual(response.total, 1)
    XCTAssertEqual(response.files.count, 1)
    XCTAssertEqual(response.files.first?.name, "The Matrix.mkv")
    XCTAssertEqual(response.files.first?.type, .video)
  }

  func testSearchFilesPreservesNullCursor() throws {
    let payload = """
      {
        "cursor": null,
        "total": 0,
        "files": []
      }
      """

    let response = try JSONDecoder().decode(PutioFileSearchResponse.self, from: Data(payload.utf8))

    XCTAssertNil(response.cursor)
    XCTAssertEqual(response.total, 0)
    XCTAssertTrue(response.files.isEmpty)
  }

  func testSearchFilesRequiresBackendTotal() throws {
    let payload = """
      {
        "cursor": null,
        "files": []
      }
      """

    XCTAssertThrowsError(
      try JSONDecoder().decode(PutioFileSearchResponse.self, from: Data(payload.utf8)))
  }

  func testGetMp4ConversionStatusDecodesTypedStatus() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/mp4")

      let payload = """
        {
          "mp4": {
            "percent_done": 35,
            "status": "CONVERTING"
          }
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let conversion = try await sdk.getMp4ConversionStatus(fileID: 42)

    XCTAssertEqual(conversion.percentDone, 0.35, accuracy: 0.001)
    XCTAssertEqual(conversion.status, .converting)
    XCTAssertTrue(conversion.status.isKnown)
  }

  func testGetStartFromDecodesNumericStartPosition() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/start-from")

      let payload = """
        {
          "start_from": 91.7
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let startFrom = try await sdk.getStartFrom(fileID: 42)

    XCTAssertEqual(startFrom, 91)
  }

  func testGetHistoryEventsDecodesConcreteEventTypes() async throws {
    try installMockRequestHandler { request in
      XCTAssertEqual(request.url?.path, "/v2/events/list")
      let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "25")
      XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "before" })?.value, "100")

      let payload = """
        {
          "status": "OK",
          "has_more": false,
          "events": [
            {
              "id": 1,
              "user_id": 42,
              "type": "transfer_completed",
              "created_at": "2026-04-20T10:00:00Z",
              "transfer_name": "Movie torrent",
              "transfer_size": 1000,
              "source": "magnet:?xt=urn:btih:123",
              "file_id": 9
            },
            {
              "id": 2,
              "user_id": 42,
              "type": "mystery_future_event",
              "created_at": "2026-04-20T11:00:00Z"
            }
          ]
        }
        """

      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let response = try await sdk.getHistoryEvents(
      query: PutioHistoryEventsQuery(perPage: 25, before: 100))
    let events = response.events

    XCTAssertEqual(response.status, "OK")
    XCTAssertEqual(response.hasMore, false)
    XCTAssertEqual(events.count, 2)
    XCTAssertTrue(events.first is PutioTransferCompletedEvent)
    XCTAssertEqual(events.first?.type, .transferCompleted)
    XCTAssertEqual((events.first as? PutioTransferCompletedEvent)?.fileID, 9)
    XCTAssertEqual(events.last?.type, .other)
  }
}
