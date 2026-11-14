import Foundation
import XCTest

@testable import PutioSDK

final class PutioSDKPlaybackPlanTests: XCTestCase {
  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testDirectPlayConformanceCases() async throws {
    let cases: [PlanCase] = [
      PlanCase(
        name: "device plays the original",
        mediaInfo: CapturedMediaInfo.h264AACMP4, needConvert: false, isMp4Available: true,
        device: .playable, expected: .stream(.original, path: "stream", reason: nil),
        asksDevice: true),
      PlanCase(
        name: "no media_info, converted copy",
        mediaInfo: nil, needConvert: false, isMp4Available: true,
        device: .playable, expected: .stream(.mp4, path: "mp4/stream", reason: .notReady),
        asksDevice: false),
      PlanCase(
        name: "no media_info, needs conversion",
        mediaInfo: nil, needConvert: true, isMp4Available: false,
        device: .playable, expected: .conversionRequired(.notReady), asksDevice: false),
      PlanCase(
        name: "media_info null, nothing to convert",
        mediaInfo: "null", needConvert: false, isMp4Available: false,
        device: .playable, expected: .unplayable(.notReady), asksDevice: false),
      PlanCase(
        name: "playback_issues entry, converted copy",
        mediaInfo: CapturedMediaInfo.vp8VorbisWebMWithIssues, needConvert: false,
        isMp4Available: true, device: .playable,
        expected: .stream(.mp4, path: "mp4/stream", reason: .playbackIssue), asksDevice: false),
      PlanCase(
        name: "playback_issues entry, needs conversion",
        mediaInfo: CapturedMediaInfo.vp8VorbisWebMWithIssues, needConvert: true,
        isMp4Available: false, device: .playable,
        expected: .conversionRequired(.playbackIssue), asksDevice: false),
      PlanCase(
        name: "device says no, converted copy",
        mediaInfo: CapturedMediaInfo.hevcDTSMKV, needConvert: false, isMp4Available: true,
        device: .unsupported(.audioUnsupported),
        expected: .stream(.mp4, path: "mp4/stream", reason: .audioUnsupported),
        asksDevice: true),
      PlanCase(
        name: "device says no, needs conversion",
        mediaInfo: CapturedMediaInfo.hevcDTSMKV, needConvert: true, isMp4Available: false,
        device: .unsupported(.containerUnsupported),
        expected: .conversionRequired(.containerUnsupported), asksDevice: true),
      PlanCase(
        name: "device says no, nothing to convert",
        mediaInfo: CapturedMediaInfo.hevcDTSMKV, needConvert: false, isMp4Available: false,
        device: .unsupported(.videoUnsupported), expected: .unplayable(.videoUnsupported),
        asksDevice: true),
      PlanCase(
        name: "original failed before the first frame",
        mediaInfo: CapturedMediaInfo.h264AACMP4, needConvert: false, isMp4Available: true,
        device: .unsupported(.decoderError),
        expected: .stream(.mp4, path: "mp4/stream", reason: .decoderError), asksDevice: true),
    ]

    for planCase in cases {
      let recorder = RequestRecorder()
      try installMockRequestHandler { request in
        recorder.append(request)
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          planFileEnvelope(
            fileID: 42, fileType: "VIDEO", needConvert: planCase.needConvert,
            isMp4Available: planCase.isMp4Available, mediaInfo: planCase.mediaInfo)
        )
      }
      let asked = DecisionRecorder()

      let plan = try await makeSDK().resolvePlayback(
        fileID: 42, downloadToken: "download-token", method: .directPlay
      ) { mediaInfo in
        asked.record(mediaInfo)
        return planCase.device
      }

      try assertPlan(plan, matches: planCase.expected, fileID: 42, case: planCase.name)
      XCTAssertEqual(asked.count > 0, planCase.asksDevice, planCase.name)
      let request = try XCTUnwrap(recorder.requests.first, planCase.name)
      XCTAssertEqual(recorder.requests.count, 1, planCase.name)
      XCTAssertEqual(
        queryItems(of: request.url),
        ["media_info": "1", "mp4_status": "1", "start_from": "1"],
        planCase.name)
    }
  }

  func testDirectPlayHandsTheDeviceCheckTheCapturedMediaInfo() async throws {
    try installMockRequestHandler { request in
      (
        makeHTTPResponse(for: request, statusCode: 200),
        planFileEnvelope(
          fileID: 42, fileType: "VIDEO", needConvert: false, isMp4Available: false,
          mediaInfo: CapturedMediaInfo.h264AACMP4)
      )
    }
    let asked = DecisionRecorder()

    let plan = try await makeSDK().resolvePlayback(
      fileID: 42, downloadToken: "download-token", method: .directPlay
    ) { mediaInfo in
      asked.record(mediaInfo)
      return .playable
    }

    guard case .ready(let stream) = plan else {
      return XCTFail("Expected the original, got \(plan)")
    }
    XCTAssertEqual(asked.mediaInfos, [expectedH264AACMP4])
    XCTAssertEqual(stream.mediaInfo, expectedH264AACMP4)
    XCTAssertEqual(stream.startFrom, 30)
  }

  func testStandardPlaysHLSOrRequiresConversionWithoutMediaInfo() async throws {
    let cases: [(needConvert: Bool, isMp4Available: Bool, expected: ExpectedPlan)] = [
      (false, false, .stream(.hls, path: "hls/media.m3u8", reason: nil)),
      (false, true, .stream(.hls, path: "hls/media.m3u8", reason: nil)),
      (true, false, .conversionRequired(nil)),
    ]

    for testCase in cases {
      let recorder = RequestRecorder()
      try installMockRequestHandler { request in
        recorder.append(request)
        return (
          makeHTTPResponse(for: request, statusCode: 200),
          planFileEnvelope(
            fileID: 43, fileType: "VIDEO", needConvert: testCase.needConvert,
            isMp4Available: testCase.isMp4Available, mediaInfo: CapturedMediaInfo.h264AACMP4)
        )
      }
      let asked = DecisionRecorder()

      let plan = try await makeSDK().resolvePlayback(
        fileID: 43, downloadToken: "download-token", method: .standard
      ) { mediaInfo in
        asked.record(mediaInfo)
        return .playable
      }

      let name = "standard, need_convert \(testCase.needConvert)"
      try assertPlan(plan, matches: testCase.expected, fileID: 43, case: name)
      XCTAssertEqual(asked.count, 0, name)
      XCTAssertEqual(
        queryItems(of: try XCTUnwrap(recorder.requests.first).url),
        ["mp4_status": "1", "start_from": "1"], name)
    }
  }

  func testAudioPlaysTheOriginalUnderBothMethods() async throws {
    for method in PutioStreamingMethod.allCases {
      try installMockRequestHandler { request in
        (
          makeHTTPResponse(for: request, statusCode: 200),
          planFileEnvelope(
            fileID: 50, fileType: "AUDIO", needConvert: nil, isMp4Available: nil, mediaInfo: nil)
        )
      }

      let plan = try await makeSDK().resolvePlayback(
        fileID: 50, downloadToken: "download-token", method: method
      ) { _ in
        XCTFail("Audio never asks the device check")
        return .playable
      }

      try assertPlan(
        plan, matches: .stream(.original, path: "stream", reason: nil), fileID: 50,
        case: method.rawValue)
    }
  }

  func testNonMediaFilesThrowTypedRecovery() async throws {
    try installMockRequestHandler { request in
      (
        makeHTTPResponse(for: request, statusCode: 200),
        planFileEnvelope(
          fileID: 51, fileType: "PDF", needConvert: nil, isMp4Available: nil, mediaInfo: nil)
      )
    }

    do {
      _ = try await makeSDK().resolvePlayback(
        fileID: 51, downloadToken: "download-token", method: .directPlay
      ) { _ in .playable }
      XCTFail("Expected an unsupported file type")
    } catch let error as PutioPlaybackPlanError {
      XCTAssertEqual(error, .unsupportedFileType(.pdf))
      XCTAssertNotNil(error.errorDescription)
      XCTAssertNotNil(error.recoverySuggestion)
    }
  }

  func testVideoWithoutConversionStateFailsDecoding() async throws {
    let states = [
      #""need_convert": false, "start_from": 0"#,
      #""is_mp4_available": false, "start_from": 0"#,
      #""need_convert": false, "is_mp4_available": false"#,
    ]

    for state in states {
      try installMockRequestHandler { request in
        let payload = #"{"file": {"id": 52, "file_type": "VIDEO", \#(state)}}"#
        return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
      }

      do {
        _ = try await makeSDK().resolvePlayback(
          fileID: 52, downloadToken: "download-token", method: .directPlay
        ) { _ in .playable }
        XCTFail("Expected \(state) to fail decoding")
      } catch let error as PutioSDKError {
        XCTAssertTrue(error.isDecodingFailure, state)
      }
    }
  }

  func testCapturedMediaInfoDecodes() throws {
    let decoder = JSONDecoder()

    XCTAssertEqual(
      try decoder.decode(PutioMediaInfo.self, from: Data(CapturedMediaInfo.h264AACMP4.utf8)),
      expectedH264AACMP4)

    let mkv = try decoder.decode(
      PutioMediaInfo.self, from: Data(CapturedMediaInfo.hevcDTSMKV.utf8))
    XCTAssertEqual(mkv.mimeType, "video/x-matroska")
    XCTAssertEqual(mkv.format, PutioMediaFormat(name: "matroska"))
    XCTAssertEqual(mkv.streams.map(\.codecType), [.video, .audio, .audio, .subtitle])
    XCTAssertEqual(mkv.streams.map(\.codecName), ["hevc", "dts", "truehd", "ass"])
    XCTAssertEqual(mkv.streams[0].profile, "Main 10")
    XCTAssertEqual(mkv.streams[0].level, 150)
    XCTAssertEqual(mkv.streams[0].width, 3840)
    XCTAssertEqual(mkv.streams[0].height, 2160)
    XCTAssertNil(mkv.streams[0].rfc6381Codec)
    XCTAssertEqual(mkv.streams[1].channels, 6)
    XCTAssertEqual(mkv.playbackIssues, [])
    XCTAssertTrue(mkv.streams.allSatisfy { $0.codecType?.isKnown == true })

    let webm = try decoder.decode(
      PutioMediaInfo.self, from: Data(CapturedMediaInfo.vp8VorbisWebMWithIssues.utf8))
    XCTAssertEqual(webm.playbackIssues, [.openGOP, PutioPlaybackIssue(rawValue: "future_issue")])
    XCTAssertEqual(webm.playbackIssues.map(\.isKnown), [true, false])
    XCTAssertEqual(webm.streams[0].level, -99)

    let sparse = try decoder.decode(PutioMediaInfo.self, from: Data("{}".utf8))
    XCTAssertEqual(
      sparse, PutioMediaInfo(mimeType: nil, format: nil, streams: [], playbackIssues: []))
  }

  func testFileDetailsRequestAndDecodeMediaInfo() async throws {
    let recorder = RequestRecorder()
    try installMockRequestHandler { request in
      recorder.append(request)
      let payload = """
        {
          "file": {
            "id": 60,
            "name": "Clip.mp4",
            "parent_id": 0,
            "size": 100,
            "created_at": "2026-04-20T10:00:00Z",
            "updated_at": "2026-04-20T10:00:00Z",
            "file_type": "VIDEO",
            "media_info": \(CapturedMediaInfo.h264AACMP4)
          },
          "status": "OK"
        }
        """
      return (makeHTTPResponse(for: request, statusCode: 200), Data(payload.utf8))
    }

    let file = try await makeSDK().getFile(
      fileID: 60, query: PutioFileDetailsQuery(mediaInfo: true))

    XCTAssertEqual(file.mediaInfo, expectedH264AACMP4)
    XCTAssertEqual(queryItems(of: try XCTUnwrap(recorder.requests.first).url)["media_info"], "1")
    XCTAssertNil(PutioFileDetailsQuery().parameters["media_info"])

    let fileStream = URLComponents(
      url: file.getFileStreamURL(downloadToken: "download-token"), resolvingAgainstBaseURL: false)
    XCTAssertEqual(fileStream?.path, "/v2/files/60/stream")
    XCTAssertEqual(
      fileStream?.queryItems, [URLQueryItem(name: "oauth_token", value: "download-token")])
  }

  func testPlanDescriptionsRedactTheDownloadToken() throws {
    let stream = PutioPlaybackStream(
      kind: .mp4,
      url: try XCTUnwrap(
        URL(string: "https://example.test/v2/files/1/mp4/stream?oauth_token=secret")),
      startFrom: 3,
      fallbackReason: .audioUnsupported
    )

    for plan in [
      PutioPlaybackPlan.ready(stream), .conversionRequired(.notReady), .unplayable(.playbackIssue),
    ] {
      var dumped = ""
      dump(plan, to: &dumped)
      for description in [String(describing: plan), String(reflecting: plan), dumped] {
        XCTAssertFalse(description.contains("secret"), description)
      }
    }
    XCTAssertEqual(
      PutioPlaybackReason.allCases.map(\.rawValue),
      [
        "not_ready", "playback_issue", "container_unsupported", "video_unsupported",
        "audio_unsupported", "decoder_error", "conversion_failed",
      ])
    XCTAssertEqual(PutioStreamingMethod.allCases.map(\.rawValue), ["hls", "file"])
  }

  private func makeSDK() -> PutioSDK {
    PutioSDK(
      config: PutioSDKConfig(clientID: "ios-app", token: "token-123"),
      urlSession: makeTestSession()
    )
  }

  private func assertPlan(
    _ plan: PutioPlaybackPlan, matches expected: ExpectedPlan, fileID: Int, case name: String
  ) throws {
    switch (plan, expected) {
    case (.ready(let stream), .stream(let kind, let path, let reason)):
      XCTAssertEqual(stream.kind, kind, name)
      XCTAssertEqual(stream.fallbackReason, reason, name)
      let components = URLComponents(url: stream.url, resolvingAgainstBaseURL: false)
      XCTAssertEqual(components?.path, "/v2/files/\(fileID)/\(path)", name)
      let query = queryItems(of: stream.url)
      XCTAssertEqual(query["oauth_token"], "download-token", name)
      XCTAssertNil(query["original"], name)
    case (.conversionRequired(let reason), .conversionRequired(let expectedReason)):
      XCTAssertEqual(reason, expectedReason, name)
    case (.unplayable(let reason), .unplayable(let expectedReason)):
      XCTAssertEqual(reason, expectedReason, name)
    default:
      XCTFail("\(name): expected \(expected), got \(plan)")
    }
  }
}

