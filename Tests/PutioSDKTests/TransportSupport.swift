import Foundation
import XCTest

@testable import PutioSDK

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// watchOS proxies URLSession loads out of process and never consults custom
// URLProtocol classes, so URLProtocol-backed transport tests cannot run there.
// This helper is the suite-level watchOS gate: every test that dispatches through
// the mock transport installs its handler here, and a test that never installs a
// handler (OAuth state and callback validation, decoding, URL building) still runs
// on every platform. Write `MockURLProtocol.requestHandler` only through this helper.
func installMockRequestHandler(
  _ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) throws {
  #if os(watchOS)
    throw XCTSkip("watchOS URLSession does not consult custom URLProtocol classes")
  #else
    MockURLProtocol.requestHandler = { request in
      if let url = request.url,
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      {
        XCTAssertFalse(
          queryItems.contains(where: { $0.name.lowercased() == "oauth_token" }),
          "API request URL must not carry oauth_token query parameter: \(url.path)"
        )
      }
      return try handler(request)
    }
  #endif
}

final class MockURLProtocol: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  private let loader = DispatchQueue(label: "MockURLProtocol.loader")
  private let stateLock = NSLock()
  private var isStopped = false

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      fatalError("MockURLProtocol.requestHandler must be configured before use")
    }

    let request = request
    nonisolated(unsafe) let loading = self
    loader.async {
      let result = Result { try handler(request) }
      loading.deliver(result)
    }
  }

  override func stopLoading() {
    stateLock.withLock { isStopped = true }
  }

  private func deliver(_ result: Result<(HTTPURLResponse, Data), Error>) {
    stateLock.withLock {
      guard !isStopped else { return }
      switch result {
      case .success(let (response, data)):
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
      case .failure(let error):
        client?.urlProtocol(self, didFailWithError: error)
      }
    }
  }
}

func makeTestSession() -> URLSession {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  return URLSession(configuration: configuration)
}

func makeHTTPResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
  HTTPURLResponse(
    url: request.url!,
    statusCode: statusCode,
    httpVersion: nil,
    headerFields: ["Content-Type": "application/json"]
  )!
}

func requestBodyData(for request: URLRequest) -> Data? {
  if let body = request.httpBody {
    return body
  }

  guard let stream = request.httpBodyStream else {
    return nil
  }

  stream.open()
  defer { stream.close() }

  let bufferSize = 1024
  let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
  defer { buffer.deallocate() }

  var data = Data()

  while stream.hasBytesAvailable {
    let read = stream.read(buffer, maxLength: bufferSize)
    if read < 0 {
      return nil
    }
    if read == 0 {
      break
    }

    data.append(buffer, count: read)
  }

  return data
}
