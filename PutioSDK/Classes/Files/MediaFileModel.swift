import Foundation

public struct PutioMp4ConversionStatus: RawRepresentable, Equatable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let queued = PutioMp4ConversionStatus(rawValue: "IN_QUEUE")
  public static let converting = PutioMp4ConversionStatus(rawValue: "CONVERTING")
  public static let completed = PutioMp4ConversionStatus(rawValue: "COMPLETED")
  public static let error = PutioMp4ConversionStatus(rawValue: "ERROR")
  public static let notAvailable = PutioMp4ConversionStatus(rawValue: "NOT_AVAILABLE")

  public var isKnown: Bool {
    Self.knownValues.contains(rawValue)
  }

  static func fromAPI(_ rawValue: String) -> PutioMp4ConversionStatus {
    switch rawValue {
    case Self.queued.rawValue:
      return .queued
    case Self.converting.rawValue:
      return .converting
    case Self.completed.rawValue:
      return .completed
    case Self.error.rawValue:
      return .error
    case Self.notAvailable.rawValue:
      return .notAvailable
    default:
      return PutioMp4ConversionStatus(rawValue: rawValue)
    }
  }

  private static let knownValues: Set<String> = [
    queued.rawValue,
    converting.rawValue,
    completed.rawValue,
    error.rawValue,
    notAvailable.rawValue,
  ]
}

open class PutioMp4Conversion: Decodable {
  open var percentDone: Float
  open var status: PutioMp4ConversionStatus

  enum CodingKeys: String, CodingKey {
    case percentDone = "percent_done"
    case status
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.percentDone = (try container.decodeIfPresent(Float.self, forKey: .percentDone) ?? 0) / 100
    self.status = PutioMp4ConversionStatus.fromAPI(
      try container.decodeIfPresent(String.self, forKey: .status)
        ?? PutioMp4ConversionStatus.notAvailable.rawValue
    )
  }
}

struct PutioStartFromResponse: Decodable {
  var startFrom: Int

  enum CodingKeys: String, CodingKey {
    case startFrom = "start_from"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.startFrom = Int(try container.decodeIfPresent(Double.self, forKey: .startFrom) ?? 0)
  }
}
