import Foundation

extension PutioSDK {
  public func getGrants() async throws -> [PutioOAuthGrant] {
    let envelope = try await request("/oauth/grants", as: PutioGrantsEnvelope.self)
    return envelope.apps
  }

  public func revokeGrant(id: Int) async throws -> PutioOKResponse {
    try await request("/oauth/grants/\(id)/delete", method: .post, as: PutioOKResponse.self)
  }

  public func getClients() async throws -> [PutioOAuthClient] {
    let envelope = try await request("/oauth/clients", as: PutioClientsEnvelope.self)
    return envelope.clients
  }

  /// The image put.io stores for an app; ask only for a grant whose `hasIcon` is true.
  public func getAppIcon(appID: Int) async throws -> Data {
    try await requestData("/oauth/apps/\(appID)/icon")
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

private struct PutioClientsEnvelope: Decodable {
  let clients: [PutioOAuthClient]
}

private struct PutioGrantEnvelope: Decodable {
  let app: PutioOAuthGrant
}
