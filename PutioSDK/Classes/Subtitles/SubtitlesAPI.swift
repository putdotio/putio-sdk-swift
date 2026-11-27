import Foundation

extension PutioSDK {
  public func getSubtitles(fileID: Int) async throws -> PutioSubtitlesResponse {
    try await request("/files/\(fileID)/subtitles", as: PutioSubtitlesResponse.self)
  }
}
