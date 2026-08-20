import Foundation

extension PutioSDK {
  public func sendIFTTTEvent(event: PutioIFTTTEvent) async throws -> PutioOKResponse {
    try await request(
      "/ifttt-client/event",
      method: .post,
      body: [
        "event_type": .string(event.eventType),
        "ingredients": .object(event.ingredients.parameters()),
      ],
      as: PutioOKResponse.self
    )
  }
}
