import Foundation

/// Bearer secret of a public link: anyone holding it can read the shared file.
public struct PutioPublicShareToken: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible, CustomReflectable
{
  public let value: String

  public init(value: String) {
    self.value = value
  }

  public var description: String {
    "<redacted public share token>"
  }

  public var debugDescription: String {
    description
  }

  public var customMirror: Mirror {
    Mirror(self, children: ["value": description])
  }
}

public struct PutioPublicShareOwner: Equatable, Sendable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

public struct PutioPublicShareFile: Equatable, Sendable {
  public let id: Int
  public let name: String
  public let fileType: PutioFileType

  public init(id: Int, name: String, fileType: PutioFileType) {
    self.id = id
    self.name = name
    self.fileType = fileType
  }
}

public struct PutioPublicShare: Decodable, Equatable, Identifiable, Sendable {
  public let id: Int
  public let token: PutioPublicShareToken
  public let pushToken: PutioPublicShareToken
  public let createdAt: String
  public let expirationDate: String?
  public let owner: PutioPublicShareOwner
  public let userFile: PutioPublicShareFile

  enum CodingKeys: String, CodingKey {
    case id
    case token
    case pushToken = "push_token"
    case createdAt = "created_at"
    case expirationDate = "expiration_date"
    case owner
    case userFile = "user_file"
  }

  enum OwnerCodingKeys: String, CodingKey {
    case name
  }

  enum FileCodingKeys: String, CodingKey {
    case id
    case name
    case fileType = "file_type"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.token = PutioPublicShareToken(value: try Self.decodeSecret(container, .token))
    self.pushToken = PutioPublicShareToken(value: try Self.decodeSecret(container, .pushToken))
    self.createdAt = try container.decode(String.self, forKey: .createdAt)
    self.expirationDate = try container.decodeIfPresent(String.self, forKey: .expirationDate)

    let owner = try container.nestedContainer(keyedBy: OwnerCodingKeys.self, forKey: .owner)
    self.owner = PutioPublicShareOwner(name: try owner.decode(String.self, forKey: .name))

    let file = try container.nestedContainer(keyedBy: FileCodingKeys.self, forKey: .userFile)
    self.userFile = PutioPublicShareFile(
      id: try file.decode(Int.self, forKey: .id),
      name: try file.decode(String.self, forKey: .name),
      fileType: PutioFileType.fromAPI(try file.decode(String.self, forKey: .fileType))
    )
  }

  private static func decodeSecret(
    _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
  ) throws -> String {
    let value = try container.decode(String.self, forKey: key)
    guard !value.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: container, debugDescription: "A public share token must not be empty.")
    }
    return value
  }
}

/// Why put.io refused to create a public share, read from the backend `error_type`.
public struct PutioPublicShareRefusal: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let planNotAllowed = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_NOT_ALLOWED_PLAN")
  public static let rootFolderNotAllowed = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_FOLDER_ROOT_NOT_ALLOWED")
  public static let singleFileLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_SINGLE_FILE_LIMIT_EXCEEDED")
  public static let folderLinkLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_FOLDER_LINK_COUNT_LIMIT_EXCEEDED")
  public static let folderSizeLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_FOLDER_MAX_SIZE_LIMIT_EXCEEDED")
  public static let folderChildrenLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_FOLDER_MAX_CHILDREN_LIMIT_EXCEEDED")
  public static let dailyLinkLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_DAILY_TOTAL_LINK_COUNT_EXCEEDED")
  public static let weeklyLinkLimitExceeded = PutioPublicShareRefusal(
    rawValue: "PUBLIC_SHARE_WEEKLY_TOTAL_LINK_COUNT_EXCEEDED")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  private static let knownValues: Set<String> = [
    planNotAllowed.rawValue,
    rootFolderNotAllowed.rawValue,
    singleFileLimitExceeded.rawValue,
    folderLinkLimitExceeded.rawValue,
    folderSizeLimitExceeded.rawValue,
    folderChildrenLimitExceeded.rawValue,
    dailyLinkLimitExceeded.rawValue,
    weeklyLinkLimitExceeded.rawValue,
  ]
}

extension PutioSDKError {
  /// The refusal behind a failed `createPublicShare(fileID:)`, or nil for any other failure.
  public var publicShareRefusal: PutioPublicShareRefusal? {
    guard let apiErrorType, apiErrorType.hasPrefix("PUBLIC_SHARE_") else {
      return nil
    }
    return PutioPublicShareRefusal(rawValue: apiErrorType)
  }
}
