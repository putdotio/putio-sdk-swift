import Foundation

extension PutioSDK {
  public func listTrash(query: PutioTrashListQuery = PutioTrashListQuery()) async throws
    -> PutioListTrashResponse
  {
    try await request("/trash/list", query: query.parameters, as: PutioListTrashResponse.self)
  }

  public func listTrash(perPage: Int) async throws -> PutioListTrashResponse {
    try await listTrash(query: PutioTrashListQuery(perPage: perPage))
  }

  public func continueListTrash(cursor: String, query: PutioTrashListQuery = PutioTrashListQuery())
    async throws -> PutioListTrashResponse
  {
    try await request(
      "/trash/list/continue",
      method: .post,
      query: query.parameters,
      body: ["cursor": .string(cursor)],
      as: PutioListTrashResponse.self
    )
  }

  public func continueListTrash(cursor: String, perPage: Int) async throws -> PutioListTrashResponse
  {
    try await continueListTrash(cursor: cursor, query: PutioTrashListQuery(perPage: perPage))
  }

  public func restoreTrashFiles(fileIDs: [Int] = [], cursor: String?) async throws
    -> PutioOKResponse
  {
    let body = putioTrashMutationBody(fileIDs: fileIDs, cursor: cursor)
    return try await request("/trash/restore", method: .post, body: body, as: PutioOKResponse.self)
  }

  public func deleteTrashFiles(fileIDs: [Int] = [], cursor: String?) async throws -> PutioOKResponse
  {
    let body = putioTrashMutationBody(fileIDs: fileIDs, cursor: cursor)
    return try await request("/trash/delete", method: .post, body: body, as: PutioOKResponse.self)
  }

  public func emptyTrash() async throws -> PutioOKResponse {
    try await request("/trash/empty", method: .post, as: PutioOKResponse.self)
  }
}

private func putioTrashMutationBody(fileIDs: [Int], cursor: String?) -> PutioRequestParameters {
  if let cursor, !cursor.isEmpty {
    return ["cursor": .string(cursor)]
  }

  return ["file_ids": .string((fileIDs.map { String($0) }).joined(separator: ","))]
}
