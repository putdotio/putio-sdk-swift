import Foundation

extension PutioSDK {
  /// Starts copying files shared with the user into their folder `parentID` (0 is the root)
  /// and returns the copy's id for `getCloneInfo(cloneID:)`. put.io copies in the background,
  /// so a started copy can still end in `.error`. A refused start throws a `PutioSDKError`
  /// whose `sharedFileCloneLimit` names the limit it hit.
  public func cloneSharedFiles(fileIDs: [Int], parentID: Int = 0) async throws -> Int {
    let body: PutioRequestParameters = [
      "file_ids": .string((fileIDs.map { String($0) }).joined(separator: ",")),
      "parent_id": .integer(parentID),
    ]
    let envelope = try await request(
      "/sharing/clone", method: .post, body: body, as: PutioSharedFileCloneEnvelope.self)
    return envelope.id
  }

  public func getCloneInfo(cloneID: Int) async throws -> PutioSharedFileCloneInfo {
    try await request("/sharing/clone/\(cloneID)", as: PutioSharedFileCloneInfo.self)
  }
}

private struct PutioSharedFileCloneEnvelope: Decodable {
  let id: Int
}
