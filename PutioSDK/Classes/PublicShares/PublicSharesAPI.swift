import Foundation

extension PutioSDK {
  public func listPublicShares() async throws -> [PutioPublicShare] {
    let envelope = try await request("/public_share/list", as: PutioPublicSharesEnvelope.self)
    return envelope.publicShares
  }

  /// Creates a new public share of the file; every call issues another link.
  public func createPublicShare(fileID: Int) async throws -> PutioPublicShare {
    let envelope = try await request(
      "/public_share/\(fileID)", method: .post, as: PutioPublicShareEnvelope.self)
    return envelope.publicShare
  }

  public func deletePublicShare(id: Int) async throws -> PutioOKResponse {
    try await request("/public_share/\(id)", method: .delete, as: PutioOKResponse.self)
  }
}

private struct PutioPublicSharesEnvelope: Decodable {
  let publicShares: [PutioPublicShare]

  enum CodingKeys: String, CodingKey {
    case publicShares = "public_shares"
  }
}

private struct PutioPublicShareEnvelope: Decodable {
  let publicShare: PutioPublicShare

  enum CodingKeys: String, CodingKey {
    case publicShare = "public_share"
  }
}
