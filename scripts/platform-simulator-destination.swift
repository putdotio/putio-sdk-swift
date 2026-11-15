#!/usr/bin/env swift
import Foundation

enum Platform: String {
  case tvOS
  case watchOS
}

struct DeviceList: Decodable {
  let devices: [String: [Device]]
}

struct Device: Decodable {
  let udid: String
  let name: String
  let isAvailable: Bool
}

struct RuntimeVersion: Comparable {
  let components: [Int]

  init?(runtimeIdentifier: String, platform: Platform) {
    let prefix = "com.apple.CoreSimulator.SimRuntime.\(platform.rawValue)-"
    guard runtimeIdentifier.hasPrefix(prefix) else { return nil }
    let parts = runtimeIdentifier.dropFirst(prefix.count).split(separator: "-")
    let components = parts.compactMap { Int($0) }
    guard !components.isEmpty, components.count == parts.count else { return nil }
    self.components = components
  }

  static func < (lhs: RuntimeVersion, rhs: RuntimeVersion) -> Bool {
    lhs.components.lexicographicallyPrecedes(rhs.components)
  }
}

struct Runtime {
  let version: RuntimeVersion
  let devices: [Device]
}

func fail(_ message: String, status: Int32) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(status)
}

func deviceListJSON() -> Data {
  if let path = ProcessInfo.processInfo.environment["PUTIO_SIMCTL_DEVICES_JSON"] {
    guard let data = FileManager.default.contents(atPath: path) else {
      fail("cannot read \(path)", status: 66)
    }
    return data
  }

  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
  process.arguments = ["simctl", "list", "devices", "available", "--json"]
  let output = Pipe()
  process.standardOutput = output
  do {
    try process.run()
  } catch {
    fail("cannot run simctl: \(error)", status: 71)
  }
  let data = output.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    fail("simctl list devices failed with status \(process.terminationStatus)", status: 71)
  }
  return data
}

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 1, let argument = arguments.first,
  let platform = Platform(rawValue: argument)
else {
  fail("usage: platform-simulator-destination.swift <tvOS|watchOS>", status: 64)
}

let list: DeviceList
do {
  list = try JSONDecoder().decode(DeviceList.self, from: deviceListJSON())
} catch {
  fail("unreadable simctl device list: \(error)", status: 65)
}

let newest = list.devices
  .compactMap { identifier, devices -> Runtime? in
    guard let version = RuntimeVersion(runtimeIdentifier: identifier, platform: platform) else {
      return nil
    }
    let available = devices.filter(\.isAvailable)
    return available.isEmpty ? nil : Runtime(version: version, devices: available)
  }
  .max { $0.version < $1.version }

guard let newest, let device = newest.devices.min(by: { ($0.name, $0.udid) < ($1.name, $1.udid) })
else {
  fail(
    "no available \(platform.rawValue) simulator; install the \(platform.rawValue) runtime",
    status: 69)
}

print("id=\(device.udid)")
