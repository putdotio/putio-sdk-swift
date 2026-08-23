import XCTest

@testable import PutioSDK

final class PutioSDKFilesTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
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
              "parent_id": 7,
              "file_type": "VIDEO"
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
