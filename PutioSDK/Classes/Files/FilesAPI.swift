import Foundation

extension PutioSDK {
  public func getFiles(parentID: Int, query: PutioFilesListQuery = PutioFilesListQuery())
    async throws -> PutioFilesListResult
  {
    let envelope = try await request(
      "/files/list", query: query.parameters(parentID: parentID), as: PutioFilesListEnvelope.self)
    return PutioFilesListResult(
      parent: envelope.parent, children: envelope.files, cursor: envelope.cursor,
      total: envelope.total)
  }

  public func getFile(fileID: Int, query: PutioFileDetailsQuery = PutioFileDetailsQuery())
    async throws -> PutioFile
  {
    let envelope = try await request(
      "/files/\(fileID)", query: query.parameters, as: PutioFileEnvelope.self)
    return envelope.file
  }

  public func createFolder(name: String, parentID: Int) async throws -> PutioFile {
    let body: PutioRequestParameters = ["name": .string(name), "parent_id": .integer(parentID)]
    let envelope = try await request(
      "/files/create-folder", method: .post, body: body, as: PutioFileEnvelope.self)
    return envelope.file
  }

  public func deleteFiles(
    fileIDs: [Int], options: PutioFileDeleteOptions = PutioFileDeleteOptions()
  ) async throws -> PutioOKResponse {
    let body: PutioRequestParameters = [
      "file_ids": .string((fileIDs.map { String($0) }).joined(separator: ","))
    ]
    return try await request(
      "/files/delete", method: .post, query: options.parameters, body: body,
      as: PutioOKResponse.self)
  }

  public func copyFiles(fileIDs: [Int]) async throws -> PutioOKResponse {
    let body: PutioRequestParameters = [
      "file_ids": .string((fileIDs.map { String($0) }).joined(separator: ","))
    ]
    return try await request(
      "/files/copy-to-disk", method: .post, body: body, as: PutioOKResponse.self)
  }

  public func moveFiles(fileIDs: [Int], parentID: Int) async throws -> PutioFilesMoveResponse {
    let body: PutioRequestParameters = [
      "file_ids": .string((fileIDs.map { String($0) }).joined(separator: ",")),
      "parent_id": .integer(parentID),
    ]
    return try await request(
      "/files/move", method: .post, body: body, as: PutioFilesMoveResponse.self)
  }

  public func renameFile(fileID: Int, name: String) async throws -> PutioOKResponse {
    try await request(
      "/files/rename", method: .post, body: ["file_id": .integer(fileID), "name": .string(name)],
      as: PutioOKResponse.self)
  }

  public func findNextFile(fileID: Int, fileType: PutioNextFileType) async throws -> PutioNextFile {
    let envelope = try await request(
      "/files/\(fileID)/next-file", query: ["file_type": .string(fileType.rawValue)],
      as: PutioNextFileEnvelope.self)
    return envelope.nextFile
  }

  public func setSortBy(fileId: Int, sortBy: String) async throws -> PutioOKResponse {
    try await request(
      "/files/set-sort-by", method: .post,
      body: ["file_id": .integer(fileId), "sort_by": .string(sortBy)], as: PutioOKResponse.self)
  }

  public func resetFileSpecificSortSettings() async throws -> PutioOKResponse {
    try await request("/files/remove-sort-by-settings", method: .post, as: PutioOKResponse.self)
  }
}

public struct PutioFilesListResult {
  public let parent: PutioFile?
  public let children: [PutioFile]
  public let cursor: String?
  public let total: Int?
}

private struct PutioFilesListEnvelope: Decodable {
  let parent: PutioFile?
  let files: [PutioFile]
  let cursor: String?
  let total: Int?
}

private struct PutioFileEnvelope: Decodable {
  let file: PutioFile
}

public struct PutioFilesMoveError: Codable {
  public let errorType: String
  public let id: Int
  public let name: String?
  public let statusCode: Int

  enum CodingKeys: String, CodingKey {
    case errorType = "error_type"
    case id
    case name
    case statusCode = "status_code"
  }
}

public struct PutioFilesMoveResponse: Codable {
  public let status: String
  public let errors: [PutioFilesMoveError]
}

private struct PutioNextFileEnvelope: Decodable {
  let nextFile: PutioNextFile

  enum CodingKeys: String, CodingKey {
    case nextFile = "next_file"
  }
}
