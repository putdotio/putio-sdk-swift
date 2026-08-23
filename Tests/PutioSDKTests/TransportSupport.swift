import Foundation
import XCTest

@testable import PutioSDK

// watchOS proxies URLSession loads out of process and never consults custom
// URLProtocol classes, so URLProtocol-backed transport tests cannot run there.
// The pure-logic suites (OAuth state and callback validation, decoding, public
// surface) still run on watchOS.
func skipUnlessURLProtocolMockingIsSupported() throws {
  #if os(watchOS)
    throw XCTSkip("watchOS URLSession does not consult custom URLProtocol classes")
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

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      fatalError("MockURLProtocol.requestHandler must be configured before use")
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
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
