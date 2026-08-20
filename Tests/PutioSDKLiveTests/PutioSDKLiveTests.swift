import XCTest

@testable import PutioSDK

final class PutioSDKLiveTests: XCTestCase {
  func testAccountInfoLoadsAgainstRealAPI() async throws {
    let sdk = try LiveSupport.newAuthedClient()
    let account = try await sdk.getAccountInfo()

    XCTAssertFalse(account.username.isEmpty)
    XCTAssertGreaterThan(account.id, 0)
  }

  func testValidateTokenLoadsAgainstRealAPI() async throws {
    let sdk = try LiveSupport.newAuthedClient()
    let validation = try await sdk.validateToken(token: sdk.config.token)

    XCTAssertTrue(validation.result)
    XCTAssertNotNil(validation.tokenID)
    XCTAssertNotNil(validation.tokenScope)
    XCTAssertNotNil(validation.userID)
  }

  func testFilesAndTrashDisposableFlow() async throws {
    let sdk = try LiveSupport.newAuthedClient()
    let trashEnabled = try await sdk.getAccountSettings().trashEnabled
    let folderName = LiveSupport.uniqueName(prefix: "putio-swift-live")

    let created = try await sdk.createFolder(name: folderName, parentID: 0)
    let createdID = created.id
    XCTAssertGreaterThan(createdID, 0)

    do {
      let listing = try await sdk.getFiles(parentID: 0)
      XCTAssertTrue(listing.children.contains(where: { $0.id == createdID }))

      _ = try await sdk.deleteFiles(fileIDs: [createdID])

      try XCTSkipIf(!trashEnabled, "Live test account has trash disabled")

      let trash = try await sdk.listTrash()
      XCTAssertTrue(trash.files.contains(where: { $0.id == createdID }))

      _ = try await sdk.restoreTrashFiles(fileIDs: [createdID], cursor: nil)

      let restored = try await sdk.getFile(fileID: createdID)
      XCTAssertEqual(restored.id, createdID)
    } catch {
      try await cleanup(sdk: sdk, fileID: createdID)
      throw error
    }

    try await cleanup(sdk: sdk, fileID: createdID)
  }

  func testTransfersReadPathsLoadAgainstRealAPI() async throws {
    let sdk = try LiveSupport.newAuthedClient()
    let listed = try await sdk.listTransfers(query: PutioTransfersListQuery(perPage: 5))
    let count = try await sdk.countTransfers()
    let probeURL = "https://example.invalid/swift-live-transfer.iso"
    let info = try await sdk.getTransferInfo(urls: [probeURL])

    XCTAssertLessThanOrEqual(listed.transfers.count, 5)
    XCTAssertGreaterThanOrEqual(count, 0)
    XCTAssertGreaterThanOrEqual(info.diskAvailable, 0)
    XCTAssertEqual(info.items.count, 1)
    XCTAssertEqual(info.items.first?.url, probeURL)

    if let cursor = listed.cursor, !cursor.isEmpty {
      let continued = try await sdk.continueTransfers(
        cursor: cursor,
        query: PutioTransfersListQuery(perPage: 5)
      )
      XCTAssertLessThanOrEqual(continued.transfers.count, 5)
    }

    if let transfer = listed.transfers.first {
      let fetched = try await sdk.getTransfer(id: transfer.id)
      XCTAssertEqual(fetched.id, transfer.id)
      XCTAssertFalse(fetched.name.isEmpty)
    }
  }

  func testPlaybackHelpersLoadAndRestoreAgainstRealAPI() async throws {
    let sdk = try LiveSupport.newAuthedClient()
    let video = try await findOwnedVideoCandidate(sdk: sdk)
    try XCTSkipIf(video == nil, "No owned video candidate found for playback live coverage")
    let candidate = try XCTUnwrap(video)

    let subtitles = try await sdk.getSubtitles(fileID: candidate.id)
    if let subtitle = subtitles.subtitles.first {
      XCTAssertFalse(subtitle.key.isEmpty)
      XCTAssertFalse(subtitle.languageCode.isEmpty)
      XCTAssertFalse(subtitle.url.isEmpty)
    }

    let before = try await sdk.getStartFrom(fileID: candidate.id)
    let probe = before == 37 ? 0 : 37

    do {
      _ = try await sdk.setStartFrom(fileID: candidate.id, time: probe)
      let updated = try await sdk.getStartFrom(fileID: candidate.id)
      XCTAssertEqual(updated, probe)

      _ = try await sdk.resetStartFrom(fileID: candidate.id)
      let reset = try await sdk.getStartFrom(fileID: candidate.id)
      XCTAssertEqual(reset, 0)
    } catch {
      try await restoreStartFrom(sdk: sdk, fileID: candidate.id, original: before)
      throw error
    }

    try await restoreStartFrom(sdk: sdk, fileID: candidate.id, original: before)
  }

  private func cleanup(sdk: PutioSDK, fileID: Int) async throws {
    _ = try? await sdk.deleteFiles(fileIDs: [fileID])
    _ = try? await sdk.deleteTrashFiles(fileIDs: [fileID], cursor: nil)
  }

  private func findOwnedVideoCandidate(sdk: PutioSDK) async throws -> PutioFile? {
    let search = try await sdk.searchFiles(
      query: PutioFileSearchQuery(keyword: "mp4", perPage: 10)
    )
    return search.files.first { file in
      file.type == .video && !file.isShared
    }
  }

  private func restoreStartFrom(sdk: PutioSDK, fileID: Int, original: Int) async throws {
    if original == 0 {
      _ = try await sdk.resetStartFrom(fileID: fileID)
    } else {
      _ = try await sdk.setStartFrom(fileID: fileID, time: original)
    }
  }
}
