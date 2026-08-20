import Foundation

extension PutioSDK {
  public func getRoutes() async throws -> [PutioRoute] {
    let envelope = try await request("/tunnel/routes", as: PutioRoutesEnvelope.self)
    return envelope.routes
  }
}

private struct PutioRoutesEnvelope: Decodable {
  let routes: [PutioRoute]
}
