import Foundation

public protocol PutioSDKDelegate: AnyObject {
  func onPutioSDKError(error: PutioSDKError)
}

public final class PutioSDK {
  public weak var delegate: PutioSDKDelegate?
  let urlSession: URLSession

  static let apiURL = "https://api.put.io/v2"

  public var config: PutioSDKConfig

  // Internal test seam: `awaitDeviceCodeAuthorization` awaits this at its observable
  // boundaries so deterministic tests can park the loop and cancel at an exact point.
  // Never set outside the package test targets.
  var deviceCodePollObserver: (@Sendable (PutioDeviceCodePollEvent) async -> Void)?

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

  // Snapshots the mutable client state on the caller's actor before hopping to the
  // global executor. `config` and `delegate` are plain stored properties mutated by
  // `setToken`/`clearToken` and consumers on the owning actor; reading them inside the
  // `@concurrent` body below would race those writes (see #52), and the library target
  // compiles in Swift 5 mode, so the compiler would not catch it. The delegate crosses
  // the hop as a weak reference so an in-flight request never extends its lifetime;
  // a delegate swapped mid-request still receives that request's failure if it is alive.
  func request<T: Decodable>(
    _ url: String,
    method: PutioHTTPMethod = .get,
    headers: PutioHTTPHeaders = [:],
    query: PutioRequestParameters = [:],
    body: PutioRequestParameters = [:],
    apiConfig: PutioSDKConfig? = nil,
    isExpectedFailure: @escaping @Sendable (PutioSDKError) -> Bool = { _ in false },
    as type: T.Type
  ) async throws -> sending T {
    let requestConfig = PutioSDKRequestConfig(
      apiConfig: apiConfig ?? config,
      url: url,
      method: method,
      headers: headers,
      query: query,
      body: body
    )
    return try await perform(
      requestConfig: requestConfig,
      delegateReference: PutioSDKDelegateReference(delegate, isExpectedFailure: isExpectedFailure),
      as: type)
  }

  // Runs off the caller's actor (see docs/ARCHITECTURE.md#swift-concurrency-posture):
  // `NonisolatedNonsendingByDefault` would otherwise inherit the caller's isolation for
  // this async body, forcing JSON encode/decode and delegate callbacks onto a `@MainActor`
  // consumer's main thread. `@concurrent` keeps that work on the global executor while the
  // public domain methods that call into `request` stay caller-isolated. Only the value
  // snapshot taken in `request` crosses the hop; `self.config` is never read here.
  // scripts/check-transport-isolation.sh rejects `self.` member access and bare
  // `config`/`delegate` reads inside every `@concurrent` body in this file.
  @concurrent
  private func perform<T: Decodable>(
    requestConfig: PutioSDKRequestConfig,
    delegateReference: PutioSDKDelegateReference,
    as type: T.Type
  ) async throws -> sending T {
    let data = try await execute(requestConfig: requestConfig, delegateReference: delegateReference)

    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      let apiError = PutioSDKError(
        request: PutioSDKErrorRequestInformation(config: requestConfig), decodingError: error,
        responseBody: String(decoding: data, as: UTF8.self))
      delegateReference.notify(apiError)
      throw apiError
    }
  }

  // Stays off the caller's actor for the same reason as `request` above: keeps the
  // network round trip and error-envelope decode/delegate callback on the global executor.
  @concurrent
  private func execute(
    requestConfig: PutioSDKRequestConfig, delegateReference: PutioSDKDelegateReference
  ) async throws -> Data {
    let requestInformation = PutioSDKErrorRequestInformation(config: requestConfig)
    let urlRequest = try buildURLRequest(from: requestConfig)

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await urlSession.data(for: urlRequest)
    } catch {
      let apiError = PutioSDKError(request: requestInformation, error: error)
      delegateReference.notify(apiError)
      throw apiError
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      let apiError = PutioSDKError(
        request: requestInformation, unknownError: URLError(.badServerResponse))
      delegateReference.notify(apiError)
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
      delegateReference.notify(apiError)
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
    request.timeoutInterval = requestConfig.timeoutInterval

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

// Carries the delegate across the executor hop without retaining it. Created on the
// caller's actor and only read afterwards, so the weak load is the sole cross-thread
// access and the Swift runtime performs it atomically. `isExpectedFailure` lets a
// caller own a failure it will translate into a typed result (for example the
// device-code 404 that means "expired"); every other failure still reaches the
// delegate from the global executor, never on the caller's actor.
final class PutioSDKDelegateReference {
  private weak var delegate: PutioSDKDelegate?
  private let isExpectedFailure: @Sendable (PutioSDKError) -> Bool

  init(
    _ delegate: PutioSDKDelegate?,
    isExpectedFailure: @escaping @Sendable (PutioSDKError) -> Bool = { _ in false }
  ) {
    self.delegate = delegate
    self.isExpectedFailure = isExpectedFailure
  }

  func notify(_ error: PutioSDKError) {
    guard !isExpectedFailure(error) else { return }
    delegate?.onPutioSDKError(error: error)
  }
}
