import Foundation

extension PutioSDK {
  public func searchFiles(query: PutioFileSearchQuery) async throws -> PutioFileSearchResponse {
    try await request("/files/search", query: query.parameters, as: PutioFileSearchResponse.self)
  }

  public func continueFileSearch(
    cursor: String, query: PutioFileSearchContinueQuery = PutioFileSearchContinueQuery()
  ) async throws -> PutioFileSearchResponse {
    try await request(
      "/files/search/continue", method: .post, query: query.parameters,
      body: ["cursor": .string(cursor)], as: PutioFileSearchResponse.self)
  }
}
