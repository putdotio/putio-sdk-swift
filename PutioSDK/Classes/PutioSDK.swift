import Foundation

public protocol PutioSDKDelegate: AnyObject {
  func onPutioSDKError(error: PutioSDKError)
}

public final class PutioSDK {
  public weak var delegate: PutioSDKDelegate?
  let urlSession: URLSession

  static let apiURL = "https://api.put.io/v2"

  public var config: PutioSDKConfig

  public convenience init(config: PutioSDKConfig) {
    self.init(config: config, urlSession: .shared)
  }

  public init(config: PutioSDKConfig, urlSession: URLSession) {
    self.urlSession = urlSession
    self.config = config
  }

  public func setToken(token: String) {
    self.config.token = token
  }

  public func clearToken() {
    self.config.token = ""
  }

  func request<T: Decodable>(
    _ url: String,
    method: PutioHTTPMethod = .get,
    headers: PutioHTTPHeaders = [:],
    query: PutioRequestParameters = [:],
    body: PutioRequestParameters = [:],
    as type: T.Type
  ) async throws -> T {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: config,
      url: url,
      method: method,
      headers: headers,
      query: query,
      body: body
    )
    let data = try await execute(requestConfig: requestConfig)

    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      let apiError = PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig), decodingError: error,
        responseBody: String(decoding: data, as: UTF8.self))
      delegate?.onPutioSDKError(error: apiError)
      throw apiError
    }
  }

  private func execute(requestConfig: PutioSDKRequestConfig) async throws -> Data {
    let requestInformation = PutioSDKErrorRequestInformation(config: requestConfig)
    let urlRequest = try buildURLRequest(from: requestConfig)

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await urlSession.data(for: urlRequest)
    } catch {
      let apiError = PutioSDKError(request: requestInformation, error: error)
      delegate?.onPutioSDKError(error: apiError)
      throw apiError
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      let apiError = PutioSDKError(
        request: requestInformation, unknownError: URLError(.badServerResponse))
      delegate?.onPutioSDKError(error: apiError)
      throw apiError
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let body = String(decoding: data, as: UTF8.self)
      let envelope = try? JSONDecoder().decode(PutioAPIErrorEnvelope.self, from: data)
      let message = envelope?.resolvedMessage ?? "put.io returned HTTP \(httpResponse.statusCode)"
      let apiError = PutioSDKError(
        request: requestInformation,
        statusCode: envelope?.statusCode ?? httpResponse.statusCode,
        errorType: envelope?.errorType,
        message: message,
        underlyingError: URLError(.badServerResponse),
        responseBody: body
      )
      delegate?.onPutioSDKError(error: apiError)
      throw apiError
    }

    return data
  }

  private func buildURLRequest(from requestConfig: PutioSDKRequestConfig) throws -> URLRequest {
    let url: URL
    do {
      url = try requestConfig.buildURL()
    } catch {
      throw PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig),
        unknownError: URLError(.badURL))
    }

    var request = URLRequest(url: url)
    request.httpMethod = requestConfig.method.rawValue
    request.timeoutInterval = config.timeoutInterval

    for (name, value) in requestConfig.headers
    where !(name.lowercased() == "authorization" && value.isEmpty) {
      request.setValue(value, forHTTPHeaderField: name)
    }

    if let body = requestConfig.body, !body.isEmpty {
      request.httpBody = try JSONEncoder().encode(body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }
}
