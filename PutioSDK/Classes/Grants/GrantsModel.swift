import Foundation

open class PutioOAuthGrant: Decodable {
  open var id: Int
  open var name: String
  open var description: String
  open var website: URL?
  open var hasIcon: Bool?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case description
    case website
    case hasIcon = "has_icon"
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    self.website = try container.decodeIfPresent(URL.self, forKey: .website)
    self.hasIcon = try container.decodeIfPresent(Bool.self, forKey: .hasIcon)
  }
}

/// One signed-in session of an app. Sessions of one app share its grant; the
/// session that made the request is `isActive`.
public struct PutioOAuthClient: Decodable, Equatable, Identifiable, Sendable {
  public let id: Int
  public let appID: Int
  public let appName: String?
  public let clientName: String
  public let createdAt: String?
  public let lastUsedAt: String?
  public let isActive: Bool

  public init(
    id: Int, appID: Int, appName: String? = nil, clientName: String = "",
    createdAt: String? = nil, lastUsedAt: String? = nil, isActive: Bool = false
  ) {
    self.id = id
    self.appID = appID
    self.appName = appName
    self.clientName = clientName
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.isActive = isActive
  }

  enum CodingKeys: String, CodingKey {
    case id
    case appID = "app_id"
    case appName = "app_name"
    case clientName = "client_name"
    case createdAt = "created_at"
    case lastUsedAt = "last_used_at"
    case isActive = "active"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    appID = try container.decode(Int.self, forKey: .appID)
    appName = try container.decodeIfPresent(String.self, forKey: .appName)
    clientName = try container.decodeIfPresent(String.self, forKey: .clientName) ?? ""
    createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    lastUsedAt = try container.decodeIfPresent(String.self, forKey: .lastUsedAt)
    isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
  }
}
