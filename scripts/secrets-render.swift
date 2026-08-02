#!/usr/bin/env swift

import Foundation

enum RenderError: Error, CustomStringConvertible {
    case invalidArguments
    case invalidPayload
    case invalidInventory
    case invalidValue
    case invalidIdentifier
    case unsafeValue

    var description: String {
        switch self {
        case .invalidArguments:
            return "expected payload and output paths"
        case .invalidPayload:
            return "decrypted payload must be a JSON object"
        case .invalidInventory:
            return "decrypted payload key inventory does not match the SDK contract"
        case .invalidValue:
            return "decrypted payload contains an empty, non-string, quote-wrapped, or control-character value"
        case .invalidIdentifier:
            return "decrypted payload contains an invalid numeric identifier"
        case .unsafeValue:
            return "decrypted payload contains a value that cannot be rendered safely"
        }
    }
}

func render(_ value: String) throws -> String {
    if !value.contains("\"") {
        return "\"\(value)\""
    }

    if !value.contains("'") {
        return "'\(value)'"
    }

    throw RenderError.unsafeValue
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw RenderError.invalidArguments
    }

    let payloadPath = CommandLine.arguments[1]
    let outputPath = CommandLine.arguments[2]
    let data = try Data(contentsOf: URL(fileURLWithPath: payloadPath))
    let decoded = try JSONSerialization.jsonObject(with: data)

    guard let payload = decoded as? [String: String] else {
        throw RenderError.invalidPayload
    }

    let expectedKeys = [
        "PUTIO_CLIENT_ID",
        "PUTIO_TOKEN_FIRST_PARTY",
        "PUTIO_TOKEN_THIRD_PARTY",
    ]
    let actualKeys = payload.keys.sorted()

    guard actualKeys == expectedKeys else {
        throw RenderError.invalidInventory
    }

    for key in actualKeys {
        guard let value = payload[key], !value.isEmpty else {
            throw RenderError.invalidValue
        }

        let quoteWrapped = value.count >= 2
            && ((value.hasPrefix("\"") && value.hasSuffix("\""))
                || (value.hasPrefix("'") && value.hasSuffix("'")))
        let hasControlCharacter = value.unicodeScalars.contains { scalar in
            scalar.value == 0 || scalar.value == 10 || scalar.value == 13
        }

        guard !quoteWrapped, !hasControlCharacter else {
            throw RenderError.invalidValue
        }
    }

    guard payload["PUTIO_CLIENT_ID"]?.allSatisfy({ $0 >= "0" && $0 <= "9" }) == true else {
        throw RenderError.invalidIdentifier
    }

    let dotenv = try actualKeys
        .map { key -> String in
            guard let value = payload[key] else {
                throw RenderError.invalidPayload
            }

            return "\(key)=\(try render(value))"
        }
        .joined(separator: "\n") + "\n"
    let outputURL = URL(fileURLWithPath: outputPath)

    try Data(dotenv.utf8).write(to: outputURL, options: .atomic)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: outputPath
    )
} catch {
    FileHandle.standardError.write(Data("FAILED: \(error)\n".utf8))
    exit(1)
}
