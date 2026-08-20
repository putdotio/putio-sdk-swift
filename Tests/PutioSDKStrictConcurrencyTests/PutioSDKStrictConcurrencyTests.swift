import PutioSDK
import XCTest

final class PutioSDKStrictConcurrencyTests: XCTestCase {
  func testClientCanBeOwnedByAnActor() async {
    let owner = SDKOwner()
    let token = await owner.updateToken()

    XCTAssertEqual(token, "actor-token")
  }

  func testLowRiskValueTypesAreSendable() {
    requireSendable(PutioSDKConfig.self)
    requireSendable(PutioAccountInfoQuery.self)
    requireSendable(PutioAccountSettingsPatch.self)
    requireSendable(PutioTwoFactorSettings.self)
    requireSendable(PutioAccountSettingsUpdate.self)
    requireSendable(PutioAccountClearOptions.self)
    requireSendable(PutioOAuthCallbackError.self)
    requireSendable(PutioOAuthStateError.self)
    requireSendable(PutioFileSearchQuery.self)
    requireSendable(PutioFileSearchContinueQuery.self)
    requireSendable(PutioFilesMoveError.self)
    requireSendable(PutioFilesMoveResponse.self)
    requireSendable(PutioVideoMetadata.self)
    requireSendable(PutioNextFileType.self)
    requireSendable(PutioFilesListQuery.self)
    requireSendable(PutioFileDetailsQuery.self)
    requireSendable(PutioFileDeleteOptions.self)
    requireSendable(PutioHistoryEventsQuery.self)
    requireSendable(PutioSDKRequestConfig.self)
    requireSendable(PutioSDKErrorType.self)
    requireSendable(PutioSDKErrorRequestInformation.self)
    requireSendable(PutioSDKError.self)
    requireSendable(PutioOKResponse.self)
    requireSendable(PutioTransferLink.self)
    requireSendable(PutioTransfer.self)
    requireSendable(PutioTransfersListQuery.self)
    requireSendable(PutioTransfersListResponse.self)
    requireSendable(PutioTransferAddInput.self)
    requireSendable(PutioTransferInfoItem.self)
    requireSendable(PutioTransferInfoResponse.self)
    requireSendable(PutioTransfersAddManyError.self)
    requireSendable(PutioTransfersAddManyResponse.self)
    requireSendable(PutioTransfersCleanResponse.self)
    requireSendable(PutioTrashListQuery.self)
  }
}

private func requireSendable<T: Sendable>(_: T.Type) {}

private actor SDKOwner {
  private let sdk = PutioSDK(config: PutioSDKConfig(clientID: "strict-consumer"))

  func updateToken() -> String {
    sdk.setToken(token: "actor-token")
    return sdk.config.token
  }
}

// This function is intentionally compile-only. It verifies that a Swift 6 app can
// keep legacy mutable response models on its actor while using every SDK domain.
@MainActor
private func auditAsyncConsumerSurface(_ sdk: PutioSDK) async throws {
  _ = try await sdk.getAccountInfo()
  _ = try await sdk.getAccountSettings()
  _ = try await sdk.getAuthCode()
  _ = try await sdk.validateToken(token: "token")
  _ = try await sdk.getRecoveryCodes()
  _ = try await sdk.getConfig()
  _ = try await sdk.searchFiles(query: PutioFileSearchQuery(keyword: "query"))
  _ = try await sdk.getFiles(parentID: 0)
  _ = try await sdk.getFile(fileID: 1)
  _ = try await sdk.findNextFile(fileID: 1, fileType: .video)
  _ = try await sdk.getMp4ConversionStatus(fileID: 1)
  _ = try await sdk.getGrants()
  _ = try await sdk.getHistoryEvents()
  let ingredients = PutioIFTTTPlaybackEventIngredients(
    fileId: 1,
    fileName: "Movie",
    fileType: "VIDEO"
  )
  let event = PutioIFTTTPlaybackEvent(
    eventType: "playback_started",
    ingredients: ingredients
  )
  _ = try await sdk.sendIFTTTEvent(event: event)
  ingredients.fileName = "Movie 2"
  _ = try await sdk.getRoutes()
  _ = try await sdk.getSubtitles(fileID: 1)
  _ = try await sdk.listTransfers()
  _ = try await sdk.getTransfer(id: 1)
  _ = try await sdk.getTransferInfo(urls: ["https://example.com/file"])
  _ = try await sdk.listTrash()
}
