import Foundation

extension PutioSDK {
  public func getGrants() async throws -> [PutioOAuthGrant] {
    let envelope = try await request("/oauth/grants", as: PutioGrantsEnvelope.self)
    return envelope.apps
  }

  public func revokeGrant(id: Int) async throws -> PutioOKResponse {
    try await request("/oauth/grants/\(id)/delete", method: .post, as: PutioOKResponse.self)
  }

  public func linkDevice(code: String) async throws -> PutioOAuthGrant {
    let envelope = try await request(
      "/oauth2/oob/code", method: .post, body: ["code": .string(code)], as: PutioGrantEnvelope.self)
    return envelope.app
  }
}

private struct PutioGrantsEnvelope: Decodable {
  let apps: [PutioOAuthGrant]
}

private struct PutioGrantEnvelope: Decodable {
  let app: PutioOAuthGrant
}
