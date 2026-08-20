import Foundation

open class PutioRoute: Decodable {
  open var name: String
  open var description: String
  open var hosts: [String]

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case hosts
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    self.hosts = try container.decodeIfPresent([String].self, forKey: .hosts) ?? []
  }
}
