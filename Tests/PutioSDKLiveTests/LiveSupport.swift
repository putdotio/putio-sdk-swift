import Foundation
import XCTest

@testable import PutioSDK

enum LiveSupport {
    private static let envFileValues: [String: String] = loadEnvFiles([".env.local", ".env"])

    static func newAuthedClient() throws -> PutioSDK {
        let token = try requiredValue("PUTIO_TOKEN_FIRST_PARTY", aliases: ["PUTIO_ACCESS_TOKEN", "PUTIO_TOKEN"])
        let clientID = try runtimeValue("PUTIO_CLIENT_ID") ?? ""
        let baseURL = env("PUTIO_BASE_URL")

        var config = PutioSDKConfig(clientID: clientID, token: token)
        if let baseURL {
            config = PutioSDKConfig(
                baseURL: baseURL,
                clientID: clientID,
                clientSecret: "",
                clientName: "",
                token: token,
                timeoutInterval: 15.0
            )
        }

        return PutioSDK(config: config)
    }

    static func uniqueName(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(12))"
    }

    private static func env(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? envFileValues[name]
    }

    private static func requiredValue(_ primary: String, aliases: [String] = []) throws -> String {
        if let value = try runtimeValue(primary, aliases: aliases) {
            return value
        }

        throw XCTSkip("Missing live-test credential env: \(primary)")
    }

    private static func runtimeValue(_ primary: String, aliases: [String] = []) throws -> String? {
        for key in [primary] + aliases {
            if let value = env(key) {
                return value
            }
        }

        return nil
    }

    private static func loadEnvFiles(_ paths: [String]) -> [String: String] {
        paths.reduce(into: [:]) { values, path in
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
                return
            }

            for line in contents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else {
                    continue
                }

                let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rawValue = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = unquote(rawValue).nilIfEmpty

                if !key.isEmpty, let value {
                    values[key] = value
                }
            }
        }
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        let first = value.first
        let last = value.last

        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }

        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
