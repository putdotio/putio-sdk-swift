import Foundation

extension PutioSDK {
  public func getSubtitles(fileID: Int) async throws -> PutioSubtitlesResponse {
    try await request(
      "/files/\(fileID)/subtitles", query: ["oauth_token": .string(self.config.token)],
      as: PutioSubtitlesResponse.self)
  }
}
