import Foundation

extension PutioSDK {
  public func listTransfers(query: PutioTransfersListQuery = PutioTransfersListQuery()) async throws
    -> PutioTransfersListResponse
  {
    try await request(
      "/transfers/list", query: query.parameters, as: PutioTransfersListResponse.self)
  }

  public func continueTransfers(
    cursor: String, query: PutioTransfersListQuery = PutioTransfersListQuery()
  ) async throws -> PutioTransfersListResponse {
    try await request(
      "/transfers/list/continue",
      method: .post,
      query: query.parameters,
      body: ["cursor": .string(cursor)],
      as: PutioTransfersListResponse.self
    )
  }

  public func getTransfer(id: Int) async throws -> PutioTransfer {
    let envelope = try await request("/transfers/\(id)", as: PutioTransferEnvelope.self)
    return envelope.transfer
  }

  public func countTransfers() async throws -> Int {
    let envelope = try await request("/transfers/count", as: PutioTransferCountEnvelope.self)
    return envelope.count
  }

  public func getTransferInfo(urls: [String]) async throws -> PutioTransferInfoResponse {
    try await request(
      "/transfers/info", method: .post, body: ["urls": .string(urls.joined(separator: "\n"))],
      as: PutioTransferInfoResponse.self)
  }

  public func addTransfer(_ input: PutioTransferAddInput) async throws -> PutioTransfer {
    let envelope = try await request(
      "/transfers/add", method: .post, body: input.parameters, as: PutioTransferEnvelope.self)
    return envelope.transfer
  }

  public func addTransfers(_ inputs: [PutioTransferAddInput]) async throws
    -> PutioTransfersAddManyResponse
  {
    let payload = inputs.map(\.parameters)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(payload)
    let urls = String(decoding: data, as: UTF8.self)
    return try await request(
      "/transfers/add-multi", method: .post, body: ["urls": .string(urls)],
      as: PutioTransfersAddManyResponse.self)
  }

  public func cancelTransfers(ids: [Int]) async throws -> PutioOKResponse {
    try await request(
      "/transfers/cancel", method: .post,
      body: ["transfer_ids": .string(ids.map(String.init).joined(separator: ","))],
      as: PutioOKResponse.self)
  }

  public func cleanTransfers(ids: [Int] = []) async throws -> PutioTransfersCleanResponse {
    let body: PutioRequestParameters =
      ids.isEmpty ? [:] : ["transfer_ids": .string(ids.map(String.init).joined(separator: ","))]
    return try await request(
      "/transfers/clean", method: .post, body: body, as: PutioTransfersCleanResponse.self)
  }

  public func retryTransfer(id: Int) async throws -> PutioTransfer {
    let envelope = try await request(
      "/transfers/retry", method: .post, body: ["id": .integer(id)], as: PutioTransferEnvelope.self)
    return envelope.transfer
  }
}
