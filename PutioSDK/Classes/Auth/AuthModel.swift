import Foundation

open class PutioAuthCode: Decodable {
  open var code: String
  open var qrCodeURL: URL?

  enum CodingKeys: String, CodingKey {
    case code
    case qrCodeURL = "qr_code_url"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
    self.qrCodeURL = try container.decodeIfPresent(URL.self, forKey: .qrCodeURL)
  }
}

public enum PutioDeviceCodeAuthorization: Equatable, Sendable {
  case authorized(token: String)
  case expired
}

open class PutioTokenValidationResult: Decodable {
  open var result: Bool
  open var tokenID: Int?
  open var tokenScope: String?
  open var userID: Int?

  enum CodingKeys: String, CodingKey {
    case result
    case tokenID = "token_id"
    case tokenScope = "token_scope"
    case userID = "user_id"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.result = try container.decodeIfPresent(Bool.self, forKey: .result) ?? false
    self.tokenID = try container.decodeIfPresent(Int.self, forKey: .tokenID)
    self.tokenScope = try container.decodeIfPresent(String.self, forKey: .tokenScope)
    self.userID = try container.decodeIfPresent(Int.self, forKey: .userID)
  }
}

open class PutioTwoFactorRecoveryCode: Decodable {
  open var code: String
  open var usedAt: String?

  enum CodingKeys: String, CodingKey {
    case code
    case usedAt = "used_at"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.code = try container.decode(String.self, forKey: .code)
    self.usedAt = try container.decodeIfPresent(String.self, forKey: .usedAt)
  }
}

open class PutioTwoFactorRecoveryCodes: Decodable {
  open var createdAt: String
  open var codes: [PutioTwoFactorRecoveryCode]

  enum CodingKeys: String, CodingKey {
    case createdAt = "created_at"
    case codes
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    self.codes =
      try container.decodeIfPresent([PutioTwoFactorRecoveryCode].self, forKey: .codes) ?? []
  }
}

open class PutioGenerateTOTPResult: Decodable {
  open var secret: String
  open var uri: String
  open var recoveryCodes: PutioTwoFactorRecoveryCodes

  enum CodingKeys: String, CodingKey {
    case secret
    case uri
    case recoveryCodes = "recovery_codes"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
    self.uri = try container.decodeIfPresent(String.self, forKey: .uri) ?? ""
    self.recoveryCodes = try container.decode(
      PutioTwoFactorRecoveryCodes.self, forKey: .recoveryCodes)
  }
}

open class PutioVerifyTOTPResult: Decodable {
  open var token: String
  open var userID: Int

  enum CodingKeys: String, CodingKey {
    case token
    case userID = "user_id"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
    self.userID = try container.decodeIfPresent(Int.self, forKey: .userID) ?? 0
  }
}
