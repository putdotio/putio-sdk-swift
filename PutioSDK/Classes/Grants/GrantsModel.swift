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
