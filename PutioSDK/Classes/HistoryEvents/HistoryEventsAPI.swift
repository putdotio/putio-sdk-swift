import Foundation

extension PutioSDK {
  public func getHistoryEvents(query: PutioHistoryEventsQuery = PutioHistoryEventsQuery())
    async throws -> PutioHistoryEventsResponse
  {
    try await request("/events/list", query: query.parameters, as: PutioHistoryEventsResponse.self)
  }

  public func clearHistoryEvents() async throws -> PutioOKResponse {
    try await request("/events/delete", method: .post, as: PutioOKResponse.self)
  }

  public func deleteHistoryEvent(eventID: Int) async throws -> PutioOKResponse {
    try await request("/events/delete/\(eventID)", method: .post, as: PutioOKResponse.self)
  }
}
