import Foundation

extension PutioSDK {
  public func getAccountInfo(query: PutioAccountInfoQuery = PutioAccountInfoQuery()) async throws
    -> PutioAccount
  {
    let envelope = try await request(
      "/account/info", query: query.parameters, as: PutioAccountInfoEnvelope.self)
    return envelope.info
  }

  public func getAccountSettings() async throws -> PutioAccount.Settings {
    let envelope = try await request(
      "/account/settings", query: [:], as: PutioAccountSettingsEnvelope.self)
    return envelope.settings
  }

  public func saveAccountSettings(_ update: PutioAccountSettingsUpdate) async throws
    -> PutioOKResponse
  {
    try await request(
      "/account/settings", method: .post, body: update.parameters, as: PutioOKResponse.self)
  }

  public func clearAccountData(options: PutioAccountClearOptions) async throws -> PutioOKResponse {
    try await request(
      "/account/clear", method: .post, body: options.parameters, as: PutioOKResponse.self)
  }

  public func destroyAccount(currentPassword: String) async throws -> PutioOKResponse {
    try await request(
      "/account/destroy", method: .post, body: ["current_password": .string(currentPassword)],
      as: PutioOKResponse.self)
  }
}

private struct PutioAccountInfoEnvelope: Decodable {
  let info: PutioAccount
}

private struct PutioAccountSettingsEnvelope: Decodable {
  let settings: PutioAccount.Settings
}
