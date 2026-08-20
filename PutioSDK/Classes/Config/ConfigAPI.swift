import Foundation

extension PutioSDK {
  public func getConfig() async throws -> PutioConfig {
    let envelope = try await request("/config", as: PutioConfigEnvelope.self)
    return envelope.config
  }

  public func saveConfig(_ update: PutioConfigUpdate) async throws -> PutioOKResponse {
    try await request(
      "/config/\(update.key)",
      method: .put,
      body: ["value": update.value],
      as: PutioOKResponse.self
    )
  }

  public func setChromecastPlaybackType(_ playbackType: PutioChromecastPlaybackType) async throws
    -> PutioOKResponse
  {
    try await saveConfig(.chromecastPlaybackType(playbackType))
  }
}

private struct PutioConfigEnvelope: Decodable {
  let config: PutioConfig
}
