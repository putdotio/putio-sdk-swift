import Foundation

public class PutioIFTTTEvent {
  open var eventType: String
  open var ingredients: PutioIFTTTEventIngredients

  public init(eventType: String, ingredients: PutioIFTTTEventIngredients) {
    self.eventType = eventType
    self.ingredients = ingredients
  }
}

public class PutioIFTTTEventIngredients {
  func parameters() -> PutioRequestParameters {
    return [:]
  }
}

public class PutioIFTTTPlaybackEventIngredients: PutioIFTTTEventIngredients {
  public var fileId: Int
  public var fileName: String
  public var fileType: String

  public init(fileId: Int, fileName: String, fileType: String) {
    self.fileId = fileId
    self.fileName = fileName
    self.fileType = fileType
  }

  override func parameters() -> PutioRequestParameters {
    return [
      "file_id": .integer(self.fileId),
      "file_name": .string(self.fileName),
      "file_type": .string(self.fileType),
    ]
  }
}

public class PutioIFTTTPlaybackEvent: PutioIFTTTEvent {
  public init(eventType: String, ingredients: PutioIFTTTPlaybackEventIngredients) {
    super.init(eventType: eventType, ingredients: ingredients)
  }
}
