import Foundation

public enum PutioSharedFileCloneStatus: Equatable, Sendable {
  case new
  case processing
  case done
  case error
  case unknown(String)

  init(rawValue: String) {
    switch rawValue {
    case "NEW": self = .new
    case "PROCESSING": self = .processing
    case "DONE": self = .done
    case "ERROR": self = .error
    default: self = .unknown(rawValue)
    }
  }

  /// put.io stops working on the copy in these states; any other status may still change.
  public var isFinished: Bool {
    switch self {
    case .done, .error:
      return true
    case .new, .processing, .unknown:
      return false
    }
  }
}

/// A background copy started by `cloneSharedFiles(fileIDs:parentID:)`. `errorMessage` is
/// put.io's English reason for `.error`, with sensitive values redacted.
public struct PutioSharedFileCloneInfo: Decodable, Equatable, Sendable {
  public let status: PutioSharedFileCloneStatus
  public let errorMessage: String?

  public init(status: PutioSharedFileCloneStatus, errorMessage: String? = nil) {
    self.status = status
    self.errorMessage = errorMessage
  }

  enum CodingKeys: String, CodingKey {
    case status = "shared_file_clone_status"
    case errorMessage = "error_msg"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    status = PutioSharedFileCloneStatus(
      rawValue: try container.decode(String.self, forKey: .status))
    errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
      .map(redactSensitiveText)
  }
}

/// The limit put.io enforced when it refused to start a shared-file copy.
public enum PutioSharedFileCloneLimit: String, CaseIterable, Sendable {
  /// The user already has the maximum number of copies running.
  case concurrentCopies = "SharedFileCloneConcurrentLimit"
  /// The selection has more top-level files than one copy accepts.
  case tooManyFiles = "SharedFileCloneTooManyFiles"
  /// The selected folders hold more files in total than one copy accepts.
  case tooManyChildren = "SharedFileCloneTooManyChildren"
}

extension PutioSDKError {
  /// The limit put.io reported when it refused `cloneSharedFiles(fileIDs:parentID:)`.
  public var sharedFileCloneLimit: PutioSharedFileCloneLimit? {
    guard statusCode == 400 else { return nil }
    return apiErrorType.flatMap(PutioSharedFileCloneLimit.init(rawValue:))
  }
}
