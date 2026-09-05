import Foundation
import XCTest

@testable import PutioSDK

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
    MockURLProtocol.requestHandler = handler
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

func makeTestSession(taskObserver: TaskCompletionObserver? = nil) -> URLSession {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  return URLSession(configuration: configuration, delegate: taskObserver, delegateQueue: nil)
}

// Signals once URLSession has finished a task, which is the earliest point at which
// cancelling the calling task can no longer surface as `URLError.cancelled`. The async
// `data(for:)` API consumes `didCompleteWithError` itself and only forwards the metrics
// callback to the session delegate, so that is the completion signal observed here.
final class TaskCompletionObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let completed = DispatchSemaphore(value: 0)

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    completed.signal()
  }

  func waitUntilTaskCompleted(timeout: DispatchTimeInterval = .seconds(5)) throws {
    guard completed.wait(timeout: .now() + timeout) == .success else {
      throw TestSynchronizationTimeout(stage: "URLSession task completion")
    }
  }
}

struct TestSynchronizationTimeout: Error, CustomStringConvertible {
  let stage: String
  var description: String { "timed out waiting for \(stage)" }
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
