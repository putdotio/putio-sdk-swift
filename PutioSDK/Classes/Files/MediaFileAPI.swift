import Foundation

extension PutioSDK {
  public func startMp4Conversion(fileID: Int) async throws -> PutioOKResponse {
    try await request("/files/\(fileID)/mp4", method: .post, as: PutioOKResponse.self)
  }

  public func getMp4ConversionStatus(fileID: Int) async throws -> PutioMp4Conversion {
    let envelope = try await request("/files/\(fileID)/mp4", as: PutioMp4ConversionEnvelope.self)
    return envelope.mp4
  }

  public func getStartFrom(fileID: Int) async throws -> Int {
    let response = try await request("/files/\(fileID)/start-from", as: PutioStartFromResponse.self)
    return response.startFrom
  }

  public func setStartFrom(fileID: Int, time: Int) async throws -> PutioOKResponse {
    try await request(
      "/files/\(fileID)/start-from/set", method: .post, body: ["time": .integer(time)],
      as: PutioOKResponse.self)
  }

  public func resetStartFrom(fileID: Int) async throws -> PutioOKResponse {
    try await request("/files/\(fileID)/start-from/delete", as: PutioOKResponse.self)
  }
}

private struct PutioMp4ConversionEnvelope: Decodable {
  let mp4: PutioMp4Conversion
}
