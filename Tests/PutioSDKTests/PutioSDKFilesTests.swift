import XCTest

@testable import PutioSDK

final class PutioSDKFilesTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testOptionalNextFileMapsSuccessorAndAbsence() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    var responses = [
      """
      {
        "next_file": {
          "id": 43,
          "name": "Episode 2.mkv",
          "parent_id": 7
        }
      }
      """,
      #"{"next_file":null}"#,
    ]
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/next-file")
      let components = URLComponents(
        url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
      XCTAssertEqual(
        components?.queryItems?.first(where: { $0.name == "file_type" })?.value, "VIDEO")
      return (makeHTTPResponse(for: request, statusCode: 200), Data(responses.removeFirst().utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let successor = try await sdk.findNextFileIfAvailable(fileID: 42, fileType: .video)
    let absent = try await sdk.findNextFileIfAvailable(fileID: 42, fileType: .video)

    XCTAssertEqual(successor?.id, 43)
    XCTAssertEqual(successor?.name, "Episode 2.mkv")
    XCTAssertEqual(successor?.parentID, 7)
    XCTAssertEqual(successor?.type, .video)
    XCTAssertNil(absent)
  }

  func testOptionalNextFileRejectsMissingEnvelopeKey() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/42/next-file")
      return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{}"#.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.findNextFileIfAvailable(fileID: 42, fileType: .video)
      XCTFail("Expected a missing next_file key to fail decoding")
    } catch let error as PutioSDKError {
      XCTAssertTrue(error.isDecodingFailure)
    } catch {
      XCTFail("Expected PutioSDKError, got \(type(of: error))")
    }
  }

  func testFilesAndMediaEndpointsDecodeResponsesAndBuildExpectedRequests() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      switch request.url?.path {
      case "/v2/files/list":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "parent_id" })?.value, "7")
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "sort_by" })?.value, "NAME_ASC")
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "mp4_status_parent" })?.value, "1")
        let payload = """
          {
            "parent": {
              "id": 7,
              "name": "Shows",
              "icon": "folder",
              "parent_id": 0,
              "size": 0,
              "created_at": "2026-04-20T10:00:00Z",
              "updated_at": "2026-04-20T10:00:00Z",
              "file_type": "FOLDER",
              "folder_type": "SHARED_ROOT",
              "sort_by": "NAME_ASC"
            },
            "files": [
              {
                "id": 42,
                "name": "Episode.mkv",
                "icon": "video",
                "parent_id": 7,
                "size": 100,
                "created_at": "2026-04-20T10:00:00Z",
                "updated_at": "2026-04-20T10:00:00Z",
                "file_type": "VIDEO",
                "video_metadata": {
                  "height": 1080,
                  "width": 1920,
                  "codec": "h264",
                  "duration": 90.5,
                  "aspect_ratio": 1.78
                },
                "start_from": 91.7,
                "need_convert": true,
                "is_mp4_available": true,
                "mp4_size": 88,
                "mp4_stream_url": "https://example.com/mp4",
                "stream_url": "https://example.com/stream"
              }
            ],
            "cursor": "next-page",
            "total": 1
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/42":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "mp4_size" })?.value, "1")
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "start_from" })?.value, "1")
        let payload = """
          {
            "file": {
              "id": 42,
              "name": "Episode.mkv",
              "icon": "video",
              "parent_id": 7,
              "size": 100,
              "created_at": "2026-04-20T10:00:00Z",
              "updated_at": "2026-04-20T10:00:00Z",
              "file_type": "VIDEO"
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/create-folder":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Season 2")
        XCTAssertEqual(json["parent_id"] as? Int, 7)
        let payload = """
          {
            "file": {
              "id": 77,
              "name": "Season 2",
              "icon": "folder",
              "parent_id": 7,
              "size": 0,
              "created_at": "2026-04-20T10:00:00Z",
              "updated_at": "2026-04-20T10:00:00Z",
              "file_type": "FOLDER"
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/delete":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertNotNil(components?.queryItems?.first(where: { $0.name == "skip_nonexistents" }))
        XCTAssertNotNil(components?.queryItems?.first(where: { $0.name == "skip_owner_check" }))
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["file_ids"], "42,43")
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          Data(#"{"status":"OK","cursor":"after-delete","skipped":1}"#.utf8)
        )
      case "/v2/files/copy-to-disk":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["file_ids"], "42")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/files/rename":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["file_id"] as? Int, 42)
        XCTAssertEqual(json["name"] as? String, "Episode 2.mkv")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/files/42/next-file":
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(
          components?.queryItems?.first(where: { $0.name == "file_type" })?.value, "VIDEO")
        let payload = """
          {
            "next_file": {
              "id": 43,
              "name": "Episode 2.mkv",
              "parent_id": 7
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/set-sort-by":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["file_id"] as? Int, 42)
        XCTAssertEqual(json["sort_by"] as? String, "NAME_ASC")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/files/remove-sort-by-settings":
        XCTAssertEqual(request.httpMethod, "POST")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/files/search/continue":
        XCTAssertEqual(request.httpMethod, "POST")
        let components = URLComponents(
          url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "10")
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["cursor"], "search-page-2")
        let payload = """
          {
            "cursor": "search-done",
            "total": 1,
            "files": [
              {
                "id": 90,
                "name": "Episode 3.mkv",
                "size": 100,
                "created_at": "2026-04-20T10:00:00Z",
                "updated_at": "2026-04-20T10:00:00Z",
                "file_type": "VIDEO",
                "parent_id": 7
              }
            ]
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/42/mp4":
        if request.httpMethod == "POST" {
          return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
        }
        let payload = """
          {
            "mp4": {
              "percent_done": 100,
              "status": "COMPLETED"
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      case "/v2/files/42/start-from/set":
        let body = try XCTUnwrap(requestBodyData(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Int])
        XCTAssertEqual(json["time"], 91)
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      case "/v2/files/42/start-from/delete":
        XCTAssertEqual(request.httpMethod, "GET")
        return (makeHTTPResponse(for: request, statusCode: 200), Data(#"{"status":"OK"}"#.utf8))
      default:
        XCTFail("Unexpected files path \(request.url?.path ?? "<nil>")")
        return (makeHTTPResponse(for: request, statusCode: 404), Data())
      }
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let listed = try await sdk.getFiles(parentID: 7, query: PutioFilesListQuery(sortBy: "NAME_ASC"))
    let file = try await sdk.getFile(fileID: 42)
    let folder = try await sdk.createFolder(name: "Season 2", parentID: 7)
    let deleted = try await sdk.deleteFiles(fileIDs: [42, 43])
    let copied = try await sdk.copyFiles(fileIDs: [42])
    let renamed = try await sdk.renameFile(fileID: 42, name: "Episode 2.mkv")
    let nextFile = try await sdk.findNextFile(fileID: 42, fileType: .video)
    let sorted = try await sdk.setSortBy(fileId: 42, sortBy: "NAME_ASC")
    let resetSort = try await sdk.resetFileSpecificSortSettings()
    let continuedSearch = try await sdk.continueFileSearch(
      cursor: "search-page-2", query: PutioFileSearchContinueQuery(perPage: 10))
    let startedConversion = try await sdk.startMp4Conversion(fileID: 42)
    let conversion = try await sdk.getMp4ConversionStatus(fileID: 42)
    let setStartFrom = try await sdk.setStartFrom(fileID: 42, time: 91)
    let resetStartFrom = try await sdk.resetStartFrom(fileID: 42)

    XCTAssertEqual(listed.parent?.name, "Shows")
    XCTAssertEqual(listed.parent?.isSharedRoot, true)
    XCTAssertEqual(listed.children.first?.metaData?.width, 1920)
    XCTAssertEqual(listed.children.first?.startFrom, 91)
    XCTAssertEqual(listed.cursor, "next-page")
    XCTAssertEqual(listed.total, 1)
    XCTAssertEqual(file.id, 42)
    XCTAssertEqual(folder.name, "Season 2")
    XCTAssertEqual(deleted.cursor, "after-delete")
    XCTAssertEqual(deleted.skipped, 1)
    XCTAssertEqual(copied.status, "OK")
    XCTAssertEqual(renamed.status, "OK")
    XCTAssertEqual(nextFile.id, 43)
    XCTAssertEqual(nextFile.type, .video)
    XCTAssertEqual(sorted.status, "OK")
    XCTAssertEqual(resetSort.status, "OK")
    XCTAssertEqual(continuedSearch.cursor, Optional("search-done"))
    XCTAssertEqual(continuedSearch.files.first?.name, "Episode 3.mkv")
    XCTAssertEqual(startedConversion.status, "OK")
    XCTAssertEqual(conversion.status, .completed)
    XCTAssertEqual(conversion.percentDone, 1.0, accuracy: 0.001)
    XCTAssertEqual(setStartFrom.status, "OK")
    XCTAssertEqual(resetStartFrom.status, "OK")
  }

  func testResolveVideoPlaybackSourceBuildsAuthenticatedHLSURLAndMapsStartFrom() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/custom/v2/files/42")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token token / value")

      let components = URLComponents(
        url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
      let queryItems = Dictionary(
        uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
      XCTAssertEqual(queryItems.count, 2)
      XCTAssertEqual(queryItems["mp4_status"], "1")
      XCTAssertEqual(queryItems["start_from"], "1")

      return (
        makeHTTPResponse(for: request, statusCode: 200),
        playbackFileEnvelope(fileID: 42, fileType: "VIDEO", needConvert: false, startFrom: 91.7)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(
        baseURL: "https://media.example.test/custom/v2/",
        clientID: "ios-app",
        token: "token / value"
      ),
      urlSession: makeTestSession()
    )

    let resolution = try await sdk.resolveVideoPlaybackSource(fileID: 42)

    guard case .ready(let source) = resolution else {
      return XCTFail("Expected an HLS playback source")
    }

    let components = URLComponents(url: source.url, resolvingAgainstBaseURL: false)
    let queryItems = Dictionary(
      uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
    XCTAssertEqual(components?.scheme, "https")
    XCTAssertEqual(components?.host, "media.example.test")
    XCTAssertEqual(components?.path, "/custom/v2/files/42/hls/media.m3u8")
    XCTAssertEqual(queryItems["subtitle_key"], "all")
    XCTAssertEqual(queryItems["oauth_token"], "token / value")
    XCTAssertEqual(source.startFrom, 91)
  }

  func testResolveVideoPlaybackSourceUsesOneConfigSnapshotAcrossSuspension() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    let requestStarted = expectation(description: "metadata request started")
    let allowResponse = expectation(description: "metadata response allowed")
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.host, "old.example.test")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token old-token")
      requestStarted.fulfill()
      guard XCTWaiter.wait(for: [allowResponse], timeout: 5) == .completed else {
        throw URLError(.timedOut)
      }
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        playbackFileEnvelope(fileID: 42, fileType: "VIDEO", needConvert: false, startFrom: 12)
      )
    }

    let owner = PlaybackResolverOwner(
      config: PutioSDKConfig(
        baseURL: "https://old.example.test/v2",
        clientID: "ios-app",
        token: "old-token"
      ),
      urlSession: makeTestSession()
    )
    let resolutionTask = Task {
      try await owner.resolveVideoPlaybackSource(fileID: 42)
    }

    await fulfillment(of: [requestStarted], timeout: 5)

    await owner.replaceConfig(
      PutioSDKConfig(
        baseURL: "https://new.example.test/v2",
        clientID: "ios-app",
        token: "new-token"
      ))
    allowResponse.fulfill()

    let resolution = try await resolutionTask.value
    guard case .ready(let source) = resolution else {
      return XCTFail("Expected an HLS playback source")
    }
    let components = URLComponents(url: source.url, resolvingAgainstBaseURL: false)
    XCTAssertEqual(components?.host, "old.example.test")
    XCTAssertEqual(
      components?.queryItems?.first(where: { $0.name == "oauth_token" })?.value,
      "old-token"
    )
  }

  func testResolveVideoPlaybackSourceReportsConversionRequired() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/43")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        playbackFileEnvelope(fileID: 43, fileType: "VIDEO", needConvert: true, startFrom: 0)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let resolution = try await sdk.resolveVideoPlaybackSource(fileID: 43)

    XCTAssertEqual(resolution, .conversionRequired)
  }

  func testResolveVideoPlaybackSourceRejectsNonVideoWithTypedRecovery() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/44")
      return (
        makeHTTPResponse(for: request, statusCode: 200),
        playbackFileEnvelope(fileID: 44, fileType: "AUDIO", needConvert: nil, startFrom: 12)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.resolveVideoPlaybackSource(fileID: 44)
      XCTFail("Expected a non-video file to be rejected")
    } catch let error as PutioVideoPlaybackResolutionError {
      XCTAssertEqual(error, .unsupportedFileType(.audio))
      XCTAssertEqual(error.errorDescription, "Only video files can be resolved for video playback.")
      XCTAssertEqual(error.recoverySuggestion, "Choose a video file and try again.")
    } catch {
      XCTFail("Expected PutioVideoPlaybackResolutionError, got \(type(of: error))")
    }
  }

  func testResolveVideoPlaybackSourcePreservesTypedAPIErrors() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/404")
      return (
        makeHTTPResponse(for: request, statusCode: 404),
        Data(#"{"error_type":"NOT_FOUND","message":"File not found"}"#.utf8)
      )
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.resolveVideoPlaybackSource(fileID: 404)
      XCTFail("Expected a missing file to fail")
    } catch let error as PutioSDKError {
      XCTAssertTrue(error.isNotFound)
      XCTAssertEqual(error.apiErrorType, "NOT_FOUND")
    } catch {
      XCTFail("Expected PutioSDKError, got \(type(of: error))")
    }
  }

  func testResolveVideoPlaybackSourcePreservesTypedTransportErrors() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/45")
      throw URLError(.notConnectedToInternet)
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    do {
      _ = try await sdk.resolveVideoPlaybackSource(fileID: 45)
      XCTFail("Expected a transport failure")
    } catch let error as PutioSDKError {
      XCTAssertTrue(error.isNetworkFailure)
      XCTAssertEqual((error.underlyingError as? URLError)?.code, .notConnectedToInternet)
    } catch {
      XCTFail("Expected PutioSDKError, got \(type(of: error))")
    }
  }

  func testResolveVideoPlaybackSourceRejectsMissingRequiredVideoState() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    let cases = [
      (fileID: 46, providedState: #""start_from": 0"#),
      (fileID: 47, providedState: #""need_convert": false"#),
    ]

    for testCase in cases {
      MockURLProtocol.requestHandler = { request in
        XCTAssertEqual(request.url?.path, "/v2/files/\(testCase.fileID)")
        let payload = """
          {
            "file": {
              "id": \(testCase.fileID),
              "file_type": "VIDEO",
              \(testCase.providedState)
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      }

      let sdk = PutioSDK(
        config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
        urlSession: makeTestSession()
      )

      do {
        _ = try await sdk.resolveVideoPlaybackSource(fileID: testCase.fileID)
        XCTFail("Expected missing video state to fail decoding")
      } catch let error as PutioSDKError {
        XCTAssertTrue(error.isDecodingFailure)
      } catch {
        XCTFail("Expected PutioSDKError, got \(type(of: error))")
      }
    }
  }

  func testResolveVideoPlaybackSourceRejectsInvalidStartFromValues() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    let cases = [
      (fileID: 48, startFrom: "-1"),
      (fileID: 49, startFrom: "1e100"),
    ]

    for testCase in cases {
      MockURLProtocol.requestHandler = { request in
        XCTAssertEqual(request.url?.path, "/v2/files/\(testCase.fileID)")
        let payload = """
          {
            "file": {
              "id": \(testCase.fileID),
              "file_type": "VIDEO",
              "need_convert": false,
              "start_from": \(testCase.startFrom)
            }
          }
          """
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      }

      let sdk = PutioSDK(
        config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
        urlSession: makeTestSession()
      )

      do {
        _ = try await sdk.resolveVideoPlaybackSource(fileID: testCase.fileID)
        XCTFail("Expected invalid start-from state to fail decoding")
      } catch let error as PutioSDKError {
        XCTAssertTrue(error.isDecodingFailure)
      } catch {
        XCTFail("Expected PutioSDKError, got \(type(of: error))")
      }
    }
  }

  func testResolveVideoPlaybackSourceAcceptsIntMaxStartFrom() async throws {
    try skipUnlessURLProtocolMockingIsSupported()
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/v2/files/50")
      let payload = """
        {
          "file": {
            "id": 50,
            "file_type": "VIDEO",
            "need_convert": false,
            "start_from": \(Int.max)
          }
        }
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let sdk = PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )

    let resolution = try await sdk.resolveVideoPlaybackSource(fileID: 50)

    guard case .ready(let source) = resolution else {
      return XCTFail("Expected an HLS playback source")
    }
    XCTAssertEqual(source.startFrom, Int.max)
  }

  func testFileModelsCoverKnownUnknownAndHelperURLs() throws {
    let decoder = JSONDecoder()

    let videoFile = try decoder.decode(
      PutioFile.self,
      from: Data(
        """
        {
          "id": 42,
          "name": "Episode.mkv",
          "icon": "video",
          "parent_id": 7,
          "size": 100,
          "created_at": "2026-04-20T10:00:00Z",
          "updated_at": "2026-04-20T10:00:00Z",
          "file_type": "VIDEO",
          "folder_type": "SHARED_ROOT",
          "sort_by": "NAME_ASC",
          "video_metadata": {
            "height": 1080,
            "width": 1920,
            "codec": "h264",
            "duration": 90.5,
            "aspect_ratio": 1.78
          },
          "screenshot": "https://example.com/shot.jpg",
          "start_from": 91.7,
          "need_convert": true,
          "is_mp4_available": true,
          "mp4_size": 88,
          "mp4_stream_url": "https://example.com/mp4",
          "stream_url": "https://example.com/stream"
        }
        """.utf8
      )
    )
    let audioFile = try decoder.decode(
      PutioFile.self,
      from: Data(
        """
        {
          "id": 50,
          "name": "Song.mp3",
          "icon": "audio",
          "parent_id": 7,
          "size": 5,
          "created_at": "2026-04-20T10:00:00Z",
          "updated_at": "2026-04-20T10:00:00Z",
          "file_type": "AUDIO"
        }
        """.utf8
      )
    )
    let nextAudioFile = try decoder.decode(
      PutioNextFile.self,
      from: Data(
        """
        {
          "id": 51,
          "name": "Song 2.mp3",
          "parent_id": 7,
          "file_type": "AUDIO"
        }
        """.utf8
      )
    )
    let metadata = try decoder.decode(PutioVideoMetadata.self, from: Data(#"{}"#.utf8))
    let rootFile = try decoder.decode(
      PutioFile.self,
      from: Data(
        """
        {
          "id": 0,
          "name": "Your Files",
          "icon": "folder",
          "parent_id": 0,
          "size": 0,
          "created_at": "2026-04-20T10:00:00Z",
          "file_type": "FOLDER"
        }
        """.utf8
      )
    )

    XCTAssertTrue(PutioFileType.fromAPI("FOLDER").isKnown)
    XCTAssertTrue(PutioFileType.fromAPI("VIDEO").isKnown)
    XCTAssertTrue(PutioFileType.fromAPI("AUDIO").isKnown)
    XCTAssertTrue(PutioFileType.fromAPI("IMAGE").isKnown)
    XCTAssertTrue(PutioFileType.fromAPI("PDF").isKnown)
    XCTAssertEqual(PutioFileType.fromAPI("BOOK").rawValue, "BOOK")
    XCTAssertEqual(videoFile.type, .video)
    XCTAssertEqual(videoFile.metaData?.codec, "h264")
    XCTAssertEqual(
      videoFile.getStreamURL(token: "token-123")?.absoluteString,
      "https://api.put.io/v2/files/42/hls/media.m3u8?subtitle_key=all&oauth_token=token-123")
    XCTAssertEqual(
      videoFile.getHlsStreamURL(token: "token-123").absoluteString,
      "https://api.put.io/v2/files/42/hls/media.m3u8?subtitle_key=all&oauth_token=token-123")
    XCTAssertEqual(
      videoFile.getDownloadURL(token: "token-123").absoluteString,
      "https://api.put.io/v2/files/42/download?oauth_token=token-123")
    XCTAssertEqual(
      videoFile.getMp4DownloadURL(token: "token-123").absoluteString,
      "https://api.put.io/v2/files/42/mp4/download?oauth_token=token-123")
    XCTAssertEqual(
      audioFile.getStreamURL(token: "token-123")?.absoluteString,
      "https://api.put.io/v2/files/50/stream?oauth_token=token-123")
    XCTAssertEqual(
      audioFile.getAudioStreamURL(token: "token-123").absoluteString,
      "https://api.put.io/v2/files/50/stream?oauth_token=token-123")
    XCTAssertEqual(
      nextAudioFile.getStreamURL(token: "token-123").absoluteString,
      "https://api.put.io/v2/files/51/stream?oauth_token=token-123")
    XCTAssertEqual(metadata.height, 0)
    XCTAssertEqual(metadata.width, 0)
    XCTAssertEqual(metadata.codec, "")
    XCTAssertEqual(metadata.duration, 0)
    XCTAssertEqual(metadata.aspectRatio, 0)
    XCTAssertEqual(rootFile.id, 0)
    XCTAssertEqual(rootFile.updatedAt, rootFile.createdAt)
    XCTAssertNoThrow(try PutioSDKDateParser.parse("2026-04-23T19:08:48.356333"))
    XCTAssertNoThrow(try PutioSDKDateParser.parse("2026-04-23T19:08:48.356333Z"))
    XCTAssertThrowsError(try PutioSDKDateParser.parse(nil))
    XCTAssertThrowsError(try PutioSDKDateParser.parse("not-a-date"))
  }

  func testTypedFileInputsBuildExpectedParameters() {
    let listQuery = PutioFilesListQuery(
      perPage: 25,
      total: true,
      hidden: true,
      noCursor: true,
      contentType: "video/mp4",
      fileType: .video,
      sortBy: "NAME_ASC",
      mp4Status: true
    )
    let detailsQuery = PutioFileDetailsQuery(
      mp4Size: true,
      startFrom: true,
      streamURL: true,
      mp4StreamURL: true
    )
    let deleteOptions = PutioFileDeleteOptions(skipNonexistents: false, skipOwnerCheck: true)
    let searchQuery = PutioFileSearchQuery(keyword: "matrix", perPage: 10, types: [.video, .audio])
    let continueQuery = PutioFileSearchContinueQuery(perPage: 5)

    XCTAssertEqual(listQuery.parameters(parentID: 7)["parent_id"], .integer(7))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["mp4_status_parent"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["stream_url_parent"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["mp4_stream_url_parent"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["video_metadata_parent"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["per_page"], .integer(25))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["total"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["hidden"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["no_cursor"], .integer(1))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["content_type"], .string("video/mp4"))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["file_type"], .string("VIDEO"))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["sort_by"], .string("NAME_ASC"))
    XCTAssertEqual(listQuery.parameters(parentID: 7)["mp4_status"], .integer(1))
    XCTAssertEqual(detailsQuery.parameters["mp4_size"], .integer(1))
    XCTAssertEqual(detailsQuery.parameters["start_from"], .integer(1))
    XCTAssertEqual(detailsQuery.parameters["stream_url"], .integer(1))
    XCTAssertEqual(detailsQuery.parameters["mp4_stream_url"], .integer(1))
    XCTAssertEqual(deleteOptions.parameters["skip_nonexistents"], .bool(false))
    XCTAssertEqual(deleteOptions.parameters["skip_owner_check"], .bool(true))
    XCTAssertEqual(searchQuery.parameters["query"], .string("matrix"))
    XCTAssertEqual(searchQuery.parameters["per_page"], .integer(10))
    XCTAssertEqual(searchQuery.parameters["type"], .string("VIDEO,AUDIO"))
    XCTAssertEqual(continueQuery.parameters["per_page"], .integer(5))
  }
}

private func playbackFileEnvelope(
  fileID: Int,
  fileType: String,
  needConvert: Bool?,
  startFrom: Double
) -> Data {
  let conversionState = needConvert.map { #""need_convert": \#($0),"# } ?? ""
  return Data(
    """
    {
      "file": {
        "id": \(fileID),
        "name": "Media \(fileID)",
        "parent_id": 7,
        "size": 100,
        "created_at": "2026-04-20T10:00:00Z",
        "updated_at": "2026-04-20T10:00:00Z",
        "file_type": "\(fileType)",
        \(conversionState)
        "start_from": \(startFrom)
      }
    }
    """.utf8
  )
}

private actor PlaybackResolverOwner {
  private let sdk: PutioSDK

  init(config: PutioSDKConfig, urlSession: URLSession) {
    self.sdk = PutioSDK(config: config, urlSession: urlSession)
  }

  func resolveVideoPlaybackSource(fileID: Int) async throws -> PutioVideoPlaybackResolution {
    try await sdk.resolveVideoPlaybackSource(fileID: fileID)
  }

  func replaceConfig(_ config: PutioSDKConfig) {
    sdk.config = config
  }
}