private struct PlanCase {
  let name: String
  let mediaInfo: String?
  let needConvert: Bool
  let isMp4Available: Bool
  let device: PutioOriginalVideoSupport
  let expected: ExpectedPlan
  let asksDevice: Bool
}

private enum ExpectedPlan {
  case stream(PutioPlaybackStreamKind, path: String, reason: PutioPlaybackReason?)
  case conversionRequired(PutioPlaybackReason?)
  case unplayable(PutioPlaybackReason)
}

private final class RequestRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [URLRequest] = []

  func append(_ request: URLRequest) {
    lock.withLock { storage.append(request) }
  }

  var requests: [URLRequest] {
    lock.withLock { storage }
  }
}

private final class DecisionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [PutioMediaInfo] = []

  func record(_ mediaInfo: PutioMediaInfo) {
    lock.withLock { storage.append(mediaInfo) }
  }

  var mediaInfos: [PutioMediaInfo] {
    lock.withLock { storage }
  }

  var count: Int {
    mediaInfos.count
  }
}

private func queryItems(of url: URL?) -> [String: String] {
  guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
  else {
    return [:]
  }
  return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

private func planFileEnvelope(
  fileID: Int, fileType: String, needConvert: Bool?, isMp4Available: Bool?, mediaInfo: String?
) -> Data {
  var fields = [
    #""id": \#(fileID)"#,
    #""name": "Media \#(fileID)""#,
    #""file_type": "\#(fileType)""#,
    #""start_from": 30.4"#,
  ]
  if let needConvert { fields.append(#""need_convert": \#(needConvert)"#) }
  if let isMp4Available { fields.append(#""is_mp4_available": \#(isMp4Available)"#) }
  if let mediaInfo { fields.append(#""media_info": \#(mediaInfo)"#) }
  return Data(#"{"file": {\#(fields.joined(separator: ", "))}, "status": "OK"}"#.utf8)
}

private let expectedH264AACMP4 = PutioMediaInfo(
  mimeType: "video/mp4",
  format: PutioMediaFormat(name: "mp4"),
  streams: [
    PutioMediaStream(
      codecType: .video, codecName: "h264", rfc6381Codec: "avc1.42001e", width: 720,
      height: 480, profile: "Main", level: 42),
    PutioMediaStream(
      codecType: .audio, codecName: "aac", rfc6381Codec: "mp4a.40.2", channels: 2),
  ],
  playbackIssues: []
)

private enum CapturedMediaInfo {
  static let h264AACMP4 = """
    {
      "format": {"bit_rate": 1322900, "duration": 1394.149289, "name": "mp4"},
      "mime_type": "video/mp4",
      "playback_issues": [],
      "streams": [
        {
          "codec_name": "h264", "codec_type": "video", "height": 480, "level": 42,
          "profile": "Main", "rfc6381_codec": "avc1.42001e", "width": 720
        },
        {"channels": 2, "codec_name": "aac", "codec_type": "audio", "rfc6381_codec": "mp4a.40.2"}
      ]
    }
    """

  static let hevcDTSMKV = """
    {
      "format": {"bit_rate": 35632654, "duration": 60.019, "name": "matroska"},
      "mime_type": "video/x-matroska",
      "playback_issues": [],
      "streams": [
        {
          "codec_name": "hevc", "codec_type": "video", "height": 2160, "level": 150,
          "profile": "Main 10", "rfc6381_codec": null, "width": 3840
        },
        {"channels": 6, "codec_name": "dts", "codec_type": "audio", "rfc6381_codec": null},
        {"channels": 6, "codec_name": "truehd", "codec_type": "audio", "rfc6381_codec": null},
        {"codec_name": "ass", "codec_type": "subtitle", "rfc6381_codec": null}
      ]
    }
    """

  static let vp8VorbisWebMWithIssues = """
    {
      "format": {"bit_rate": null, "duration": 734.167, "name": "matroska"},
      "mime_type": "video/webm",
      "playback_issues": ["open_gop", "future_issue"],
      "streams": [
        {
          "codec_name": "vp8", "codec_type": "video", "height": 800, "level": -99,
          "profile": "0", "rfc6381_codec": null, "width": 1920
        },
        {"channels": 2, "codec_name": "vorbis", "codec_type": "audio", "rfc6381_codec": null}
      ]
    }
    """
}
